module nmcu4_tb;

    reg [127:0] A;
    reg [31:0] kernel;
    wire [287:0] out;

    nmcu4 dut (A, kernel, out);

    initial begin
        A = {16{8'b1}};
        kernel = {4{8'b1}};

        #10
        $finish;
    end
endmodule