`timescale 1ns/1ps

module tb_convolution_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    reg signed [7:0] matrix [0:15];
    reg signed [7:0] kernel [0:3];

    reg [7:0] matrix_addr;
    reg [7:0] kernel_addr;
    reg [7:0] output_addr;

    reg driving_mem;

    reg [7:0] my_address;
    wire [7:0] address_bus;
    assign address_bus = (driving_mem)?my_address:8'bZ;

    reg [31:0] my_data;
    wire [31:0] data_bus;
    assign data_bus = (driving_mem)?my_data:32'bZ;

    reg my_mem_sel;
    wire conv_mem_sel;
    wire mem_sel;
    assign mem_sel = (driving_mem)?my_mem_sel:conv_mem_sel;

    reg my_mem_w_en;
    wire mem_w_en;
    wire conv_mem_w_en;
    assign mem_w_en = (driving_mem)?my_mem_w_en:conv_mem_w_en;

    mem memory (
        .clk(clk),
        .w_en(mem_w_en),
        .sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    convolution_with_mem dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .matrix_addr(matrix_addr),
        .kernel_addr(kernel_addr),
        .output_addr(output_addr),
        .mem_w(conv_mem_w_en),
        .mem_sel(conv_mem_sel),
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

        matrix = '{
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        };

        kernel = '{
            1, 0,
            0, -1
        };

        // Write to memory while convolution is idle
        matrix_addr <= 0;
        kernel_addr <= 16;
        output_addr <= 20;
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 1;

        @(posedge clk);

        for (integer i=0; i<16; i++) begin
            my_address <= matrix_addr + i;
            my_data <= matrix[i];
            @(posedge clk);
            $display("Writing %0d to %0d", my_data, address_bus);
        end

        for (integer i=0; i<4; i++) begin
            my_address <= kernel_addr + i;
            my_data <= kernel[i];
            @(posedge clk);
            $display("Writing %0d to %0d", my_data, address_bus);
        end

        driving_mem <= 0;
        my_mem_sel <= 0;
        my_mem_w_en <= 0;
        @(posedge clk);

        // Start convolution
        start <= 1;
        @(posedge clk);
        start <= 0;

        // Monitor results
        wait(done);

        // Read out from memory
        driving_mem <= 1;
        my_mem_sel <= 1;
        my_mem_w_en <= 0;
        @(posedge clk);

        for (integer i=0; i<9; i++) begin
            my_address <= output_addr + i;
            @(posedge clk);
            $display("Reading %0d from %0d", data_bus, address_bus);
        end

        $finish;
    end

endmodule
