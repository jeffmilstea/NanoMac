`timescale 1ns/1ps

module tb_via_irq_storm (
    input clk,
    input reset,
    input turbo_mode,
    output [23:0] dbg_addr,
    output        dbg_as,
    output        dbg_rw,
    output        dbg_dtack,
    output [2:0]  dbg_fc,
    output [2:0]  dbg_pswi,
    output        dbg_via_irq,
    output [6:0]  dbg_irq_flags,
    output [6:0]  dbg_irq_mask,
    output [15:0] dbg_t2_count,
    output        dbg_t2_trig
);

    reg [2:0] phase = 3'd0;
    always @(posedge clk or posedge reset) begin
        if (reset)
            phase <= 3'd0;
        else
            phase <= phase + 3'd1;
    end

    wire clk8_en_p = (phase[0] == 1'b1);
    wire clk8_en_n = (phase[0] == 1'b0);

    reg turbo_phase = 1'b0;
    always @(posedge clk or posedge reset) begin
        if (reset)
            turbo_phase <= 1'b0;
        else
            turbo_phase <= !turbo_phase;
    end

    wire enPhi1 = turbo_mode ? turbo_phase : clk8_en_p;
    wire enPhi2 = turbo_mode ? !turbo_phase : clk8_en_n;

    // Fixed 783.36 kHz timer tick (div 20)
    reg [4:0] via_timer_div = 5'd0;
    reg via_timer_tick = 1'b0;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            via_timer_div  <= 5'd0;
            via_timer_tick <= 1'b0;
        end else begin
            if (via_timer_div == 5'd19) begin
                via_timer_div  <= 5'd0;
                via_timer_tick <= 1'b1;
            end else begin
                via_timer_div  <= via_timer_div + 5'd1;
                via_timer_tick <= 1'b0;
            end
        end
    end

    // fx68k signals
    wire _cpuRW, _cpuAS, _cpuLDS, _cpuUDS;
    wire _cpuVMA, _cpuVPA, _cpuDTACK;
    wire fx68k_e_pos, fx68k_e_neg;
    wire [2:0] cpuFC;
    wire [23:1] cpuAddr;
    wire [15:0] cpuDataOut;
    reg  [15:0] cpuDataIn;

    // Address decode
    wire selectVIA = !_cpuAS && (cpuAddr[23:20] == 4'b1110 && cpuAddr[19]); // 0xEFxxxx
    wire selectRAM = !_cpuAS && (cpuAddr[23:22] == 2'b00); // 0x00xxxx-0x3Fxxxx
    wire selectROM = !_cpuAS && (cpuAddr[23:20] == 4'b0100); // 0x40xxxx
    wire is_iack   = !_cpuAS && (cpuFC == 3'b111);

    assign _cpuVPA = 1'b1;

    reg [2:0] dtack_wait = 3'd0;
    always @(posedge clk or posedge reset) begin
        if (reset || _cpuAS)
            dtack_wait <= 3'd0;
        else if ((selectRAM || selectROM || selectVIA || is_iack) && dtack_wait < 3'd4)
            dtack_wait <= dtack_wait + 3'd1;
    end

    assign _cpuDTACK = ~((selectRAM || selectROM || selectVIA || is_iack) && (dtack_wait >= 3'd2));
    always @(posedge clk) begin
        if (selectVIA && !_cpuRW && !_cpuDTACK) begin
            $display("[VIA WRITE] Addr=0x%06X (Reg %X) DataIn=0x%02X uds=%b lds=%b", 
                     {cpuAddr[23:1], 1'b0}, cpuAddr[12:9], cpuDataOut[15:8], _cpuUDS, _cpuLDS);
        end
        if (selectVIA && _cpuRW && !_cpuDTACK) begin
            $display("[VIA READ]  Addr=0x%06X (Reg %X) DataOut=0x%02X", 
                     {cpuAddr[23:1], 1'b0}, cpuAddr[12:9], via_dout);
        end
    end

    // 64K words memory
    reg [15:0] mem [0:65535];
    integer j;
    initial begin
        for (j = 0; j < 65536; j = j + 1) mem[j] = 16'h0000;

        // Reset vectors
        mem[0] = 16'h0000; mem[1] = 16'h7000; // SSP = 0x00007000
        mem[2] = 16'h0040; mem[3] = 16'h0100; // PC  = 0x00400100

        // Autovector 25 (0x64) -> 0x0000BD26
        mem[16'h0064 >> 1] = 16'h0000;
        mem[16'h0066 >> 1] = 16'hBD26;

        // Low memory globals:
        // VIA base at 0x01D4 -> 0x00EFE1FE
        mem[16'h01D4 >> 1] = 16'h00EF;
        mem[16'h01D6 >> 1] = 16'hE1FE;

        // Vector table starting at 0x018E:
        // 0x018E + 20 (entry 5 = Timer 2) = 0x01A6 -> points to 0x00400200
        mem[16'h01A6 >> 1] = 16'h0040;
        mem[16'h01A8 >> 1] = 16'h0200;

        // -------------------------------------------------------------
        // User initialization code at 0x400100:
        // -------------------------------------------------------------
        // 400100: MOVE.W #, SR            ; Enable interrupts
        mem[16'h0100 >> 1] = 16'h46FC;
        mem[16'h0102 >> 1] = 16'h2000;
        // 400104: MOVEA.L #zshEFE1FE, A1       ; A1 = VIA base
        mem[16'h0104 >> 1] = 16'h227C;
        mem[16'h0106 >> 1] = 16'h00EF;
        mem[16'h0108 >> 1] = 16'hE1FE;
        // 40010A: MOVE.B #, C00(A1)       ; IER <= 0xA0 (Enable Timer 2 IRQ)
        mem[16'h010A >> 1] = 16'h137C;
        mem[16'h010C >> 1] = 16'h00A0;
        mem[16'h010E >> 1] = 16'h1C00;
        // 400110: MOVE.B #zsh, (A1)       ; Reg 9 (T2C-H) <= 0x00
        mem[16'h0110 >> 1] = 16'h137C;
        mem[16'h0112 >> 1] = 16'h0000;
        mem[16'h0114 >> 1] = 16'h1200;
        // 400116: MOVE.B #, (A1)       ; Reg 8 (T2L-L) <= 0x08 (8 ticks = ~10us)
        mem[16'h0116 >> 1] = 16'h137C;
        mem[16'h0118 >> 1] = 16'h0008;
        mem[16'h011A >> 1] = 16'h1000;
        // 40011C: user_loop: NOP, BRA.S user_loop
        mem[16'h011C >> 1] = 16'h4E71;
        mem[16'h011E >> 1] = 16'h60FE;

        // -------------------------------------------------------------
        // Level 1 wrapper in RAM at 0x00BD26:
        // -------------------------------------------------------------
        // MOVEM.L D0-D3/A0-A3, -(SP)
        mem[16'hBD26 >> 1] = 16'h48E7;
        mem[16'hBD28 >> 1] = 16'h0F0F;
        // JMP A60.L
        mem[16'hBD2A >> 1] = 16'h4EF9;
        mem[16'hBD2C >> 1] = 16'h0040;
        mem[16'hBD2E >> 1] = 16'h1A60;

        // -------------------------------------------------------------
        // ROM VIA Dispatcher at 0x401A60:
        // -------------------------------------------------------------
        // LEA E.W, A0
        mem[16'h1A60 >> 1] = 16'h41F8;
        mem[16'h1A62 >> 1] = 16'h018E;
        // MOVEA.L D4.W, A1
        mem[16'h1A64 >> 1] = 16'h2278;
        mem[16'h1A66 >> 1] = 16'h01D4;
        // MOVE.B A00(A1), D0 (Read IFR)
        mem[16'h1A68 >> 1] = 16'h1029;
        mem[16'h1A6A >> 1] = 16'h1A00;
        // AND.B C00(A1), D0 (Read IER)
        mem[16'h1A6C >> 1] = 16'hC029;
        mem[16'h1A6E >> 1] = 16'h1C00;
        // BCLR #7, D0
        mem[16'h1A70 >> 1] = 16'h08C0;
        mem[16'h1A72 >> 1] = 16'h0007;
        // loop: ADDQ.L #4, A0
        mem[16'h1A74 >> 1] = 16'h5888;
        // LSR.B #1, D0
        mem[16'h1A76 >> 1] = 16'hE208;
        // BCC.S loop (back to 1A74)
        mem[16'h1A78 >> 1] = 16'h64FA;
        // MOVEA.L (A0), A0
        mem[16'h1A7A >> 1] = 16'h2050;
        // JSR (A0)
        mem[16'h1A7C >> 1] = 16'h4E90;
        // MOVEM.L (SP)+, D0-D3/A0-A3
        mem[16'h1A7E >> 1] = 16'h4CDF;
        mem[16'h1A80 >> 1] = 16'h0F0F;
        // RTE
        mem[16'h1A82 >> 1] = 16'h4E73;

        // -------------------------------------------------------------
        // Timer 2 ISR handler at 0x400200:
        // -------------------------------------------------------------
        // MOVE.B $1000(A1), D0   ; Read Reg 8 (T2C-L) to clear Timer 2 IRQ!
        mem[16'h0200 >> 1] = 16'h1029;
        mem[16'h0202 >> 1] = 16'h1000;
        // MOVE.B #0, $1000(A1)   ; Write 0 to Reg 8 (simulate RmvTime canceling timer!)
        mem[16'h0204 >> 1] = 16'h137C;
        mem[16'h0206 >> 1] = 16'h0000;
        mem[16'h0208 >> 1] = 16'h1000;
        // RTS
        mem[16'h020A >> 1] = 16'h4E75;
    end

    // RAM writes
    always @(posedge clk) begin
        if (selectRAM && !_cpuRW && !_cpuDTACK) begin
            if (!_cpuUDS) mem[cpuAddr[15:1]][15:8] <= cpuDataOut[15:8];
            if (!_cpuLDS) mem[cpuAddr[15:1]][7:0]  <= cpuDataOut[7:0];
        end
    end

    // VIA instance
    wire [7:0] via_dout;
    wire via_irq;
    via6522 via_inst (
        .clock      ( clk ),
        .rising     ( fx68k_e_neg ),
        .falling    ( fx68k_e_pos ),
        .timer_tick ( via_timer_tick ),
        .reset      ( reset ),
        .addr       ( cpuAddr[12:9] ),
        .wen        ( selectVIA && !_cpuAS && !_cpuRW ),
        .ren        ( selectVIA && !_cpuAS &&  _cpuRW ),
        .data_in    ( cpuDataOut[15:8] ),
        .data_out   ( via_dout ),
        .phi2_ref   (),
        .port_a_o   (), .port_a_t(), .port_a_i(8'hFF),
        .port_b_o   (), .port_b_t(), .port_b_i(8'hFF),
        .ca1_i      ( 1'b1 ), .ca2_i( 1'b1 ),
        .cb1_i      ( 1'b1 ), .cb2_i( 1'b1 ),
        .cb2_o      (), .cb2_t(),
        .irq        ( via_irq )
    );

    wire [15:0] iack_vector = {8'd24 + {5'd0, cpuAddr[3:1]}, 8'd24 + {5'd0, cpuAddr[3:1]}};

    always @(*) begin
        if (cpuFC == 3'b111)
            cpuDataIn = iack_vector;
        else if (selectRAM || selectROM)
            cpuDataIn = mem[cpuAddr[15:1]];
        else if (selectVIA)
            cpuDataIn = { via_dout, 8'hEF };
        else
            cpuDataIn = 16'hFFFF;
    end

    // Level 1 IPL connected directly to VIA IRQ!
    wire [2:0] ipl = via_irq ? 3'b001 : 3'b000;

    fx68k cpu (
        .clk        ( clk ),
        .extReset   ( reset ),
        .pwrUp      ( reset ),
        .enPhi1     ( enPhi1 ),
        .enPhi2     ( enPhi2 ),
        .eRWn       ( _cpuRW ),
        .ASn        ( _cpuAS ),
        .LDSn       ( _cpuLDS ),
        .UDSn       ( _cpuUDS ),
        .E          ( ),
        .E_div      ( 1'b0 ),
        .E_PosClkEn ( fx68k_e_pos ),
        .E_NegClkEn ( fx68k_e_neg ),
        .VMAn       ( _cpuVMA ),
        .FC0        ( cpuFC[0] ),
        .FC1        ( cpuFC[1] ),
        .FC2        ( cpuFC[2] ),
        .BGn        (),
        .oRESETn    (),
        .oHALTEDn   (),
        .DTACKn     ( _cpuDTACK ),
        .VPAn       ( _cpuVPA ),
        .HALTn      ( 1'b1 ),
        .BERRn      ( 1'b1 ),
        .BRn        ( 1'b1 ),
        .BGACKn     ( 1'b1 ),
        .IPL0n      ( ~ipl[0] ),
        .IPL1n      ( ~ipl[1] ),
        .IPL2n      ( ~ipl[2] ),
        .iEdb       ( cpuDataIn ),
        .oEdb       ( cpuDataOut ),
        .eab        ( cpuAddr )
    );

    assign dbg_addr        = {cpuAddr[23:1], 1'b0};
    assign dbg_as          = _cpuAS;
    assign dbg_rw          = _cpuRW;
    assign dbg_dtack       = _cpuDTACK;
    assign dbg_fc          = cpuFC;
    assign dbg_pswi        = cpu.pswI;
    assign dbg_via_irq     = via_irq;
    assign dbg_irq_flags   = via_inst.irq_flags;
    assign dbg_irq_mask    = via_inst.irq_mask;
    assign dbg_t2_count    = via_inst.timer_b_count;
    assign dbg_t2_trig     = via_inst.timer_b_oneshot_trig;

endmodule
