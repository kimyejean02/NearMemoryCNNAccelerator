`timescale 1ns/1ps

module mac2_tb;

    parameter width = 8;

    reg [(4*width)-1:0] a;
    reg [(4*width)-1:0] kernel;
    wire [(width-1):0] out;

    mac2 #(
        .width(width)
    ) dut (
        .a(a),
        .kernel(kernel),
        .out(out)
    );

    initial begin
        a = {8'd4, 8'd3, 8'd2, 8'd1};
        kernel = {8'd8, 8'd7, 8'd6, 8'd5};
        #10;
    end

endmodule;