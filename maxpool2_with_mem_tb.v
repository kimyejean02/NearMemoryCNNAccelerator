`timescale 1ns/1ps

module tb_maxpool2_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    reg [7:0] input_data [0:15];

    reg [7:0] input_addr;
    reg [7:0] output_addr;

    wire [7:0] address_bus;
    wire [31:0] data_bus;

    wire mem_sel;
    wire mem_w_en;

    wire ready;

    mem memory (
        .clk(clk),
        .rst(rst),
        .sel(mem_sel),
        .w_en(mem_w_en),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    maxpool2_with_mem #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(8),
        .DATABUS_WIDTH(32),
        .HEIGHT(4),
        .WIDTH(4),
        .POOL_SIZE(2),
        .STRIDE(2)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .input_addr(input_addr),
        .output_addr(output_addr),
        .mem_w(mem_w_en),
        .mem_sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    initial clk = 0;
    always #10 clk = !clk;

    initial begin 
        rst <= 1;
        start <= 0;

        repeat(4) @(posedge clk);
        rst <= 0;
        @(posedge clk);

        input_data = '{
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        };

        input_addr <= 0;
        output_addr <= 20;

        memory.memory[0]  = 32'd1;
	memory.memory[1]  = 32'd2;
	memory.memory[2]  = 32'd3;
	memory.memory[3]  = 32'd4;

	memory.memory[4]  = 32'd5;
	memory.memory[5]  = 32'd6;
	memory.memory[6]  = 32'd7;
	memory.memory[7]  = 32'd8;

	memory.memory[8]  = 32'd9;
	memory.memory[9]  = 32'd10;
	memory.memory[10] = 32'd11;
	memory.memory[11] = 32'd12;

	memory.memory[12] = 32'd13;
	memory.memory[13] = 32'd14;
	memory.memory[14] = 32'd15;
	memory.memory[15] = 32'd16;

        $display("\n=== Starting Max Pooling Operation ===");
        $display("Time %0t: Asserting start signal", $time);
        start <= 1;
        @(posedge clk);
        start <= 0;

        $display("Time %0t: Waiting for done signal...", $time);
        wait(done);
        $display("Time %0t: Max pooling completed!", $time);

        repeat(3) @(posedge clk);

        $display("\n=== Reading Output Data from Memory ===");

        for (integer i = 0; i < 4; i++) begin
            $display("Time %0t: output[%0d] = %0d",
                     $time, i, memory.memory[output_addr + i][7:0]);
        end

        $display("\n=== Verification ===");
        $display("Expected output:");
        $display("[6  8 ]");
        $display("[14 16]");
        
        repeat(5) @(posedge clk);
        $display("\n=== Test Completed ===");
        $finish;
    end

    initial begin
        #10000;
        $display("\nERROR: Timeout! Test did not complete in time.");
        $finish;
    end

    initial begin
        $display("\n=== Max Pool 2x2 with Memory Testbench ===");
        $display("Configuration:");
        $display("  Input size: 4x4");
        $display("  Pool size: 2x2");
        $display("  Stride: 2");
        $display("  Output size: 2x2");
        $display("=====================================\n");
    end

endmodule

