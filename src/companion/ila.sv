/*
    ila.sv - On-chip Integrated Logic Analyzer & In-Circuit Debugger (ICE)
    for NanoMac (Apple Macintosh Plus on Tang Nano 20K)

    Features:
    1. Passive ILA: 512 samples x 64-bit circular trace buffer in BSRAM.
       Configurable trigger (address match, _cpuAS falling edge, DTACK, collisions).
    2. Active ICE: Halt, Resume, Single-step N clock phases, Single-step N bus cycles,
       and CPU reset control.
    3. Live Snapshot: Instantaneous 64-bit probe readout via SPI while halted.
*/

module ila (
    input               clk,            // System clock (78.336 MHz)
    input               reset,          // Asynchronous system reset / PLL unlock

    // CPU clock gating interface
    input               enPhi1_in,      // Input Phi1 clock enable from core
    input               enPhi2_in,      // Input Phi2 clock enable from core
    output              enPhi1_out,     // Gated Phi1 clock enable to fx68k
    output              enPhi2_out,     // Gated Phi2 clock enable to fx68k
    output              cpu_reset_override, // ICE forced reset

    // Signals to monitor / capture
    input  [63:0]       probes,         // 64-bit signal probe bundle
    input               _cpuAS,         // Address strobe for bus-cycle edge detect

    // SPI interface from mcu_spi (Target 5)
    input               strobe,         // Byte strobe
    input               start,          // First byte of message
    input  [7:0]        din,            // Byte from MCU
    output reg [7:0]    dout,           // Byte to MCU

    // Direct hardware UART pins (FT2232 Channel 1)
    input               uart_rx,
    output              uart_tx
);

    // -------------------------------------------------------------------------
    // 1. In-Circuit Debugger (ICE) Execution Controller
    // -------------------------------------------------------------------------
    reg        halted;
    reg [15:0] step_clock_cnt;
    reg [15:0] step_bus_cnt;
    reg [7:0]  ice_reset_timer;

    reg        ice_cmd_strobe;
    reg [7:0]  ice_subcmd;
    reg [15:0] ice_step_val;

    // Bus cycle edge detection for bus-stepping
    reg _cpuAS_d;
    always @(posedge clk) begin
        if (reset)
            _cpuAS_d <= 1'b1;
        else
            _cpuAS_d <= _cpuAS;
    end
    wire bus_cycle_done = (!_cpuAS_d && _cpuAS); // Rising edge of _cpuAS

    // Clock gating logic
    // CPU runs if not halted, or while step counters are non-zero
    wire stepping_clocks = (step_clock_cnt != 16'd0);
    wire stepping_bus    = (step_bus_cnt != 16'd0);
    wire cpu_allowed     = !halted || stepping_clocks || stepping_bus;

    assign enPhi1_out = cpu_allowed ? enPhi1_in : 1'b0;
    assign enPhi2_out = cpu_allowed ? enPhi2_in : 1'b0;
    assign cpu_reset_override = (ice_reset_timer != 8'd0);

    always @(posedge clk) begin
        if (reset) begin
            halted          <= 1'b0;
            step_clock_cnt  <= 16'd0;
            step_bus_cnt    <= 16'd0;
            ice_reset_timer <= 8'd0;
        end else begin
            // Reset timer countdown
            if (ice_reset_timer != 8'd0)
                ice_reset_timer <= ice_reset_timer - 8'd1;

            if (uart_halt_req) begin
                halted <= 1'b1; // Halt from UART
            end else if (uart_resume_req) begin
                halted         <= 1'b0; // Resume from UART
                step_clock_cnt <= 16'd0;
                step_bus_cnt   <= 16'd0;
            end else if (uart_reset_req) begin
                ice_reset_timer <= 8'd255; // Reset from UART
            end else if (uart_step_clock_req) begin
                step_clock_cnt <= uart_step_val;
                halted         <= 1'b0;
            end else if (uart_step_bus_req) begin
                step_bus_cnt   <= uart_step_val;
                halted         <= 1'b0;
            end else if (ice_cmd_strobe) begin
                case (ice_subcmd)
                    8'd0: halted <= 1'b1; // Halt
                    8'd1: begin           // Resume
                        halted         <= 1'b0;
                        step_clock_cnt <= 16'd0;
                        step_bus_cnt   <= 16'd0;
                    end
                    8'd2: ice_reset_timer <= 8'd255; // Reset pulse
                    8'd3: begin           // Step N clocks
                        step_clock_cnt <= ice_step_val;
                        halted         <= 1'b0;
                    end
                    8'd4: begin           // Step N bus cycles
                        step_bus_cnt   <= ice_step_val;
                        halted         <= 1'b0;
                    end
                    default: ;
                endcase
            end else begin
                // Step clock countdown on each completed Phi2 pulse
                if (stepping_clocks && enPhi2_in) begin
                    step_clock_cnt <= step_clock_cnt - 16'd1;
                    if (step_clock_cnt == 16'd1)
                        halted <= 1'b1;
                end

                // Step bus cycle countdown on each completed bus cycle
                if (stepping_bus && bus_cycle_done) begin
                    step_bus_cnt <= step_bus_cnt - 16'd1;
                    if (step_bus_cnt == 16'd1)
                        halted <= 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. ILA 512 x 64 Trace Buffer (Block RAM)
    // -------------------------------------------------------------------------
    localparam BUFFER_DEPTH = 512;
    localparam ADDR_WIDTH   = 9;

    reg [63:0] trace_ram [0:BUFFER_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [2:0]            rd_byte_idx;
    reg [63:0]           rd_data_latch;

    reg sample_clk_sel; // 0 = clk (78MHz), 1 = pixel clock (phase 0)
    wire sample_tick = sample_clk_sel ? (probes[2:0] == 3'd0) : 1'b1;

    // Trigger state machine
    localparam ILA_IDLE      = 3'd0;
    localparam ILA_ARM_PRE   = 3'd1;
    localparam ILA_ARMED     = 3'd2;
    localparam ILA_POST_FILL = 3'd3;
    localparam ILA_DONE      = 3'd4;

    reg [2:0]            ila_state;
    reg [ADDR_WIDTH-1:0] trigger_pos;
    reg [ADDR_WIDTH-1:0] pre_count;
    reg [ADDR_WIDTH-1:0] post_count;

    // Trigger configuration
    reg [2:0]  trig_mode;       // 0=Manual, 1=AS low, 2=DTACK low, 3=Addr match, 4=RAM collision
    reg [23:0] trig_addr;
    reg [23:0] trig_mask;
    reg        force_trigger;

    reg        ila_arm_req;
    reg        ila_disarm_req;
    reg        force_trig_req;

    // Trigger condition evaluation
    wire [23:0] cpu_addr = probes[55:32];
    wire _as             = probes[6];
    wire _dtack          = probes[10];
    wire ram_collision   = probes[19] && probes[15] && (probes[16] || probes[17]); // RAM access during video/audio DMA

    wire addr_match = ((cpu_addr & trig_mask) == (trig_addr & trig_mask));

    reg trigger_hit;
    always @(*) begin
        case (trig_mode)
            3'd0: trigger_hit = force_trigger;
            3'd1: trigger_hit = force_trigger || !_as;
            3'd2: trigger_hit = force_trigger || (!_as && !_dtack);
            3'd3: trigger_hit = force_trigger || (!_as && addr_match);
            3'd4: trigger_hit = force_trigger || ram_collision;
            default: trigger_hit = force_trigger;
        endcase
    end

    // Circular capture logic
    always @(posedge clk) begin
        if (reset || ila_disarm_req || uart_disarm_req) begin
            ila_state     <= ILA_IDLE;
            wr_ptr        <= 0;
            pre_count     <= 0;
            post_count    <= 0;
            trigger_pos   <= 0;
            force_trigger <= 1'b0;
        end else if (ila_arm_req || uart_arm_req) begin
            ila_state     <= ILA_ARM_PRE;
            wr_ptr        <= 0;
            pre_count     <= 0;
            post_count    <= 0;
            trigger_pos   <= 0;
            force_trigger <= 1'b0;
        end else begin
            if (force_trig_req || uart_force_trig_req)
                force_trigger <= 1'b1;
            else if (force_trigger)
                force_trigger <= 1'b0;

            case (ila_state)
                ILA_IDLE: begin
                    // Wait for ARM command
                end

                ILA_ARM_PRE: begin
                    // Fill at least 64 pre-trigger samples
                    if (sample_tick) begin
                        trace_ram[wr_ptr] <= probes;
                        wr_ptr <= wr_ptr + 1'b1;
                        pre_count <= pre_count + 1'b1;
                        if (pre_count >= 9'd64)
                            ila_state <= ILA_ARMED;
                    end
                end

                ILA_ARMED: begin
                    if (sample_tick) begin
                        trace_ram[wr_ptr] <= probes;
                        wr_ptr <= wr_ptr + 1'b1;

                        if (trigger_hit) begin
                            trigger_pos <= wr_ptr;
                            post_count  <= 0;
                            ila_state   <= ILA_POST_FILL;
                        end
                    end
                end

                ILA_POST_FILL: begin
                    if (sample_tick) begin
                        trace_ram[wr_ptr] <= probes;
                        wr_ptr <= wr_ptr + 1'b1;
                        post_count <= post_count + 1'b1;
                        // Fill remaining samples (448 post-trigger)
                        if (post_count >= (BUFFER_DEPTH - 9'd65))
                            ila_state <= ILA_DONE;
                    end
                end

                ILA_DONE: begin
                    // Capture stopped, ready to read
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 3. SPI Protocol Interface (Target 5)
    // -------------------------------------------------------------------------
    reg [7:0] cmd;
    reg [4:0] byte_cnt;

    always @(posedge clk) begin
        if (reset) begin
            cmd             <= 8'h00;
            byte_cnt        <= 5'd0;
            dout            <= 8'h00;
            rd_ptr          <= 0;
            rd_byte_idx     <= 0;
            trig_mode       <= 3'd1; // Default: trigger on _cpuAS low
            trig_addr       <= 24'h000000;
            trig_mask       <= 24'hFFFFFF;
            sample_clk_sel  <= 1'b0;
            ice_cmd_strobe  <= 1'b0;
            ice_subcmd      <= 8'h00;
            ice_step_val    <= 16'd0;
            ila_arm_req     <= 1'b0;
            ila_disarm_req  <= 1'b0;
            force_trig_req  <= 1'b0;
        end else begin
            if (uart_arm_req)
                trig_mode <= uart_trig_mode;
            if (ice_cmd_strobe)
                ice_cmd_strobe <= 1'b0;
            if (ila_arm_req)
                ila_arm_req <= 1'b0;
            if (ila_disarm_req)
                ila_disarm_req <= 1'b0;
            if (force_trig_req)
                force_trig_req <= 1'b0;

            if (strobe) begin
                if (start) begin
                    cmd      <= din;
                    byte_cnt <= 5'd0;

                    // On starting READ_SAMPLE, reset read pointer
                    if (din == 8'd2) begin
                        rd_ptr      <= 0;
                        rd_byte_idx <= 0;
                    end
                end else begin
                    byte_cnt <= byte_cnt + 5'd1;

                    case (cmd)
                        // ---------------------------------------------------------
                        // CMD 0: Status & Info
                        // ---------------------------------------------------------
                        8'd0: begin
                            case (byte_cnt)
                                5'd0: dout <= { 3'b001, (ila_state == ILA_DONE), (ila_state >= ILA_POST_FILL), (ila_state == ILA_ARMED || ila_state == ILA_ARM_PRE), halted, 1'b1 };
                                5'd1: dout <= 8'd2; // 512 depth MSB (512 >> 8)
                                5'd2: dout <= 8'd0; // 512 depth LSB
                                5'd3: dout <= { 7'd0, trigger_pos[8] };
                                5'd4: dout <= trigger_pos[7:0];
                                5'd5: dout <= { 7'd0, wr_ptr[8] };
                                5'd6: dout <= wr_ptr[7:0];
                                default: dout <= 8'h00;
                            endcase
                        end

                        // ---------------------------------------------------------
                        // CMD 1: Config (Clock & Trigger setup)
                        // ---------------------------------------------------------
                        8'd1: begin
                            case (byte_cnt)
                                5'd0: sample_clk_sel    <= din[0];
                                5'd1: trig_mode         <= din[2:0];
                                5'd2: trig_addr[23:16]  <= din;
                                5'd3: trig_addr[15:8]   <= din;
                                5'd4: trig_addr[7:0]    <= din;
                                5'd5: trig_mask[23:16]  <= din;
                                5'd6: trig_mask[15:8]   <= din;
                                5'd7: trig_mask[7:0]    <= din;
                                default: ;
                            endcase
                            dout <= 8'hA5; // ACK
                        end

                        // ---------------------------------------------------------
                        // CMD 2: Read Trace Buffer (Streams 8 bytes per sample)
                        // ---------------------------------------------------------
                        8'd2: begin
                            case (rd_byte_idx)
                                3'd0: dout <= trace_ram[rd_ptr][7:0];
                                3'd1: dout <= trace_ram[rd_ptr][15:8];
                                3'd2: dout <= trace_ram[rd_ptr][23:16];
                                3'd3: dout <= trace_ram[rd_ptr][31:24];
                                3'd4: dout <= trace_ram[rd_ptr][39:32];
                                3'd5: dout <= trace_ram[rd_ptr][47:40];
                                3'd6: dout <= trace_ram[rd_ptr][55:48];
                                3'd7: dout <= trace_ram[rd_ptr][63:56];
                            endcase

                            rd_byte_idx <= rd_byte_idx + 1'b1;
                            if (rd_byte_idx == 3'd7) begin
                                if (rd_ptr < (BUFFER_DEPTH - 1))
                                    rd_ptr <= rd_ptr + 1'b1;
                            end
                        end

                        // ---------------------------------------------------------
                        // CMD 3: Arm / Disarm / Force Trigger
                        // ---------------------------------------------------------
                        8'd3: begin
                            if (byte_cnt == 5'd0) begin
                                if (din == 8'd1) begin
                                    ila_arm_req <= 1'b1;
                                end else if (din == 8'd0) begin
                                    ila_disarm_req <= 1'b1;
                                end else if (din == 8'd2) begin
                                    force_trig_req <= 1'b1;
                                end
                            end
                            dout <= 8'h5A; // ACK
                        end

                        // ---------------------------------------------------------
                        // CMD 4: ICE Execution Control (Halt, Resume, Step, Reset)
                        // ---------------------------------------------------------
                        8'd4: begin
                            case (byte_cnt)
                                5'd0: begin
                                    ice_subcmd <= din;
                                    if (din == 8'd0 || din == 8'd1 || din == 8'd2) begin
                                        ice_step_val   <= 16'd0;
                                        ice_cmd_strobe <= 1'b1;
                                    end
                                end
                                // Bytes 1..2: Step count high/low
                                5'd1: begin
                                    ice_step_val[15:8] <= din;
                                end
                                5'd2: begin
                                    ice_step_val[7:0] <= din;
                                    ice_cmd_strobe    <= 1'b1;
                                end
                                default: ;
                            endcase
                            dout <= { 7'd0, halted };
                        end

                        // ---------------------------------------------------------
                        // CMD 5: Live Hardware State Readout (8 bytes instantaneous)
                        // ---------------------------------------------------------
                        8'd5: begin
                            case (byte_cnt)
                                5'd0: dout <= probes[7:0];
                                5'd1: dout <= probes[15:8];
                                5'd2: dout <= probes[23:16];
                                5'd3: dout <= probes[31:24];
                                5'd4: dout <= probes[39:32];
                                5'd5: dout <= probes[47:40];
                                5'd6: dout <= probes[55:48];
                                5'd7: dout <= probes[63:56];
                                default: dout <= 8'h00;
                            endcase
                        end

                        default: dout <= 8'h00;
                    endcase
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 4. Hardware UART Controller (FT2232 Channel 1 on Pins 69/70)
    // -------------------------------------------------------------------------
    wire [8:0]  trace_rd_addr_uart;
    wire [63:0] trace_rd_data_uart = trace_ram[trace_rd_addr_uart];

    wire        uart_halt_req;
    wire        uart_resume_req;
    wire        uart_reset_req;
    wire        uart_step_clock_req;
    wire        uart_step_bus_req;
    wire [15:0] uart_step_val;
    wire        uart_arm_req;
    wire        uart_disarm_req;
    wire        uart_force_trig_req;
    wire [2:0]  uart_trig_mode;

    ila_uart #(
        .CLK_FREQ(15667200),
        .BAUD_RATE(2000000),
        .DIVISOR(8)
    ) ila_uart_inst (
        .clk(clk),
        .reset(reset),
        .rx_pin(uart_rx),
        .tx_pin(uart_tx),
        .probes(probes),
        .halted(halted),
        .stepping_clocks(stepping_clocks),
        .stepping_bus(stepping_bus),
        .ila_state(ila_state),
        .wr_ptr(wr_ptr),
        .trigger_pos(trigger_pos),
        .trace_rd_addr(trace_rd_addr_uart),
        .trace_rd_data(trace_rd_data_uart),
        .uart_halt_req(uart_halt_req),
        .uart_resume_req(uart_resume_req),
        .uart_reset_req(uart_reset_req),
        .uart_step_clock_req(uart_step_clock_req),
        .uart_step_bus_req(uart_step_bus_req),
        .uart_step_val(uart_step_val),
        .uart_arm_req(uart_arm_req),
        .uart_disarm_req(uart_disarm_req),
        .uart_force_trig_req(uart_force_trig_req),
        .uart_trig_mode(uart_trig_mode)
    );

endmodule
