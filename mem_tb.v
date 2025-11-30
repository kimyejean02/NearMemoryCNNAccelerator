module tb_mem;

    reg clk;
    reg sel;
    reg w_en;
    reg [7:0] addr;

    wire [31:0] data_bus;
    reg [31:0] tb_data;

    wire mem_ready;

    assign data_bus = (sel && w_en) ? tb_data : 32'bZ;

    // DUT
    mem #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(8),
        .LATENCY(3)
    ) dut (
        .clk(clk),
        .sel(sel),
        .w_en(w_en),
        .address_bus(addr),
        .data_bus(data_bus),
        .ready(mem_ready)
    );

    // Clock
    always #10 clk = ~clk;

    task write_mem(input [7:0] a, input [31:0] d);
    begin
        @(negedge clk);
        addr    = a;
        tb_data = d;
        w_en    = 1;
        sel     = 1;

        @(posedge clk);

        while (!mem_ready) @(posedge clk);

        // 4) Drop controls
        @(negedge clk);
        sel = 0;
        w_en = 0;
    end
    endtask

    task read_mem(input [7:0] a);
    begin
        @(negedge clk);
        addr = a;
        w_en = 0;
        sel  = 1;

        @(posedge clk);
        while (!mem_ready) @(posedge clk);

        $display("Read %0d from %0d", data_bus, a);

        @(negedge clk);
        sel = 0;
    end
    endtask

    initial begin
        clk = 0;
        sel = 0;
        w_en = 0;
        addr = 0;
        tb_data = 0;

        repeat(3) @(posedge clk);

        // writes
        for (integer i=0; i<16; i=i+1) begin
            write_mem(i, $urandom);
        end

        // reads
        for (integer i=0; i<16; i=i+1) begin
            read_mem(i);
        end

        $finish;
    end

endmodule

