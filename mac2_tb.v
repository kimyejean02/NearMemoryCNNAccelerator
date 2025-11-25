`timescale 1ns/1ps

module mac2_tb;

    reg [31:0] a;
    reg [31:0] kernel;
    wire [31:0] out;

    mac2 dut (
        .a(a),
        .kernel(kernel),
        .out(out)
    );

    initial begin
        a = {8'd4, 8'd3, 8'd2, 8'd1};
        kernel = {8'd8, 8'd7, 8'd6, 8'd5};
        #10;

	$finish;
    end

endmodule;
