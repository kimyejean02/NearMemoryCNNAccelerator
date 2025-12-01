module #(
    parameter NUM_PORTS = 9,
    parameter ADDR_WIDTH = 16,
    parameter DATABUS_WIDTH = 32
) mem_serializer (
    input wire clk,

    input wire [NUM_PORTS-1:0] mem_w_ind,
    input wire [NUM_PORTS-1:0] mem_sel_ind,
    output wire [NUM_PORTS-1:0] mem_ready_ind,

    input wire [ADDR_WIDTH-1:0] addr_bus_ind [0:NUM_PORTS-1],
    inout wire [DATABUS_WIDTH-1:0] data_bus_ind [0:NUM_PORTS-1],

    // mem interface
    output reg mem_w,
    output reg mem_sel,
    input wire mem_ready,
    output wire [ADDR_WIDTH-1:0] addr_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus
);

    

endmodule
