`timescale 1ns/1ps

module tb_relu_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    // parameters to match DUT
    localparam DATA_WIDTH = 8;
    localparam DATABUS_WIDTH = 32;
    localparam ADDR_WIDTH = 8;
    localparam HEIGHT = 2;
    localparam WIDTH = 3;
    localparam N = HEIGHT * WIDTH;

    // addresses
    reg [ADDR_WIDTH-1:0] input_addr;
    reg [ADDR_WIDTH-1:0] output_addr;

    // external memory-driver signals (TB drives memory when driving_mem=1)
    reg driving_mem;

    reg [ADDR_WIDTH-1:0] my_address;
    wire [ADDR_WIDTH-1:0] address_bus;
    assign address_bus = (driving_mem) ? my_address : {ADDR_WIDTH{1'bZ}};

    reg my_mem_sel;
    wire dut_mem_sel;
    wire mem_sel;
    // when TB is driving, use my_mem_sel; otherwise expose DUT's mem_sel to mem
    assign mem_sel = (driving_mem) ? my_mem_sel : dut_mem_sel;

    reg my_mem_w_en;
    wire dut_mem_w_en;
    wire mem_w_en;
    assign mem_w_en = (driving_mem) ? my_mem_w_en : dut_mem_w_en;

    reg [DATABUS_WIDTH-1:0] my_data;
    wire [DATABUS_WIDTH-1:0] data_bus;
    assign data_bus = (driving_mem && my_mem_w_en) ? my_data : {DATABUS_WIDTH{1'bZ}};

    // temporary array of input values (signed DATA_WIDTH each)
    reg signed [DATA_WIDTH-1:0] vals [0:N-1];

    // loop variables and timeout counter
    integer i;
    integer timeout;

    // instantiate memory module used by other testbenches
    mem #(.DATA_WIDTH(DATABUS_WIDTH), .ADDRESS_WIDTH(ADDR_WIDTH)) memory (
        .clk(clk),
        .w_en(mem_w_en),
        .sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    // instantiate DUT
    wire dut_mem_w;
    relu_with_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH),
        .HEIGHT(HEIGHT),
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .input_addr(input_addr),
        .output_addr(output_addr),
        .mem_w(dut_mem_w_en),
        .mem_sel(dut_mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // initialize control
        rst = 1;
        start = 0;
        driving_mem = 0;
        my_address = 0;
        my_data = 0;
        my_mem_sel = 0;
        my_mem_w_en = 0;

        // release reset
        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // prepare a small matrix with signed values in low DATA_WIDTH bits
        // values: -3, -1, 0, 5, 127, -128 (for variety)
        vals[0] = -3;
        vals[1] = -1;
        vals[2] = 0;
        vals[3] = 5;
        vals[4] = 127;
        vals[5] = -128;

        input_addr = 8'd0;
        output_addr = 8'd100;

        // write inputs into memory by driving the bus from TB
        driving_mem = 1;
        my_mem_sel = 1;    // read-mode when mem module sees sel=1 and w_en=0, it outputs data
        my_mem_w_en = 1;   // but we want to write here, so assert w_en while driving

        @(posedge clk);
        for (i = 0; i < N; i = i + 1) begin
            my_address <= input_addr + i;
            // store signed value in low DATA_WIDTH bits
            my_data <= {{(DATABUS_WIDTH-DATA_WIDTH){vals[i][DATA_WIDTH-1]}}, vals[i]};
            @(posedge clk);
            $display("TB wrote mem[%0d] = %0d", my_address, $signed(vals[i]));
        end

        // stop TB driving memory so DUT can drive address during read phases
        driving_mem = 0;
        my_mem_sel = 0;
        my_mem_w_en = 0;

        // start DUT
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // wait for DUT to signal done (timeout in cycles)
        timeout = 0;
        while (!done && timeout < 1000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (timeout >= 1000) begin
            $display("TIMEOUT waiting for DUT done");
            $finish;
        end

        // read back outputs by driving memory read signals from TB
        driving_mem = 1;
        my_mem_sel = 1;
        my_mem_w_en = 0; // read
        @(posedge clk);
        for (i = 0; i < N; i = i + 1) begin
            my_address <= output_addr + i;
            @(posedge clk);
            // reconstruct signed DATA_WIDTH value from low bits of data_bus
            $display("mem[%0d] = %0d", my_address, $signed(data_bus[DATA_WIDTH-1:0]));
        end

        $display("TEST DONE");
        $finish;
    end

endmodule
