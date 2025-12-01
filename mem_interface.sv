module mem_interface #(
    parameter NUM_PORTS = 9,
    parameter ADDR_WIDTH = 16,
    parameter DATABUS_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [NUM_PORTS-1:0] mem_w_ind,
    input wire [NUM_PORTS-1:0] mem_sel_ind,
    output reg [NUM_PORTS-1:0] mem_ready_ind,

    input wire [ADDR_WIDTH-1:0] addr_bus_ind [NUM_PORTS-1:0],
    inout wire [DATABUS_WIDTH-1:0] data_bus_ind [NUM_PORTS-1:0],

    // mem interface
    output reg mem_w,
    output reg mem_sel,
    input wire mem_ready,
    output wire [ADDR_WIDTH-1:0] addr_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus
);
    reg [$clog2(NUM_PORTS):0] i;

    reg [ADDR_WIDTH-1:0] address;
    assign addr_bus = (mem_sel) ? address: 'z;

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (mem_sel && mem_w) ? data : 'z;
    
    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            mem_ready_ind <= '0;
            i <= 0;
        end else begin
            if (mem_sel_ind[i] & !mem_ready_ind[i]) begin // unserviced request
                mem_w <= mem_w_ind[i];
                mem_sel <= mem_sel_ind[i];
                address  <= addr_bus_ind[i];
                if (mem_w_ind[i]) begin
                    data <= data_bus_ind[i];
                end
                mem_ready_ind[i] <= mem_ready;
            end else begin 
                mem_ready_ind[i] <= 1'b0;
                i <= (i + 1) % NUM_PORTS;
            end
        end
    end
endmodule
