`timescale 1ns/1ps

module tb_relu;

    localparam DATA_WIDTH = 8;
    
    reg signed [DATA_WIDTH-1:0] in;
    reg [DATA_WIDTH-1:0] out;

    relu #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .in(in),
        .out(out)
    );

    task apply_input(
        input reg signed [DATA_WIDTH-1:0] a
    );
    begin
        in = a;

        #1;

        $display("in = { %0d } -> out = %0d",
            a, out
        );
    end
    endtask

    initial begin 
        $display("=== RELU TEST ===");

        repeat (20)
            apply_input($signed($urandom));

        $display("=== DONE ===");
        $finish;
    end
endmodule
