`timescale 1ns/1ps

module tb_maxpool2;

    localparam DATA_WIDTH = 8;

    // 2×2 inputs
    logic [DATA_WIDTH-1:0] in [0:1][0:1];

    wire [DATA_WIDTH-1:0] out;

    // DUT
    maxpool2 #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .in(in),
        .out(out)
    );

    task apply_input(
        input logic [DATA_WIDTH-1:0] a00,
        input logic [DATA_WIDTH-1:0] a01,
        input logic [DATA_WIDTH-1:0] a10,
        input logic [DATA_WIDTH-1:0] a11
    );
    begin
        in[0][0] = a00;
        in[0][1] = a01;
        in[1][0] = a10;
        in[1][1] = a11;

        #1;

        $display("in = { %0d %0d ; %0d %0d } -> out = %0d",
            a00, a01, a10, a11, out
        );
    end
    endtask

    initial begin
        $display("=== MAXPOOL2 TEST ===");

        apply_input(3, 7, 2, 1);      // expect 7
        apply_input(10, 9, 8, 1);     // expect 10
        apply_input(0, 0, 0, 0);      // expect 0
        apply_input(255, 23, 44, 12); // expect 255
        apply_input(8, 9, 10, 11);    // expect 11

        repeat (5)
            apply_input($urandom, $urandom, $urandom, $urandom);

        $display("=== DONE ===");
        $finish;
    end

endmodule
