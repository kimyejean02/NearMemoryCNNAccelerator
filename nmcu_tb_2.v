`timescale 1ns/1ps

// Convolution on a 6x6 input with kernel size of 4x4 for a total of 9 nmcus

module tb_nmcu_2;

    // Parameters
    localparam ADDR_WIDTH = 16;
    localparam DATABUS_WIDTH = 32;
    localparam MAX_DESCS = 8;
    localparam MAX_INPUT_DIM = 15;
    localparam MAX_KERNEL_DIM = 7;

    localparam INPUT_DIM = 6;
    localparam KERNEL_DIM = 4;
    localparam OUTPUT_DIM = (INPUT_DIM - KERNEL_DIM + 1);
    localparam NUM_NMCUS = OUTPUT_DIM**2;

    // Clock & reset
    reg clk;
    reg rst;

    // NMCU signals
    reg [NUM_NMCUS-1:0] start;
    wire [NUM_NMCUS-1:0] done;
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

    wire [ADDR_WIDTH-1:0] addr_bus_ind [NUM_NMCUS-1:0];
    wire [DATABUS_WIDTH-1:0] data_bus_ind [NUM_NMCUS-1:0];
    wire [NUM_NMCUS-1:0] mem_w_ind;
    wire [NUM_NMCUS-1:0] mem_sel_ind;
    wire [NUM_NMCUS-1:0] mem_ready_ind;

    // Instantiate NMCUs
    genvar i, j;
    generate
        for (i = 0; i < OUTPUT_DIM; i = i+1) begin
            for (j = 0; j < OUTPUT_DIM; j = j+1) begin
                nmcu #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATABUS_WIDTH(DATABUS_WIDTH),
                    .MAX_DESCS(MAX_DESCS),
                    .MAX_INPUT_DIM(MAX_INPUT_DIM),
                    .MAX_KERNEL_DIM(MAX_KERNEL_DIM)
                ) dut (
                    .clk(clk),
                    .rst(rst),
                    .start(start[i*OUTPUT_DIM+j]),
                    .done(done[i*OUTPUT_DIM+j]),
                    .nmcu_desc(nmcu_desc),
                    .input_addr(input_addresses[i][j]),
                    .output_addr(output_addresses[i][j]),
                    .full_input_width(full_input_width),
                    .full_input_height(full_input_height),
                    .full_output_width(full_output_width),
                    .full_output_height(full_output_height),
                    .mem_w(mem_w_ind[i*OUTPUT_DIM+j]),
                    .mem_sel(mem_sel_ind[i*OUTPUT_DIM+j]),
                    .address_bus(address_bus_ind[i*OUTPUT_DIM+j]),
                    .data_bus(data_bus_ind[i*OUTPUT_DIM+j]),
                    .ready(mem_ready_ind[i*OUTPUT_DIM+j])
                );
            end
        end
    endgenerate

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

    // Instantiate memory interface
    mem_interface #(
        .NUM_PORTS(NUM_NMCUS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH)
    ) mem_cu (
        .clk(clk),
        .rst(rst),
        .mem_w_ind(mem_w_ind),
        .mem_sel_ind(mem_sel_ind),
        .mem_ready_ind(mem_ready_ind),
        .addr_bus_ind(addr_bus_ind),
        .data_bus_ind(data_bus_ind),
        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .mem_ready(ready),
        .addr_bus(addr_bus),
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
        input_addresses[0][0] = 16'h0100;
        input_addresses[0][1] = 16'h0101;
        input_addresses[0][2] = 16'h0102;

        input_addresses[1][0] = 16'h0106;
        input_addresses[1][1] = 16'h0107;
        input_addresses[1][2] = 16'h0108;

        input_addresses[2][0] = 16'h010C;
        input_addresses[2][1] = 16'h010D;
        input_addresses[2][2] = 16'h010E;

        // Output addresses
        output_addresses[0][0] = 16'h0200;
        output_addresses[0][1] = 16'h0201;
        output_addresses[0][2] = 16'h0202;

        output_addresses[1][0] = 16'h0203;
        output_addresses[1][1] = 16'h0204;
        output_addresses[1][2] = 16'h0205;

        output_addresses[2][0] = 16'h0206;
        output_addresses[2][1] = 16'h0207;
        output_addresses[2][2] = 16'h0208;

        full_input_width = INPUT_DIM;
        full_input_height = INPUT_DIM;
        full_output_width = OUTPUT_DIM;
        full_output_height = OUTPUT_DIM;

        // Reset pulse
        #20;
        rst = 0;

        // Load descriptors into memory (for simplicity directly in memory array)
        memory.memory[0] = {16'h1234, 3'b000, 3'b100, 4'b0100, 4'b0100, 2'b01}; // CONV, input 4x4, kernel 4x4, kernel addr 0x1234

        // memory.memory[1] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b11}; // RELU, input 2x2

        // memory.memory[2] = {16'h0000, 3'b000, 3'b000, 4'b0010, 4'b0010, 2'b10}; // MAXP, input 2x2

        memory.memory[1] = {16'h0000, 3'b000, 3'b000, 4'b0001, 4'b0001, 2'b00}; // NOP, input 1x1 (specify the output size that's not the full output size here)

        for (i = 0; i < KERNEL_DIM; i = i + 1) begin
            for (j = 0; j < KERNEL_DIM; j = j + 1) begin
                case ({i,j})
                    8'b0000_0000: val =  1;
                    8'b0000_0001: val = -1;
                    8'b0000_0010: val =  2;
                    8'b0000_0011: val =  0;

                    8'b0001_0000: val = -2;
                    8'b0001_0001: val =  3;
                    8'b0001_0010: val = -1;
                    8'b0001_0011: val =  4;

                    8'b0010_0000: val =  1;
                    8'b0010_0001: val =  0;
                    8'b0010_0010: val =  1;
                    8'b0010_0011: val = -3;

                    8'b0011_0000: val =  2;
                    8'b0011_0001: val =  2;
                    8'b0011_0010: val = -2;
                    8'b0011_0011: val =  5;

                    default:       val = 0;
                endcase

                memory.memory[16'h1234 + i*KERNEL_DIM + j] = val;

                $display("KERNEL write @ %h = %0d (i=%0d j=%0d)",
                        16'h1234 + i*KERNEL_DIM + j,
                        val,
                        i,
                        j);
            end
        end

        // Load input data (6x6) with mixed positives and negatives
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
        start = 9'b111111111;

        // Wait until done
        wait(done[0] && done[1] && done[2] && done[3] && done[4] && done[5] && done[6] && done[7] && done[8]);
        $display("NMCU operation finished");

        // Print output memory (assuming output at 0x0200)
        $display("Output memory:");
        for (int i=0; i<3; i=i+1) begin
            for (int j=0; j<3; j=j+1) begin
                $write("%0d ", $signed(memory.memory[16'h0200 + i*3 + j]));
            end
            $write("\n");
        end

        $finish;
    end

endmodule
