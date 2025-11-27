`timescale 1ns/1ps

module tb_mem;
    reg clk;
    reg cs;
    reg w_en;

    reg [7:0] addr;
    wire [31:0] data_bus;
    reg [31:0] tb_data;

    assign data_bus = (cs && w_en)?tb_data:32'bZ;

    mem dut (
        .clk(clk),
        .w_en(w_en),
        .sel(cs),
        .address_bus(addr),
        .data_bus(data_bus)
    );

    always #10 clk = !clk;

    initial begin 
        {clk, cs, w_en, addr} <= 0;

        repeat(2) @(posedge clk);

        for (integer i=0; i<2**8; i=i+1) begin 
            addr <= i; w_en <= 1; cs <= 1; tb_data <= $urandom;
            @(posedge clk);
            $display("Writing %0d to %0d", tb_data, addr);
        end

        for (integer i=0; i<2**8; i=i+1) begin 
            addr <= i; w_en <= 0; cs <= 1;
            @(posedge clk) ;
            $display("Reading %0d from %0d", data_bus, addr);
        end

        $finish;
    end

endmodule
