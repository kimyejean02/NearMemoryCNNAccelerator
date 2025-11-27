module mem
#(
    parameter DATA_WIDTH=32,
    parameter ADDRESS_WIDTH=8
)
(
    input wire clk,
    input wire w_en,
    input wire sel,
    input wire [ADDRESS_WIDTH-1:0] address_bus,
    inout wire [DATA_WIDTH-1:0] data_bus
);
    reg [DATA_WIDTH-1:0] memory [(2**ADDRESS_WIDTH)-1:0];
    reg [DATA_WIDTH-1:0] d_out;

    assign data_bus = (sel && !w_en)?d_out:'hZ;

    always @(*) begin
        if (sel) begin
            if (w_en) begin
                memory[address_bus] <= data_bus;
            end else begin 
                d_out <= memory[address_bus];
            end
        end
    end

endmodule
