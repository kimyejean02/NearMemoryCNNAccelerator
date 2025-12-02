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
    reg [$clog2(NUM_PORTS):0] ind;

    reg [ADDR_WIDTH-1:0] address;
    assign addr_bus = (mem_sel) ? address: 'z;

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (mem_sel && mem_w) ? data : 'z;

    genvar i;
    generate
        for (i = 0; i < NUM_PORTS; i = i + 1) begin
            assign data_bus_ind[i] = (mem_sel_ind[i] && !mem_w_ind[i] && mem_ready_ind[i]) ? data_bus : 'z;
        end
    endgenerate
    
    reg stall;

    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            mem_ready_ind <= '0;
            ind <= 0;
        end else if (stall) begin
            mem_sel <= 0;
            mem_w <= 0;
            stall <= 0;
        end else begin
            if (mem_sel_ind[ind] & !mem_ready_ind[ind]) begin // unserviced request
                mem_w <= mem_w_ind[ind];
                mem_sel <= mem_sel_ind[ind];
                address  <= addr_bus_ind[ind];
                if (mem_w_ind[ind]) begin
                    data <= data_bus_ind[ind];
                end
                mem_ready_ind[ind] <= mem_ready;
                if (mem_ready) begin 
                    stall <= 1;
                end
            end else begin 
                mem_ready_ind[ind] <= 1'b0;
                ind <= (ind + 1) % NUM_PORTS;
            end
        end
    end
endmodule
