`timescale 1ns/1ps

module tb_maxpool2_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    // Test data: 4x4 input matrix
    reg [7:0] input_data [0:15];

    reg [7:0] input_addr;
    reg [7:0] output_addr;

    reg driving_mem;

    reg [7:0] my_address;
    wire [7:0] address_bus;
    assign address_bus = (driving_mem) ? my_address : 8'bZ;

    reg my_mem_sel;
    wire pool_mem_sel;
    wire mem_sel;
    assign mem_sel = (driving_mem) ? my_mem_sel : pool_mem_sel;

    reg my_mem_w_en;
    wire mem_w_en;
    wire pool_mem_w_en;
    assign mem_w_en = (driving_mem) ? my_mem_w_en : pool_mem_w_en;

    reg [31:0] my_data;
    wire [31:0] data_bus;
    assign data_bus = (driving_mem && my_mem_w_en) ? my_data : 32'bZ;

    // Memory instance
    mem memory (
        .clk(clk),
        .w_en(mem_w_en),
        .sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    // DUT: maxpool2_with_mem
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
        .mem_w(pool_mem_w_en),
        .mem_sel(pool_mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    // Clock generation
    initial clk = 0;
    always #10 clk = !clk;
    
    initial begin 
        // Initialize signals
        rst <= 1;
        start <= 0;
        driving_mem <= 0;
        my_address <= 0;
        my_data <= 0;

        // Wait for reset
        repeat(4) @(posedge clk);
        rst <= 0;
        @(posedge clk);

        // Initialize test data
        // Input: 4x4 matrix
        // [1   2   3   4 ]
        // [5   6   7   8 ]
        // [9  10  11  12 ]
        // [13 14  15  16 ]
        //
        // Expected output with 2x2 maxpool, stride=2:
        // [6  8 ]
        // [14 16]
        input_data = '{
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        };

        // Set memory addresses
        input_addr <= 0;    // Input starts at address 0
        output_addr <= 20;  // Output starts at address 20

        // Write input data to memory
        $display("\n=== Writing Input Data to Memory ===");
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 1;

        @(posedge clk);

        for (integer i = 0; i < 16; i++) begin
            my_address <= input_addr + i;
            my_data <= input_data[i];
            @(posedge clk);
            $display("Time %0t: Writing data[%0d] = %0d to address %0d", 
                     $time, i, input_data[i], my_address);
        end

        // Release memory bus
        driving_mem <= 0;
        my_mem_sel <= 0;
        my_mem_w_en <= 0;
        @(posedge clk);

        // Start max pooling operation
        $display("\n=== Starting Max Pooling Operation ===");
        $display("Time %0t: Asserting start signal", $time);
        start <= 1;
        @(posedge clk);
        start <= 0;

        // Wait for completion
        $display("Time %0t: Waiting for done signal...", $time);
        wait(done);
        $display("Time %0t: Max pooling completed!", $time);
        
        // Wait a few cycles
        repeat(3) @(posedge clk);

        // Read output from memory
        $display("\n=== Reading Output Data from Memory ===");
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 0;

        @(posedge clk);

        // Expected: 4 output values (2x2 output)
        for (integer i = 0; i < 4; i++) begin
            my_address <= output_addr + i;
            @(posedge clk);
            $display("Time %0t: Reading output[%0d] = %0d from address %0d", 
                     $time, i, data_bus[7:0], my_address);
        end

        driving_mem <= 0;
        my_mem_sel <= 0;

        // Verify results
        $display("\n=== Verification ===");
        $display("Expected output:");
        $display("[6  8 ]");
        $display("[14 16]");
        
        repeat(5) @(posedge clk);
        $display("\n=== Test Completed ===");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("\nERROR: Timeout! Test did not complete in time.");
        $finish;
    end

    // Monitor for debugging
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
