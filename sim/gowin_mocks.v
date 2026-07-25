// 
// Gowin Verilator Mocks
//
// These are simplified, perfectly digital behavioral models of Gowin FPGA
// primitives. They contain no analog simulation hacks, `#` delays, or 
// non-synthesizable constructs, making them 100% compatible with Verilator.
//

// Differential Output Buffer
module ELVDS_OBUF (
    input  wire I,
    output wire O,
    output wire OB
);
    assign O  = I;
    assign OB = ~I;
endmodule

// Clock Divider
module Gowin_CLKDIV (
    input  wire hclkin,
    input  wire resetn,
    output reg  clkout
);
    // In a real simulation testbench you might want to mock the actual divide ratio
    // (e.g. divide by 5). This simple toggle acts as a standard divide-by-2 placeholder.
    always @(posedge hclkin or negedge resetn) begin
        if (!resetn)
            clkout <= 1'b0;
        else
            clkout <= ~clkout;
    end
endmodule

// rPLL
module rPLL (
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
    // Just pass the clock straight through for digital simulation.
    // In a real testbench, you'd drive CLKOUT with a separate thread/generator 
    // to model the exact multiplied frequency.
    assign CLKOUT = CLKIN;
    assign CLKOUTP = CLKIN;
    assign CLKOUTD = CLKIN;
    assign CLKOUTD3 = CLKIN;
    
    // Simulate instantaneous lock
    assign LOCK = ~RESET;

endmodule
