module mem
#(
    parameter DATA_WIDTH    = 32,
    parameter ADDRESS_WIDTH = 8,
    parameter LATENCY       = 2
)
(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     sel,
    input  wire                     w_en,
    input  wire [ADDRESS_WIDTH-1:0] address_bus,
    inout  wire [DATA_WIDTH-1:0]    data_bus,

    output reg                      ready
);

    reg [DATA_WIDTH-1:0] memory [(2**ADDRESS_WIDTH)-1:0];
    reg [DATA_WIDTH-1:0] d_out;
    reg data_valid;

    assign data_bus = (sel && !w_en && data_valid) ? d_out : {DATA_WIDTH{1'bz}};

    reg [$clog2(LATENCY+1)-1:0] cnt = 0;
    reg req_active = 0;
    reg [ADDRESS_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0]    wdata_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ready <= 0;
            data_valid <= 0;
        end else begin
            if (!sel) begin
                req_active <= 0;
            end
            if (sel && !req_active) begin
                req_active <= 1;
                cnt        <= LATENCY;
                ready      <= 0;

                addr_reg <= address_bus;
                wdata_reg <= data_bus;
            end
            if (req_active && sel) begin
                if (cnt != 0) begin
                    cnt <= cnt - 1;
                end else begin
                    req_active <= 0;
                    ready <= 1;
                    data_valid <= 1;

                    if (w_en) begin
                        memory[addr_reg] <= wdata_reg;
                        data_valid <= 0;
                    end else begin
                        d_out <= memory[addr_reg];
                    end
                end
            end
        end
    end

endmodule

