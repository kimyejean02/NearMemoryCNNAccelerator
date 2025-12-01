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
    ) uut (
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
        memory.memory[1] = 32'h00000000; // NOP
        // Load kernel data
        for (int i=0; i<3; i=i+1) begin
            for (int j=0; j<3; j=j+1) begin
                memory.memory[16'h1234 + i*3 + j] = i*3 + j + 1; // kernel values 1..9
            end
        end
        // Load input data
        for (int i=0; i<4; i=i+1) begin
            for (int j=0; j<4; j=j+1) begin
                memory.memory[16'h0100 + i*4 + j] = i*4 + j + 1; // input values 1..16
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
                $write("%0d ", memory.memory[16'h0200 + i*2 + j]);
            end
            $write("\n");
        end

        $stop;
    end

endmodule
