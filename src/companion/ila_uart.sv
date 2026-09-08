/*
    ila_uart.sv - Hardware UART Controller for NanoMac ILA & ICE Debugger
    Target: Gowin GW2AR-18C (Tang Nano 20K)
    Clock: 78.336 MHz (clk_pixel_x5)
    Baud: 2,000,000 baud (divisor 39 => 2,008,615 baud, +0.43% error)

    Commands:
      '?' or 'h' : Help menu
      's'        : Live CPU state snapshot
      'H'        : Halt CPU
      'r'        : Resume CPU
      'R'        : Pulse CPU reset
      '1'        : Single-step 1 clock phase (and print state)
      '8'        : Single-step 8 clock phases (1 cycle) (and print state)
      'b'        : Single-step 1 bus cycle (and print state)
      'a'        : Arm ILA trace buffer on _cpuAS falling edge
      'A'        : Force trigger trace buffer immediately
      'd'        : Dump last 64 trace samples as formatted ASCII table
      'D'        : Dump all 512 trace samples as formatted ASCII table
      'B'        : Fast raw binary dump (4096 bytes)
*/

module ila_uart #(
    parameter CLK_FREQ  = 15667200,
    parameter BAUD_RATE = 2000000,
    parameter DIVISOR   = 8  // 15667200 / 8 = 1958400 baud (-2.08% error, well within +/-5% UART tolerance)
)(
    input               clk,
    input               reset,

    // Physical UART pins
    input               rx_pin,
    output reg          tx_pin,

    // Live probe signals from Core
    input  [63:0]       probes,
    input               halted,
    input               stepping_clocks,
    input               stepping_bus,

    // ILA status & trace memory read port
    input  [2:0]        ila_state,
    input  [8:0]        wr_ptr,
    input  [8:0]        trigger_pos,
    output reg [8:0]    trace_rd_addr,
    input  [63:0]       trace_rd_data,

    // ICE execution control outputs
    output reg          uart_halt_req,
    output reg          uart_resume_req,
    output reg          uart_reset_req,
    output reg          uart_step_clock_req,
    output reg          uart_step_bus_req,
    output reg [15:0]   uart_step_val,

    // ILA control outputs
    output reg          uart_arm_req,
    output reg          uart_disarm_req,
    output reg          uart_force_trig_req,
    output reg [2:0]    uart_trig_mode
);

    // -------------------------------------------------------------------------
    // 1. UART Receiver (RX)
    // -------------------------------------------------------------------------
    reg [1:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[0], rx_pin};
    wire rx_in = rx_sync[1];

    localparam RX_IDLE  = 3'd0;
    localparam RX_START = 3'd1;
    localparam RX_DATA  = 3'd2;
    localparam RX_STOP  = 3'd3;

    reg [2:0]  rx_state;
    reg [5:0]  rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_shreg;
    reg        rx_valid;
    reg [7:0]  rx_byte;

    always @(posedge clk) begin
        if (reset) begin
            rx_state   <= RX_IDLE;
            rx_clk_cnt <= 0;
            rx_bit_idx <= 0;
            rx_valid   <= 0;
        end else begin
            rx_valid <= 0;
            case (rx_state)
                RX_IDLE: begin
                    rx_clk_cnt <= 0;
                    rx_bit_idx <= 0;
                    if (!rx_in) rx_state <= RX_START; // Falling edge (start bit)
                end
                RX_START: begin
                    if (rx_clk_cnt == (DIVISOR / 2)) begin
                        if (!rx_in) begin
                            rx_clk_cnt <= 0;
                            rx_state   <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE; // False start bit
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 6'd1;
                    end
                end
                RX_DATA: begin
                    if (rx_clk_cnt == (DIVISOR - 1)) begin
                        rx_clk_cnt <= 0;
                        rx_shreg   <= {rx_in, rx_shreg[7:1]};
                        if (rx_bit_idx == 3'd7)
                            rx_state <= RX_STOP;
                        else
                            rx_bit_idx <= rx_bit_idx + 3'd1;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 6'd1;
                    end
                end
                RX_STOP: begin
                    if (rx_clk_cnt == (DIVISOR - 1)) begin
                        rx_clk_cnt <= 0;
                        rx_state   <= RX_IDLE;
                        if (rx_in) begin // Valid stop bit
                            rx_byte  <= rx_shreg;
                            rx_valid <= 1'b1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 6'd1;
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 2. UART Transmitter (TX) & 512-byte Output FIFO
    // -------------------------------------------------------------------------
    reg [7:0] fifo_mem [0:511];
    reg [8:0] fifo_wptr;
    reg [8:0] fifo_rptr;
    reg       fifo_wr;
    reg [7:0] fifo_din;

    wire [8:0] fifo_count    = fifo_wptr - fifo_rptr;
    wire       fifo_empty    = (fifo_wptr == fifo_rptr);
    wire       fifo_has_room = (fifo_count < 9'd480);

    always @(posedge clk) begin
        if (reset) begin
            fifo_wptr <= 0;
        end else if (fifo_wr) begin
            fifo_mem[fifo_wptr] <= fifo_din;
            fifo_wptr           <= fifo_wptr + 9'd1;
        end
    end

    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA  = 3'd2;
    localparam TX_STOP  = 3'd3;

    reg [2:0] tx_state;
    reg [5:0] tx_clk_cnt;
    reg [2:0] tx_bit_idx;
    reg [7:0] tx_shreg;

    always @(posedge clk) begin
        if (reset) begin
            tx_state   <= TX_IDLE;
            tx_pin     <= 1'b1;
            tx_clk_cnt <= 0;
            tx_bit_idx <= 0;
            fifo_rptr  <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_pin     <= 1'b1;
                    tx_clk_cnt <= 0;
                    tx_bit_idx <= 0;
                    if (!fifo_empty) begin
                        tx_shreg  <= fifo_mem[fifo_rptr];
                        fifo_rptr <= fifo_rptr + 9'd1;
                        tx_state  <= TX_START;
                    end
                end
                TX_START: begin
                    tx_pin <= 1'b0; // Start bit
                    if (tx_clk_cnt == (DIVISOR - 1)) begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 6'd1;
                    end
                end
                TX_DATA: begin
                    tx_pin <= tx_shreg[0];
                    if (tx_clk_cnt == (DIVISOR - 1)) begin
                        tx_clk_cnt <= 0;
                        tx_shreg   <= {1'b0, tx_shreg[7:1]};
                        if (tx_bit_idx == 3'd7)
                            tx_state <= TX_STOP;
                        else
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 6'd1;
                    end
                end
                TX_STOP: begin
                    tx_pin <= 1'b1; // Stop bit
                    if (tx_clk_cnt == (DIVISOR - 1)) begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_IDLE;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 6'd1;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // Helper task-like function to convert 4-bit nibble to ASCII hex
    function [7:0] hex2ascii(input [3:0] nibble);
        hex2ascii = (nibble < 4'd10) ? (8'h30 + {4'd0, nibble}) : (8'h41 + {4'd0, nibble} - 8'd10);
    endfunction

    // -------------------------------------------------------------------------
    // 3. Command Execution & Response State Machine
    // -------------------------------------------------------------------------
    localparam S_IDLE       = 4'd0;
    localparam S_PRINT_MSG  = 4'd1;
    localparam S_PRINT_STAT = 4'd2;
    localparam S_WAIT_STEP  = 4'd3;
    localparam S_DUMP_ROW   = 4'd4;
    localparam S_DUMP_BIN   = 4'd5;
    localparam S_DUMP_HDR   = 4'd6;
    localparam S_DUMP_GAP   = 4'd7;

    reg [3:0]  state;
    reg [7:0]  msg_idx;
    reg [7:0]  msg_len;
    reg [6:0]  msg_sel;

    reg [8:0]  dump_cur;
    reg [8:0]  dump_end;
    reg [9:0]  dump_cnt;
    reg [5:0]  dump_col;
    reg [2:0]  bin_byte_idx;

    reg        print_after_step;
    reg [63:0] sample_latch;
    reg [19:0] step_timeout;

    always @(posedge clk) begin
        if (reset) begin
            state               <= S_IDLE;
            uart_halt_req       <= 0;
            uart_resume_req     <= 0;
            uart_reset_req      <= 0;
            uart_step_clock_req <= 0;
            uart_step_bus_req   <= 0;
            uart_step_val       <= 0;
            uart_arm_req        <= 0;
            uart_disarm_req     <= 0;
            uart_force_trig_req <= 0;
            uart_trig_mode      <= 0;
            fifo_wr             <= 0;
            fifo_din            <= 0;
            msg_idx             <= 0;
            msg_len             <= 0;
            msg_sel             <= 0;
            dump_cur            <= 0;
            dump_end            <= 0;
            dump_col            <= 0;
            trace_rd_addr       <= 0;
            print_after_step    <= 0;
            step_timeout        <= 0;
        end else begin
            // Default strobes
            uart_halt_req       <= 0;
            uart_resume_req     <= 0;
            uart_reset_req      <= 0;
            uart_step_clock_req <= 0;
            uart_step_bus_req   <= 0;
            uart_arm_req        <= 0;
            uart_disarm_req     <= 0;
            uart_force_trig_req <= 0;
            fifo_wr             <= 0;

            case (state)
                S_IDLE: begin
                    if (rx_valid) begin
                        case (rx_byte)
                            8'h3F, 8'h68: begin // '?' or 'h' -> Help
                                msg_sel <= 0;
                                msg_idx <= 0;
                                msg_len <= 117;
                                state   <= S_PRINT_MSG;
                            end
                            8'h73, 8'h53: begin // 's' or 'S' -> State snapshot
                                sample_latch <= probes;
                                dump_col     <= 0;
                                state        <= S_PRINT_STAT;
                            end
                            8'h48: begin // 'H' -> Halt CPU
                                uart_halt_req <= 1'b1;
                                msg_sel       <= 1;
                                msg_idx       <= 0;
                                msg_len       <= 14;
                                state         <= S_PRINT_MSG;
                            end
                            8'h72: begin // 'r' -> Resume CPU
                                uart_resume_req <= 1'b1;
                                msg_sel         <= 2;
                                msg_idx         <= 0;
                                msg_len         <= 16;
                                state           <= S_PRINT_MSG;
                            end
                            8'h52, 8'h7A: begin // 'R' or 'z' -> Reset CPU
                                uart_reset_req <= 1'b1;
                                msg_sel        <= 3;
                                msg_idx        <= 0;
                                msg_len        <= 15;
                                state          <= S_PRINT_MSG;
                            end
                            8'h31: begin // '1' -> Step 1 clock phase
                                uart_step_clock_req <= 1'b1;
                                uart_step_val       <= 16'd1;
                                print_after_step    <= 1'b1;
                                step_timeout        <= 20'd500000;
                                state               <= S_WAIT_STEP;
                            end
                            8'h38: begin // '8' -> Step 8 clock phases (1 cycle)
                                uart_step_clock_req <= 1'b1;
                                uart_step_val       <= 16'd8;
                                print_after_step    <= 1'b1;
                                step_timeout        <= 20'd500000;
                                state               <= S_WAIT_STEP;
                            end
                            8'h62: begin // 'b' -> Step 1 bus cycle
                                uart_step_bus_req <= 1'b1;
                                uart_step_val     <= 16'd1;
                                print_after_step  <= 1'b1;
                                step_timeout      <= 20'd500000;
                                state             <= S_WAIT_STEP;
                            end
                            8'h61: begin // 'a' -> Arm ILA on _cpuAS
                                uart_arm_req   <= 1'b1;
                                uart_trig_mode <= 3'd1; // Trigger on _cpuAS low
                                msg_sel        <= 4;
                                msg_idx        <= 0;
                                msg_len        <= 22;
                                state          <= S_PRINT_MSG;
                            end
                            8'h41: begin // 'A' -> Force trigger now
                                uart_force_trig_req <= 1'b1;
                                msg_sel             <= 5;
                                msg_idx             <= 0;
                                msg_len             <= 21;
                                state               <= S_PRINT_MSG;
                            end
                            8'h64: begin // 'd' -> Dump 64 samples
                                dump_cur      <= wr_ptr - 9'd64;
                                dump_cnt      <= 10'd64;
                                trace_rd_addr <= wr_ptr - 9'd64;
                                dump_col      <= 0;
                                state         <= S_DUMP_HDR;
                            end
                            8'h44: begin // 'D' -> Dump all 512 samples
                                dump_cur      <= wr_ptr;
                                dump_cnt      <= 10'd512;
                                trace_rd_addr <= wr_ptr;
                                dump_col      <= 0;
                                state         <= S_DUMP_HDR;
                            end
                            8'h42: begin // 'B' -> Raw binary dump (4096 bytes)
                                dump_cur      <= 0;
                                dump_cnt      <= 10'd512;
                                trace_rd_addr <= 0;
                                bin_byte_idx  <= 0;
                                state         <= S_DUMP_BIN;
                            end
                            default: ;
                        endcase
                    end
                end

                // -------------------------------------------------------------
                // Print canned strings
                // -------------------------------------------------------------
                S_PRINT_MSG: begin
                    if (fifo_has_room) begin
                        fifo_wr  <= 1'b1;
                        msg_idx  <= msg_idx + 8'd1;
                        case (msg_sel)
// msg_sel 0 (len 117)
0: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "=";
        3: fifo_din <= "=";
        4: fifo_din <= "=";
        5: fifo_din <= " ";
        6: fifo_din <= "N";
        7: fifo_din <= "a";
        8: fifo_din <= "n";
        9: fifo_din <= "o";
        10: fifo_din <= "M";
        11: fifo_din <= "a";
        12: fifo_din <= "c";
        13: fifo_din <= " ";
        14: fifo_din <= "I";
        15: fifo_din <= "C";
        16: fifo_din <= "E";
        17: fifo_din <= " ";
        18: fifo_din <= "D";
        19: fifo_din <= "e";
        20: fifo_din <= "b";
        21: fifo_din <= "u";
        22: fifo_din <= "g";
        23: fifo_din <= "g";
        24: fifo_din <= "e";
        25: fifo_din <= "r";
        26: fifo_din <= " ";
        27: fifo_din <= "=";
        28: fifo_din <= "=";
        29: fifo_din <= "=";
        30: fifo_din <= 8'h0D;
        31: fifo_din <= 8'h0A;
        32: fifo_din <= "C";
        33: fifo_din <= "o";
        34: fifo_din <= "m";
        35: fifo_din <= "m";
        36: fifo_din <= "a";
        37: fifo_din <= "n";
        38: fifo_din <= "d";
        39: fifo_din <= "s";
        40: fifo_din <= ":";
        41: fifo_din <= " ";
        42: fifo_din <= "s";
        43: fifo_din <= "=";
        44: fifo_din <= "S";
        45: fifo_din <= "t";
        46: fifo_din <= "a";
        47: fifo_din <= "t";
        48: fifo_din <= "e";
        49: fifo_din <= " ";
        50: fifo_din <= "H";
        51: fifo_din <= "=";
        52: fifo_din <= "H";
        53: fifo_din <= "a";
        54: fifo_din <= "l";
        55: fifo_din <= "t";
        56: fifo_din <= " ";
        57: fifo_din <= "r";
        58: fifo_din <= "=";
        59: fifo_din <= "R";
        60: fifo_din <= "u";
        61: fifo_din <= "n";
        62: fifo_din <= " ";
        63: fifo_din <= "R";
        64: fifo_din <= "=";
        65: fifo_din <= "R";
        66: fifo_din <= "e";
        67: fifo_din <= "s";
        68: fifo_din <= "e";
        69: fifo_din <= "t";
        70: fifo_din <= " ";
        71: fifo_din <= "1";
        72: fifo_din <= "=";
        73: fifo_din <= "P";
        74: fifo_din <= "h";
        75: fifo_din <= "a";
        76: fifo_din <= "s";
        77: fifo_din <= "e";
        78: fifo_din <= " ";
        79: fifo_din <= "8";
        80: fifo_din <= "=";
        81: fifo_din <= "C";
        82: fifo_din <= "y";
        83: fifo_din <= "c";
        84: fifo_din <= " ";
        85: fifo_din <= "b";
        86: fifo_din <= "=";
        87: fifo_din <= "B";
        88: fifo_din <= "u";
        89: fifo_din <= "s";
        90: fifo_din <= " ";
        91: fifo_din <= "a";
        92: fifo_din <= "=";
        93: fifo_din <= "A";
        94: fifo_din <= "r";
        95: fifo_din <= "m";
        96: fifo_din <= " ";
        97: fifo_din <= "d";
        98: fifo_din <= "=";
        99: fifo_din <= "D";
        100: fifo_din <= "u";
        101: fifo_din <= "m";
        102: fifo_din <= "p";
        103: fifo_din <= " ";
        104: fifo_din <= "D";
        105: fifo_din <= "=";
        106: fifo_din <= "A";
        107: fifo_din <= "l";
        108: fifo_din <= "l";
        109: fifo_din <= " ";
        110: fifo_din <= "B";
        111: fifo_din <= "=";
        112: fifo_din <= "B";
        113: fifo_din <= "i";
        114: fifo_din <= "n";
        115: fifo_din <= 8'h0D;
        116: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end
// msg_sel 1 (len 16)
1: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "[";
        3: fifo_din <= "C";
        4: fifo_din <= "P";
        5: fifo_din <= "U";
        6: fifo_din <= " ";
        7: fifo_din <= "H";
        8: fifo_din <= "a";
        9: fifo_din <= "l";
        10: fifo_din <= "t";
        11: fifo_din <= "e";
        12: fifo_din <= "d";
        13: fifo_din <= "]";
        14: fifo_din <= 8'h0D;
        15: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end
// msg_sel 2 (len 17)
2: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "[";
        3: fifo_din <= "C";
        4: fifo_din <= "P";
        5: fifo_din <= "U";
        6: fifo_din <= " ";
        7: fifo_din <= "R";
        8: fifo_din <= "e";
        9: fifo_din <= "s";
        10: fifo_din <= "u";
        11: fifo_din <= "m";
        12: fifo_din <= "e";
        13: fifo_din <= "d";
        14: fifo_din <= "]";
        15: fifo_din <= 8'h0D;
        16: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end
// msg_sel 3 (len 15)
3: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "[";
        3: fifo_din <= "C";
        4: fifo_din <= "P";
        5: fifo_din <= "U";
        6: fifo_din <= " ";
        7: fifo_din <= "R";
        8: fifo_din <= "e";
        9: fifo_din <= "s";
        10: fifo_din <= "e";
        11: fifo_din <= "t";
        12: fifo_din <= "]";
        13: fifo_din <= 8'h0D;
        14: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end
// msg_sel 4 (len 22)
4: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "[";
        3: fifo_din <= "T";
        4: fifo_din <= "r";
        5: fifo_din <= "a";
        6: fifo_din <= "c";
        7: fifo_din <= "e";
        8: fifo_din <= " ";
        9: fifo_din <= "A";
        10: fifo_din <= "r";
        11: fifo_din <= "m";
        12: fifo_din <= "e";
        13: fifo_din <= "d";
        14: fifo_din <= " ";
        15: fifo_din <= "(";
        16: fifo_din <= "A";
        17: fifo_din <= "S";
        18: fifo_din <= ")";
        19: fifo_din <= "]";
        20: fifo_din <= 8'h0D;
        21: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end
// msg_sel 5 (len 21)
5: begin
    case (msg_idx)
        0: fifo_din <= 8'h0D;
        1: fifo_din <= 8'h0A;
        2: fifo_din <= "[";
        3: fifo_din <= "T";
        4: fifo_din <= "r";
        5: fifo_din <= "a";
        6: fifo_din <= "c";
        7: fifo_din <= "e";
        8: fifo_din <= " ";
        9: fifo_din <= "T";
        10: fifo_din <= "r";
        11: fifo_din <= "i";
        12: fifo_din <= "g";
        13: fifo_din <= "g";
        14: fifo_din <= "e";
        15: fifo_din <= "r";
        16: fifo_din <= "e";
        17: fifo_din <= "d";
        18: fifo_din <= "]";
        19: fifo_din <= 8'h0D;
        20: fifo_din <= 8'h0A;
        default: fifo_din <= 8'h0A;
    endcase
end

                        endcase
                        if (msg_idx == (msg_len - 1))
                            state <= S_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // Wait for single-step completion
                // -------------------------------------------------------------
                S_WAIT_STEP: begin
                    if (!stepping_clocks && !stepping_bus || step_timeout == 20'd0) begin
                        if (print_after_step) begin
                            sample_latch <= probes;
                            dump_col     <= 0;
                            state        <= S_PRINT_STAT;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        step_timeout <= step_timeout - 20'd1;
                    end
                end

                // -------------------------------------------------------------
                // Print single formatted 64-bit state line
                // Format: "A:xxxxxx D:xx RW:x AS:x DT:x RM:x RO:x V:x PH:x T:x H:x\r\n"
                // -------------------------------------------------------------
                                S_PRINT_STAT: begin
                    if (fifo_has_room) begin
                        fifo_wr  <= 1'b1;
                        dump_col <= dump_col + 6'd1;
                        case (dump_col)
                            0:  fifo_din <= 8'h0D;
                            1:  fifo_din <= 8'h0A;
                            2:  fifo_din <= "A";
                            3:  fifo_din <= ":";
                            4:  fifo_din <= hex2ascii(sample_latch[55:52]);
                            5:  fifo_din <= hex2ascii(sample_latch[51:48]);
                            6:  fifo_din <= hex2ascii(sample_latch[47:44]);
                            7:  fifo_din <= hex2ascii(sample_latch[43:40]);
                            8:  fifo_din <= hex2ascii(sample_latch[39:36]);
                            9:  fifo_din <= hex2ascii(sample_latch[35:32]);
                            10: fifo_din <= " ";
                            11: fifo_din <= "D";
                            12: fifo_din <= ":";
                            13: fifo_din <= hex2ascii(sample_latch[63:60]);
                            14: fifo_din <= hex2ascii(sample_latch[59:56]);
                            15: fifo_din <= " ";
                            16: fifo_din <= sample_latch[9] ? "R" : "W";
                            17: fifo_din <= " ";
                            18: fifo_din <= "A";
                            19: fifo_din <= "S";
                            20: fifo_din <= ":";
                            21: fifo_din <= sample_latch[6] ? "1" : "0";
                            22: fifo_din <= " ";
                            23: fifo_din <= "D";
                            24: fifo_din <= "T";
                            25: fifo_din <= ":";
                            26: fifo_din <= sample_latch[10] ? "1" : "0";
                            27: fifo_din <= " ";
                            28: fifo_din <= "R";
                            29: fifo_din <= "M";
                            30: fifo_din <= ":";
                            31: fifo_din <= sample_latch[19] ? "1" : "0";
                            32: fifo_din <= " ";
                            33: fifo_din <= "P";
                            34: fifo_din <= "H";
                            35: fifo_din <= ":";
                            36: fifo_din <= hex2ascii({1'b0, sample_latch[28:26]});
                            37: fifo_din <= " ";
                            38: fifo_din <= "T";
                            39: fifo_din <= "R";
                            40: fifo_din <= ":";
                            41: fifo_din <= sample_latch[5] ? "1" : "0";
                            42: fifo_din <= 8'h0D;
                            43: fifo_din <= 8'h0A;
                            default: fifo_din <= 8'h0A;
                        endcase
                        if (dump_col == 6'd43) begin
                            state <= S_IDLE;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Dump Formatted Trace Row
                // -------------------------------------------------------------
                S_DUMP_HDR: begin
                    if (fifo_has_room) begin
                        fifo_wr  <= 1'b1;
                        dump_col <= dump_col + 6'd1;
                        case (dump_col)
                            0:  fifo_din <= 8'h0D;
                            1:  fifo_din <= 8'h0A;
                            2:  fifo_din <= "#";
                            3:  fifo_din <= "S";
                            4:  fifo_din <= "M";
                            5:  fifo_din <= "P";
                            6:  fifo_din <= "L";
                            7:  fifo_din <= " ";
                            8:  fifo_din <= "A";
                            9:  fifo_din <= "D";
                            10: fifo_din <= "D";
                            11: fifo_din <= "R";
                            12: fifo_din <= " ";
                            13: fifo_din <= " ";
                            14: fifo_din <= " ";
                            15: fifo_din <= "D";
                            16: fifo_din <= "A";
                            17: fifo_din <= "T";
                            18: fifo_din <= "A";
                            19: fifo_din <= " ";
                            20: fifo_din <= "R";
                            21: fifo_din <= "W";
                            22: fifo_din <= " ";
                            23: fifo_din <= "A";
                            24: fifo_din <= "S";
                            25: fifo_din <= " ";
                            26: fifo_din <= "D";
                            27: fifo_din <= "T";
                            28: fifo_din <= " ";
                            29: fifo_din <= "R";
                            30: fifo_din <= "M";
                            31: fifo_din <= " ";
                            32: fifo_din <= "R";
                            33: fifo_din <= "O";
                            34: fifo_din <= " ";
                            35: fifo_din <= "P";
                            36: fifo_din <= "H";
                            37: fifo_din <= " ";
                            38: fifo_din <= "T";
                            39: fifo_din <= "R";
                            40: fifo_din <= 8'h0D;
                            41: fifo_din <= 8'h0A;
                            default: fifo_din <= 8'h0A;
                        endcase
                        if (dump_col == 6'd41) begin
                            dump_col <= 0;
                            state    <= S_DUMP_ROW;
                        end
                    end
                end

                S_DUMP_ROW: begin
                    if (fifo_has_room) begin
                        fifo_wr  <= 1'b1;
                        dump_col <= dump_col + 6'd1;
                        case (dump_col)
                            0:  fifo_din <= hex2ascii({3'b000, dump_cur[8]});
                            1:  fifo_din <= hex2ascii(dump_cur[7:4]);
                            2:  fifo_din <= hex2ascii(dump_cur[3:0]);
                            3:  fifo_din <= ":";
                            4:  fifo_din <= " ";
                            5:  fifo_din <= " ";
                            6:  fifo_din <= hex2ascii(trace_rd_data[55:52]);
                            7:  fifo_din <= hex2ascii(trace_rd_data[51:48]);
                            8:  fifo_din <= hex2ascii(trace_rd_data[47:44]);
                            9:  fifo_din <= hex2ascii(trace_rd_data[43:40]);
                            10: fifo_din <= hex2ascii(trace_rd_data[39:36]);
                            11: fifo_din <= hex2ascii(trace_rd_data[35:32]);
                            12: fifo_din <= " ";
                            13: fifo_din <= hex2ascii(trace_rd_data[63:60]);
                            14: fifo_din <= hex2ascii(trace_rd_data[59:56]);
                            15: fifo_din <= " ";
                            16: fifo_din <= " ";
                            17: fifo_din <= " ";
                            18: fifo_din <= trace_rd_data[9] ? "R" : "W";
                            19: fifo_din <= " ";
                            20: fifo_din <= " ";
                            21: fifo_din <= trace_rd_data[6] ? "1" : "0"; // AS
                            22: fifo_din <= " ";
                            23: fifo_din <= " ";
                            24: fifo_din <= trace_rd_data[10] ? "1" : "0"; // DTACK
                            25: fifo_din <= " ";
                            26: fifo_din <= " ";
                            27: fifo_din <= trace_rd_data[19] ? "1" : "0"; // RAM
                            28: fifo_din <= " ";
                            29: fifo_din <= " ";
                            30: fifo_din <= trace_rd_data[20] ? "1" : "0"; // ROM
                            31: fifo_din <= " ";
                            32: fifo_din <= " ";
                            33: fifo_din <= hex2ascii({1'b0, trace_rd_data[28:26]}); // SDRAM phase
                            34: fifo_din <= " ";
                            35: fifo_din <= " ";
                            36: fifo_din <= trace_rd_data[5] ? "1" : "0"; // Turbo
                            37: fifo_din <= " ";
                            38: fifo_din <= 8'h0D;
                            39: fifo_din <= 8'h0A;
                            default: fifo_din <= 8'h0A;
                        endcase

                        if (dump_col == 6'd39) begin
                            dump_col <= 0;
                            state    <= S_DUMP_GAP;
                        end
                    end
                end

                S_DUMP_GAP: begin
                    if (fifo_count < 9'd16) begin
                        if (dump_cnt == 10'd1) begin
                            state <= S_IDLE;
                        end else begin
                            dump_cnt      <= dump_cnt - 10'd1;
                            dump_cur      <= dump_cur + 9'd1;
                            trace_rd_addr <= dump_cur + 9'd1;
                            dump_col      <= 0;
                            state         <= S_DUMP_ROW;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Binary Dump (Raw 8 bytes per sample x 512 = 4096 bytes)
                // -------------------------------------------------------------
                S_DUMP_BIN: begin
                    if (fifo_has_room) begin
                        fifo_wr      <= 1'b1;
                        bin_byte_idx <= bin_byte_idx + 3'd1;
                        case (bin_byte_idx)
                            0: fifo_din <= trace_rd_data[7:0];
                            1: fifo_din <= trace_rd_data[15:8];
                            2: fifo_din <= trace_rd_data[23:16];
                            3: fifo_din <= trace_rd_data[31:24];
                            4: fifo_din <= trace_rd_data[39:32];
                            5: fifo_din <= trace_rd_data[47:40];
                            6: fifo_din <= trace_rd_data[55:48];
                            7: fifo_din <= trace_rd_data[63:56];
                        endcase

                        if (bin_byte_idx == 3'd7) begin
                            bin_byte_idx <= 0;
                            if (dump_cnt == 10'd1) begin
                                state <= S_IDLE;
                            end else begin
                                dump_cnt      <= dump_cnt - 10'd1;
                                dump_cur      <= dump_cur + 9'd1;
                                trace_rd_addr <= dump_cur + 9'd1;
                            end
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
