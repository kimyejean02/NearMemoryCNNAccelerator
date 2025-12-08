`timescale 1ns/1ps

module convolution_with_mem_tb;

    localparam MAT_WIDTH  = 8;
    localparam K_WIDTH    = 8;
    localparam ACC_WIDTH  = 32;
    localparam ADDR_WIDTH = 8;
    localparam DATABUS_WIDTH = 32;

    localparam HEIGHT = 4;
    localparam WIDTH  = 4;
    localparam K      = 2;

    reg clk;
    reg rst;
    reg start;

    wire done;

    reg [7:0] matrix_addr  = 0;
    reg [7:0] kernel_addr  = 16;
    reg [7:0] output_addr  = 32;

    wire mem_sel;
    wire mem_w;
    wire mem_ready;
    wire [ADDR_WIDTH-1:0] address_bus;
    wire [DATABUS_WIDTH-1:0] data_bus;

    mem #(
        .DATA_WIDTH(DATABUS_WIDTH),
        .ADDRESS_WIDTH(ADDR_WIDTH),
        .LATENCY(1)
    ) memory (
        .clk(clk),
        .rst(rst),
        .sel(mem_sel),
        .w_en(mem_w),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(mem_ready)
    );

    convolution_with_mem #(
        .MAT_WIDTH(MAT_WIDTH),
        .K_WIDTH(K_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH),
        .K(K)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .matrix_addr(matrix_addr),
        .kernel_addr(kernel_addr),
        .output_addr(output_addr),
        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(mem_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;


    integer i;

    initial begin
        rst = 1;
        start = 0;

        repeat(2) @(posedge clk);
        rst = 0;

        @(posedge clk);

        // Matrix
        memory.memory[matrix_addr + 0] = 1;
        memory.memory[matrix_addr + 1] = 2;
        memory.memory[matrix_addr + 2] = 3;
        memory.memory[matrix_addr + 3] = 4;

        memory.memory[matrix_addr + 4] = 5;
        memory.memory[matrix_addr + 5] = 6;
        memory.memory[matrix_addr + 6] = 7;
        memory.memory[matrix_addr + 7] = 8;

        memory.memory[matrix_addr + 8] = 9;
        memory.memory[matrix_addr + 9] = 10;
        memory.memory[matrix_addr +10] = 11;
        memory.memory[matrix_addr +11] = 12;

        memory.memory[matrix_addr +12] = 13;
        memory.memory[matrix_addr +13] = 14;
        memory.memory[matrix_addr +14] = 15;
        memory.memory[matrix_addr +15] = 16;

        // Kernel (2×2)
        memory.memory[kernel_addr + 0] = 1;
        memory.memory[kernel_addr + 1] = 0;
        memory.memory[kernel_addr + 2] = 0;
        memory.memory[kernel_addr + 3] = -1;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for it to finish
        wait(done);

        $display("=== OUTPUT FEATURE MAP ===");
        for (i = 0; i < 9; i++) begin
            $display("out[%0d] = %0d", i, memory.memory[output_addr + i]);
        end

        $display("=== TEST FINISHED ===");
        $finish;
    end

endmodule

