`timescale 1ns/1ps

module tb_mac2_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    reg [31:0] a_data;
    reg [31:0] kernel_data;

    reg [7:0] a_addr;
    reg [7:0] kernel_addr;
    reg [7:0] output_addr;

    reg driving_mem;

    reg [7:0] my_address;
    wire [7:0] address_bus;
    assign address_bus = (driving_mem) ? my_address : 8'bZ;

    reg my_mem_sel;
    wire mac_mem_sel;
    wire mem_sel;
    assign mem_sel = (driving_mem) ? my_mem_sel : mac_mem_sel;

    reg my_mem_w_en;
    wire mem_w_en;
    wire mac_mem_w_en;
    assign mem_w_en = (driving_mem) ? my_mem_w_en : mac_mem_w_en;

    reg [31:0] my_data;
    wire [31:0] data_bus;
    assign data_bus = (driving_mem && my_mem_w_en) ? my_data : 32'bZ;

    mem memory (
        .clk(clk),
        .w_en(mem_w_en),
        .sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    mac2_with_mem dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .a_addr(a_addr),
        .kernel_addr(kernel_addr),
        .output_addr(output_addr),
        .mem_w(mac_mem_w_en),
        .mem_sel(mac_mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    initial clk = 0;
    always #10 clk = !clk;
    
    initial begin 
        rst <= 1;
        start <= 0;

        driving_mem <= 0;
        my_address <= 0;
        my_data <= 0;

        repeat(4) @(posedge clk);
        rst <= 0;
        @(posedge clk);

        // Test data for MAC2:
        // a_data = [0x04, 0x03, 0x02, 0x01] = {4, 3, 2, 1}
        // kernel_data = [0x08, 0x07, 0x06, 0x05] = {8, 7, 6, 5}
        // result = (1*5) + (2*6) + (3*7) + (4*8)
        //        = 5 + 12 + 21 + 32
        //        = 70
        a_data = 32'h04030201;
        kernel_data = 32'h08070605;

        // Set memory addresses
        a_addr <= 0;
        kernel_addr <= 1;
        output_addr <= 2;

        // Write input data to memory
        $display("\n=== Writing Input Data to Memory ===");
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 1;

        @(posedge clk);

        // Write 'a' operand
        my_address <= a_addr;
        my_data <= a_data;
        @(posedge clk);
        $display("Writing a_data = %0h to address %0d", a_data, a_addr);

        // Write 'kernel' operand
        my_address <= kernel_addr;
        my_data <= kernel_data;
        @(posedge clk);
        $display("Writing kernel_data = %0h to address %0d", kernel_data, kernel_addr);

        // Release memory bus
        driving_mem <= 0;
        my_mem_sel <= 0;
        my_mem_w_en <= 0;
        @(posedge clk);

        // Start MAC operation
        $display("\n=== Starting MAC2 Operation ===");
        $display("Time %0t: Asserting start signal", $time);
        start <= 1;
        @(posedge clk);
        start <= 0;

        // Wait for completion
        $display("Time %0t: Waiting for done signal...", $time);
        wait(done);
        $display("Time %0t: MAC2 computation completed!", $time);
        
        // Wait a few cycles
        repeat(3) @(posedge clk);

        // Read output from memory
        $display("\n=== Reading Output Data from Memory ===");
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 0;

        @(posedge clk);

        // Read result
        my_address <= output_addr;
        @(posedge clk);
        $display("Time %0t: Reading output = %0d (0x%0h) from address %0d", 
                 $time, data_bus, data_bus, output_addr);

        driving_mem <= 0;
        my_mem_sel <= 0;

        // Verify result
        $display("\n=== Verification ===");
        $display("a_data = %0h = [0x%02h, 0x%02h, 0x%02h, 0x%02h]", 
                 a_data, a_data[31:24], a_data[23:16], a_data[15:8], a_data[7:0]);
        $display("kernel_data = %0h = [0x%02h, 0x%02h, 0x%02h, 0x%02h]", 
                 kernel_data, kernel_data[31:24], kernel_data[23:16], kernel_data[15:8], kernel_data[7:0]);
        $display("MAC2 result = (1*5) + (2*6) + (3*7) + (4*8) = 5 + 12 + 21 + 32 = 70");
        $display("Expected output: 70 (0x46)");
        
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
        $display("\n=== MAC2 with Memory Testbench ===");
        $display("Configuration:");
        $display("  Operand A width: 32 bits");
        $display("  Kernel width: 32 bits");
        $display("  Operation: 4 x 8-bit MACs");
        $display("  Output width: 32 bits");
        $display("=====================================\n");
    end

endmodule
