`timescale 1ns/1ps

module sync_near_mem_tb;

    // Parameters
    localparam ADDR_WIDTH = 16;
    localparam DATABUS_WIDTH = 32;
    localparam MAX_DESCS = 8;
    localparam MAX_INPUT_DIM = 16;
    localparam MAX_KERNEL_DIM = 7;

    localparam INPUT_DIM = 16;
    localparam KERNEL_DIM = 3;
    localparam OUTPUT_DIM = (INPUT_DIM - KERNEL_DIM + 1);
    localparam NUM_NMCUS = OUTPUT_DIM**2;

    // Clock & reset
    reg clk;
    reg rst;

    // NMCU signals
    reg start;
    wire done;
    reg [ADDR_WIDTH-1:0] nmcu_desc;
    reg [ADDR_WIDTH-1:0] input_addresses [OUTPUT_DIM][OUTPUT_DIM];
    reg [ADDR_WIDTH-1:0] output_addresses [OUTPUT_DIM][OUTPUT_DIM];
    reg [$clog2(MAX_INPUT_DIM):0] full_input_width;
    reg [$clog2(MAX_INPUT_DIM):0] full_input_height;
    reg [$clog2(MAX_INPUT_DIM):0] full_output_width;
    reg [$clog2(MAX_INPUT_DIM):0] full_output_height;

    wire [ADDR_WIDTH-1:0] address_bus;
    wire [DATABUS_WIDTH-1:0] data_bus;
    wire mem_w;
    wire mem_sel;
    wire ready;

    wire [NUM_NMCUS-1:0] nmcu_start;
    wire [3:0] nmcu_state [NUM_NMCUS-1:0];
    wire [ADDR_WIDTH-1:0] nmcu_addr_bus [NUM_NMCUS-1:0];
    wire [DATABUS_WIDTH-1:0] nmcu_data_bus [NUM_NMCUS-1:0];
    wire [NUM_NMCUS-1:0] nmcu_mem_w;
    wire [NUM_NMCUS-1:0] nmcu_mem_sel;
    wire [NUM_NMCUS-1:0] nmcu_mem_ready;

    // Instantiate NMCUs
    genvar i, j;
    generate
        for (i = 0; i < OUTPUT_DIM; i = i+1) begin
            for (j = 0; j < OUTPUT_DIM; j = j+1) begin
                sync_nmcu #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATABUS_WIDTH(DATABUS_WIDTH),
                    .MAX_DESCS(MAX_DESCS),
                    .MAX_INPUT_DIM(MAX_INPUT_DIM),
                    .MAX_KERNEL_DIM(MAX_KERNEL_DIM)
                ) dut (
                    .clk(clk),
                    .rst(rst),
                    .start(nmcu_start[i*OUTPUT_DIM+j]),
                    // .done(done[i*OUTPUT_DIM+j]),
                    .nmcu_desc(nmcu_desc),
                    .input_addr(input_addresses[i][j]),
                    .output_addr(output_addresses[i][j]),
                    .full_input_width(full_input_width),
                    .full_input_height(full_input_height),
                    .full_output_width(full_output_width),
                    .full_output_height(full_output_height),
                    .mem_w(nmcu_mem_w[i*OUTPUT_DIM+j]),
                    .mem_sel(nmcu_mem_sel[i*OUTPUT_DIM+j]),
                    .address_bus(nmcu_addr_bus[i*OUTPUT_DIM+j]),
                    .data_bus(nmcu_data_bus[i*OUTPUT_DIM+j]),
                    .ready(nmcu_mem_ready[i*OUTPUT_DIM+j]),
                    .state_out(nmcu_state[i*OUTPUT_DIM+j])
                );
            end
        end
    endgenerate

    // Instantiate memory
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
        .ready(ready)
    );

    // Instantiate memory interface
    nmcu_ctrl #(
        .NUM_NMCUS(NUM_NMCUS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH)
    ) nmcu_ctrl_i (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .nmcu_desc(nmcu_desc),
        .input_addr(input_addresses[0][0]),
        .output_addr(output_addresses[0][0]),
        .full_input_width(full_input_width),
        .full_input_height(full_input_height),
        .full_output_width(full_output_width),
        .full_output_height(full_output_height),
        .nmcu_start(nmcu_start),
        .nmcu_state(nmcu_state),
        .nmcu_mem_sel(nmcu_mem_sel),
        .nmcu_mem_w(nmcu_mem_w),
        .nmcu_mem_ready(nmcu_mem_ready),
        .nmcu_addr_bus(nmcu_addr_bus),
        .nmcu_data_bus(nmcu_data_bus),
        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .ready(ready),
        .address_bus(address_bus),
        .data_bus(data_bus)
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

        // Input addresses
        // input_addresses[0][0] = 16'h0100;
        // input_addresses[0][1] = 16'h0101;
        // input_addresses[0][2] = 16'h0102;

        // input_addresses[1][0] = 16'h0106;
        // input_addresses[1][1] = 16'h0107;
        // input_addresses[1][2] = 16'h0108;

        // input_addresses[2][0] = 16'h010C;
        // input_addresses[2][1] = 16'h010D;
        // input_addresses[2][2] = 16'h010E;

        // Output addresses
        // output_addresses[0][0] = 16'h0200;
        // output_addresses[0][1] = 16'h0201;
        // output_addresses[0][2] = 16'h0202;

        // output_addresses[1][0] = 16'h0203;
        // output_addresses[1][1] = 16'h0204;
        // output_addresses[1][2] = 16'h0205;

        // output_addresses[2][0] = 16'h0206;
        // output_addresses[2][1] = 16'h0207;
        // output_addresses[2][2] = 16'h0208;

        for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
            for (j = 0; j < OUTPUT_DIM; j = j + 1) begin
                input_addresses[i][j] = 16'h0100 + i*INPUT_DIM + j;
                output_addresses[i][j] = 16'h0200 + i*OUTPUT_DIM + j;
            end
        end

        full_input_width = INPUT_DIM;
        full_input_height = INPUT_DIM;
        full_output_width = OUTPUT_DIM;
        full_output_height = OUTPUT_DIM;

        // Reset pulse
        #20;
        rst = 0;

        // Load descriptors into memory (for simplicity directly in memory array)
        memory.memory[0] = {16'h1234, 3'b000, 3'b011, 4'b0011, 4'b0011, 2'b01}; // CONV, input 3x3, kernel 3x3, kernel addr 0x1234

        // memory.memory[1] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b11}; // RELU, input 2x2

        // memory.memory[2] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b10}; // MAXP, input 2x2

        memory.memory[1] = {16'h0000, 3'b000, 3'b000, 4'b0001, 4'b0001, 2'b00}; // NOP, input 1x1 (specify the output size that's not the full output size here)

        // Kernel
        memory.memory[16'h1234 + 0] =  1;  $display("KERNEL write @ %h = %0d (i=0 j=0)", 16'h1234 + 0*4 + 0,  1);
        memory.memory[16'h1234 + 1] = -1;  $display("KERNEL write @ %h = %0d (i=0 j=1)", 16'h1234 + 0*4 + 1, -1);
        memory.memory[16'h1234 + 2] =  2;  $display("KERNEL write @ %h = %0d (i=0 j=2)", 16'h1234 + 0*4 + 2,  2);
        // memory.memory[16'h1234 + 0*4 + 3] =  0;  $display("KERNEL write @ %h = %0d (i=0 j=3)", 16'h1234 + 0*4 + 3,  0);

        memory.memory[16'h1234 + 3] = -2;  $display("KERNEL write @ %h = %0d (i=1 j=0)", 16'h1234 + 1*4 + 0, -2);
        memory.memory[16'h1234 + 4] =  3;  $display("KERNEL write @ %h = %0d (i=1 j=1)", 16'h1234 + 1*4 + 1,  3);
        memory.memory[16'h1234 + 5] = -1;  $display("KERNEL write @ %h = %0d (i=1 j=2)", 16'h1234 + 1*4 + 2, -1);
        // memory.memory[16'h1234 + 1*4 + 3] =  4;  $display("KERNEL write @ %h = %0d (i=1 j=3)", 16'h1234 + 1*4 + 3,  4);

        memory.memory[16'h1234 + 6] =  1;  $display("KERNEL write @ %h = %0d (i=2 j=0)", 16'h1234 + 2*4 + 0,  1);
        memory.memory[16'h1234 + 7] =  0;  $display("KERNEL write @ %h = %0d (i=2 j=1)", 16'h1234 + 2*4 + 1,  0);
        memory.memory[16'h1234 + 8] =  1;  $display("KERNEL write @ %h = %0d (i=2 j=2)", 16'h1234 + 2*4 + 2,  1);
        // memory.memory[16'h1234 + 2*4 + 3] = -3;  $display("KERNEL write @ %h = %0d (i=2 j=3)", 16'h1234 + 2*4 + 3, -3);

        // memory.memory[16'h1234 + 3*4 + 0] =  2;  $display("KERNEL write @ %h = %0d (i=3 j=0)", 16'h1234 + 3*4 + 0,  2);
        // memory.memory[16'h1234 + 3*4 + 1] =  2;  $display("KERNEL write @ %h = %0d (i=3 j=1)", 16'h1234 + 3*4 + 1,  2);
        // memory.memory[16'h1234 + 3*4 + 2] = -2;  $display("KERNEL write @ %h = %0d (i=3 j=2)", 16'h1234 + 3*4 + 2, -2);
        // memory.memory[16'h1234 + 3*4 + 3] =  5;  $display("KERNEL write @ %h = %0d (i=3 j=3)", 16'h1234 + 3*4 + 3,  5);

        // Load input data with mixed positives and negatives
        for (i = 0; i < INPUT_DIM; i = i + 1) begin
            for (j = 0; j < INPUT_DIM; j = j + 1) begin
                // alternate positive and negative values
                val = ((i + j) % 2 == 0) ? (i*INPUT_DIM + j + 1) : -(i*INPUT_DIM + j + 1);

                memory.memory[16'h0100 + i*INPUT_DIM + j] = val;

                $display("INPUT  write @ %h = %0d (i=%0d j=%0d)",
                        16'h0100 + i*INPUT_DIM + j,
                        val,
                        i,
                        j);
            end
        end

        // All 1s
        start = '1;

        // Wait until done
        wait(&done);
        $display("NMCU operation finished");

        // Print output memory (assuming output at 0x0200)
        $display("Output memory:");
        for (int i = 0; i < OUTPUT_DIM; i = i + 1) begin
            for (int j = 0; j < OUTPUT_DIM; j = j + 1) begin
                $write("%0d ",
                    $signed(memory.memory[16'h0200 + i*OUTPUT_DIM + j]));
            end
            $write("\n");
        end

        $finish;
    end

endmodule
