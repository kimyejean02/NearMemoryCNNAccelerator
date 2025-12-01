`timescale 1ns/1ps

module tb_nmcu;

    // Parameters
    localparam ADDR_WIDTH = 16;
    localparam DATABUS_WIDTH = 32;
    localparam MAX_DESCS = 8;
    localparam MAX_INPUT_DIM = 15;
    localparam MAX_KERNEL_DIM = 7;

    // Clock & reset
    reg clk;
    reg rst;

    // NMCU signals
    reg start;
    wire done;
    reg [ADDR_WIDTH-1:0] nmcu_desc;
    reg [ADDR_WIDTH-1:0] input_addr;
    reg [ADDR_WIDTH-1:0] output_addr;
    reg [$clog2(MAX_INPUT_DIM):0] full_input_width;
    reg [$clog2(MAX_INPUT_DIM):0] full_input_height;
    reg [$clog2(MAX_INPUT_DIM):0] full_output_width;
    reg [$clog2(MAX_INPUT_DIM):0] full_output_height;
    wire mem_w;
    wire mem_sel;
    wire [ADDR_WIDTH-1:0] address_bus;
    wire [DATABUS_WIDTH-1:0] data_bus;
    wire ready;

    // Instantiate NMCU
    nmcu #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH),
        .MAX_DESCS(MAX_DESCS),
        .MAX_INPUT_DIM(MAX_INPUT_DIM),
        .MAX_KERNEL_DIM(MAX_KERNEL_DIM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .nmcu_desc(nmcu_desc),
        .input_addr(input_addr),
        .output_addr(output_addr),
        .full_input_width(full_input_width),
        .full_input_height(full_input_height),
        .full_output_width(full_output_width),
        .full_output_height(full_output_height),
        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    // Instantiate memory
    mem #(
        .DATA_WIDTH(DATABUS_WIDTH),
        .ADDRESS_WIDTH(ADDR_WIDTH),
        .LATENCY(2)
    ) memory (
        .clk(clk),
        .sel(mem_sel),
        .w_en(mem_w),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = !clk; // 100MHz

    // Test procedure
    initial begin
        integer i, j;
        integer val;

        // Initialize signals
        rst = 1;
        start = 0;
        nmcu_desc = 0;
        input_addr = 16'h0100;
        output_addr = 16'h0200;
        full_input_width = 4;
        full_input_height = 4;
        full_output_width = 2;
        full_output_height = 2;

        // Reset pulse
        #20;
        rst = 0;

        // Load descriptors into memory (for simplicity directly in memory array)
        memory.memory[0] = {16'h1234, 3'b000, 3'b011, 4'b0100, 4'b0100, 2'b01}; // CONV, input 4x4, kernel 3x3, kernel addr 0x1234
        // 9  -13
        // -25 29
        
        memory.memory[1] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b11}; // RELU, input 2x2
        // 9 0 
        // 0 29

        memory.memory[2] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b10}; // MAXP, input 2x2
        // 29

        memory.memory[3] = {16'h0000, 3'b000, 3'b000, 4'b0001, 4'b0001, 2'b00}; // NOP, input 1x1 (specify the output size that's not the full output size here)
        
        // Load kernel data (3x3 kernel, guaranteed mixed output)
        //
        // |     | j=0 | j=1 | j=2 |
        // | --- | --- | --- | --- |
        // | i=0 |  1  | -1  |  2  |
        // | i=1 | -2  |  3  | -1  |
        // | i=2 |  1  |  0  |  1  |
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                case ({i,j})
                    6'b000_00: val =  1;
                    6'b000_01: val = -1;
                    6'b000_10: val =  2;
                    6'b001_00: val = -2;
                    6'b001_01: val =  3;
                    6'b001_10: val = -1;
                    6'b010_00: val =  1;
                    6'b010_01: val =  0;
                    6'b010_10: val =  1;
                    default:   val = 0;
                endcase

                memory.memory[16'h1234 + i*3 + j] = val;

                $display("KERNEL write @ %h = %0d (i=%0d j=%0d)",
                        16'h1234 + i*3 + j,
                        val,
                        i,
                        j);
            end
        end

        // Load input data (4x4) with mixed positives and negatives
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                // alternate positive and negative values
                val = ((i + j) % 2 == 0) ? i*4 + j + 1 : -(i*4 + j + 1);

                memory.memory[16'h0100 + i*4 + j] = val;

                $display("INPUT  write @ %h = %0d (i=%0d j=%0d)",
                        16'h0100 + i*4 + j,
                        val,
                        i,
                        j);
            end
        end

        // Start NMCU
        #10;
        start = 1;
        #10;
        start = 0;

        // Wait until done
        wait(done);
        $display("NMCU operation finished");

        // Print output memory (assuming output at 0x0200)
        $display("Output memory:");
        for (int i=0; i<2; i=i+1) begin
            for (int j=0; j<2; j=j+1) begin
                $write("%0d ", $signed(memory.memory[16'h0200 + i*2 + j]));
            end
            $write("\n");
        end

        $finish;
    end

endmodule
