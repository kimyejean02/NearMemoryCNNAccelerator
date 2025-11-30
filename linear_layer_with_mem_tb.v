`timescale 1ns/1ps

module linear_layer_with_mem_tb;

    localparam DATA_WIDTH    = 8;
    localparam W_WIDTH       = 8;
    localparam ACC_WIDTH     = 32;
    localparam ADDR_WIDTH    = 8;
    localparam DATABUS_WIDTH = 32;
    localparam N = 4;
    localparam M = 3;

    reg clk;
    reg rst;
    reg start;

    wire done;
    wire out_valid;

    reg [ADDR_WIDTH-1:0] activ_base  = 0;
    reg [ADDR_WIDTH-1:0] weight_base = 16;
    reg [ADDR_WIDTH-1:0] bias_base   = 28;
    reg [ADDR_WIDTH-1:0] output_base = 32;

    wire mem_w;
    wire mem_sel;
    wire [ADDR_WIDTH-1:0] address_bus;
    wire [DATABUS_WIDTH-1:0] data_bus;
    wire mem_ready;

    // Instantiate the memory
    mem #(
        .DATA_WIDTH(DATABUS_WIDTH),
        .ADDRESS_WIDTH(ADDR_WIDTH),
        .LATENCY(1)
    ) memory (
        .clk(clk),
        .sel(mem_sel),
        .w_en(mem_w),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(mem_ready)
    );

    // Instantiate the linear layer
    linear_layer_with_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .W_WIDTH(W_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH),
        .N(N),
        .M(M)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .activ_base(activ_base),
        .weight_base(weight_base),
        .bias_base(bias_base),
        .output_base(output_base),
        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(mem_ready),
        .done(done),
        .out_valid(out_valid)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    integer i, j;

    initial begin
        rst = 1;
        start = 0;

        // Wait a few cycles
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Directly initialize memory
        for (i = 0; i < N; i = i + 1)
            memory.memory[activ_base + i] = i + 1; // activations: 1,2,3,4

        for (i = 0; i < M; i = i + 1)
            for (j = 0; j < N; j = j + 1)
                memory.memory[weight_base + i*N + j] = (i+1)*(j+1); // weights

        for (i = 0; i < M; i = i + 1)
            memory.memory[bias_base + i] = (i+1)*10; // biases: 10,20,30

        // Start linear layer
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait until done
        wait(done);

        // Read output values directly from memory
        for (i = 0; i < M; i = i + 1) begin
            @(posedge clk);
            $display("Output %0d = %0d", i, memory.memory[output_base + i]);
        end

        $display("=== TEST FINISHED ===");
        $finish;
    end

endmodule

