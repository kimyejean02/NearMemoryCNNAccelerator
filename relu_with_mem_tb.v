`timescale 1ns/1ps

module tb_relu_with_mem;
    reg clk;
    reg rst;
    reg start;
    wire done;

    localparam DATA_WIDTH = 8;
    localparam DATABUS_WIDTH = 32;
    localparam ADDR_WIDTH = 8;
    localparam HEIGHT = 2;
    localparam WIDTH = 3;
    localparam N = HEIGHT * WIDTH;

    reg [ADDR_WIDTH-1:0] input_addr;
    reg [ADDR_WIDTH-1:0] output_addr;

    wire mem_sel;
    wire mem_w_en;
    wire [ADDR_WIDTH-1:0] address_bus;
    wire [DATABUS_WIDTH-1:0] data_bus;
    wire ready;

    // instantiate memory
    mem #(
        .DATA_WIDTH(DATABUS_WIDTH),
        .ADDRESS_WIDTH(ADDR_WIDTH)
    ) memory (
        .clk(clk),
        .w_en(mem_w_en),
        .sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    // instantiate DUT
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
        .mem_w(mem_w_en),
        .mem_sel(mem_sel),
        .address_bus(address_bus),
        .data_bus(data_bus),
        .ready(ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer i;
    reg signed [DATA_WIDTH-1:0] vals [0:N-1];

    initial begin
        rst = 1;
        start = 0;
        input_addr = 8'd0;
        output_addr = 8'd100;

        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // manually initialize memory line by line
        vals[0] = -3;
        vals[1] = -1;
        vals[2] = 0;
        vals[3] = 5;
        vals[4] = 127;
        vals[5] = -128;

        memory.memory[input_addr + 0] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[0][DATA_WIDTH-1]}}, vals[0]};
        memory.memory[input_addr + 1] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[1][DATA_WIDTH-1]}}, vals[1]};
        memory.memory[input_addr + 2] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[2][DATA_WIDTH-1]}}, vals[2]};
        memory.memory[input_addr + 3] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[3][DATA_WIDTH-1]}}, vals[3]};
        memory.memory[input_addr + 4] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[4][DATA_WIDTH-1]}}, vals[4]};
        memory.memory[input_addr + 5] = {{(DATABUS_WIDTH-DATA_WIDTH){vals[5][DATA_WIDTH-1]}}, vals[5]};

        $display("Memory manually initialized with input values.");

        // start DUT
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // wait for DUT to finish
        wait(done);

        $display("DUT finished. Reading outputs:");

        // read back outputs manually after DUT done
        for (i = 0; i < N; i = i + 1) begin
            $display("mem[%0d] = %0d", output_addr + i, $signed(memory.memory[output_addr + i][DATA_WIDTH-1:0]));
        end

        $display("TEST DONE");
        $finish;
    end
endmodule

