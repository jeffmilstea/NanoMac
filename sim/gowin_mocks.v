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

module CLKDIV #(
    parameter DIV_MODE = "2",
    parameter GSREN = "false"
) (
    input  wire HCLKIN,
    input  wire RESETN,
    input  wire CALIB,
    output reg  CLKOUT
);
    reg [2:0] div_cnt;
    always @(posedge HCLKIN or negedge RESETN) begin
        if (!RESETN) begin
            div_cnt <= 3'd0;
            CLKOUT  <= 1'b0;
        end else if (DIV_MODE == "2") begin
            CLKOUT <= ~CLKOUT;
        end else if (DIV_MODE == "5") begin
            if (div_cnt == 3'd4) begin
                div_cnt <= 3'd0;
                CLKOUT  <= 1'b0;
            end else begin
                div_cnt <= div_cnt + 3'd1;
                if (div_cnt == 3'd1)
                    CLKOUT <= 1'b1;
            end
        end else begin
            CLKOUT <= ~CLKOUT;
        end
    end
endmodule

module Gowin_CLKDIV (
    input  wire hclkin,
    input  wire resetn,
    output wire clkout
);
    CLKDIV #(.DIV_MODE("5")) inst (
        .HCLKIN(hclkin),
        .RESETN(resetn),
        .CALIB(1'b0),
        .CLKOUT(clkout)
    );
endmodule

module DCS #(
    parameter DCS_MODE = "RISING"
) (
    input  wire CLK0,
    input  wire CLK1,
    input  wire CLK2,
    input  wire CLK3,
    input  wire [3:0] CLKSEL,
    input  wire SELFORCE,
    output wire CLKOUT
);
    assign CLKOUT = (CLKSEL[1]) ? CLK1 : CLK0;
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

