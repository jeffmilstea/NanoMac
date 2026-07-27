// 
// Gowin Verilator Mocks
//

module ELVDS_OBUF (
    input  wire I,
    output wire O,
    output wire OB
);
    assign O  = I;
    assign OB = ~I;
endmodule

module Gowin_CLKDIV (
    input  wire hclkin,
    input  wire resetn,
    output reg  clkout
);
    always @(posedge hclkin or negedge resetn) begin
        if (!resetn)
            clkout <= 1'b0;
        else
            clkout <= ~clkout;
    end
endmodule

module rPLL #(
    parameter FCLKIN = "27",
    parameter DYN_IDIV_SEL = "false",
    parameter IDIV_SEL = 1,
    parameter DYN_FBDIV_SEL = "false",
    parameter FBDIV_SEL = 28,
    parameter DYN_ODIV_SEL = "false",
    parameter ODIV_SEL = 2,
    parameter PSDA_SEL = "0000",
    parameter DYN_DA_EN = "true",
    parameter DUTYDA_SEL = "1000",
    parameter CLKOUT_FT_DIR = 1'b1,
    parameter CLKOUTP_FT_DIR = 1'b1,
    parameter CLKOUT_DLY_STEP = 0,
    parameter CLKOUTP_DLY_STEP = 0,
    parameter CLKFB_SEL = "internal",
    parameter CLKOUT_BYPASS = "false",
    parameter CLKOUTP_BYPASS = "false",
    parameter CLKOUTD_BYPASS = "false",
    parameter DYN_SDIV_SEL = 2,
    parameter CLKOUTD_SRC = "CLKOUT",
    parameter CLKOUTD3_SRC = "CLKOUT",
    parameter DEVICE = "GW2AR-18C"
) (
    input  wire CLKIN,
    output wire CLKOUT,
    output wire LOCK,
    output wire CLKOUTP,
    output wire CLKOUTD,
    output wire CLKOUTD3,
    input  wire RESET,
    input  wire RESET_P,
    input  wire CLKFB,
    input  wire [5:0] FBDSEL,
    input  wire [5:0] IDSEL,
    input  wire [5:0] ODSEL,
    input  wire [3:0] PSDA,
    input  wire [3:0] DUTYDA,
    input  wire [3:0] FDLY
);
    assign CLKOUT = CLKIN;
    assign CLKOUTP = CLKIN;
    assign CLKOUTD = CLKIN;
    assign CLKOUTD3 = CLKIN;
    assign LOCK = ~RESET;
endmodule

