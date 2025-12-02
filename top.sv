`timescale 1ns/1ps

module top_nmcu_4 #(
    parameter ADDR_WIDTH      = 16,
    parameter DATABUS_WIDTH   = 32,
    parameter MAX_DESCS       = 8,
    parameter MAX_INPUT_DIM   = 15,
    parameter MAX_KERNEL_DIM  = 7,
    parameter NUM_NMCUS       = 4                             // fixed 2×2 grid
)(
    input  wire                        clk,
    input  wire                        rst,

    input  wire [NUM_NMCUS-1:0]        start,
    output wire [NUM_NMCUS-1:0]        done,

    // Shared descriptor (same for all NMCUs)
    input  wire [ADDR_WIDTH-1:0]       nmcu_desc,

    // 2×2 grid input/output addresses
    input  wire [ADDR_WIDTH-1:0]       input_addresses  [0:1][0:1],
    input  wire [ADDR_WIDTH-1:0]       output_addresses [0:1][0:1],

    input  wire [$clog2(MAX_INPUT_DIM):0] full_input_width,
    input  wire [$clog2(MAX_INPUT_DIM):0] full_input_height,
    input  wire [$clog2(MAX_INPUT_DIM):0] full_output_width,
    input  wire [$clog2(MAX_INPUT_DIM):0] full_output_height,

    output wire                        mem_sel,
    output wire                        mem_w,
    output wire [ADDR_WIDTH-1:0]       addr_bus,
    inout  wire [DATABUS_WIDTH-1:0]    data_bus,
    input  wire                        mem_ready
);

    wire [ADDR_WIDTH-1:0]     addr_bus_ind [NUM_NMCUS-1:0];
    wire [DATABUS_WIDTH-1:0]  data_bus_ind [NUM_NMCUS-1:0];
    wire [NUM_NMCUS-1:0]      mem_w_ind;
    wire [NUM_NMCUS-1:0]      mem_sel_ind;
    wire [NUM_NMCUS-1:0]      mem_ready_ind;

    genvar i, j;

    generate
        for (i = 0; i < 2; i = i+1) begin : ROW
            for (j = 0; j < 2; j = j+1) begin : COL
                localparam IDX = i*2 + j;

                nmcu #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATABUS_WIDTH(DATABUS_WIDTH),
                    .MAX_DESCS(MAX_DESCS),
                    .MAX_INPUT_DIM(MAX_INPUT_DIM),
                    .MAX_KERNEL_DIM(MAX_KERNEL_DIM)
                ) u_nmcu (
                    .clk(clk),
                    .rst(rst),
                    .start(start[IDX]),
                    .done(done[IDX]),
                    .nmcu_desc(nmcu_desc),

                    .input_addr(input_addresses[i][j]),
                    .output_addr(output_addresses[i][j]),

                    .full_input_width(full_input_width),
                    .full_input_height(full_input_height),
                    .full_output_width(full_output_width),
                    .full_output_height(full_output_height),

                    .mem_w(mem_w_ind[IDX]),
                    .mem_sel(mem_sel_ind[IDX]),
                    .address_bus(addr_bus_ind[IDX]),
                    .data_bus(data_bus_ind[IDX]),
                    .ready(mem_ready_ind[IDX])
                );
            end
        end
    endgenerate

    mem_interface #(
        .NUM_PORTS(NUM_NMCUS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATABUS_WIDTH(DATABUS_WIDTH)
    ) mem_if (
        .clk(clk),
        .rst(rst),

        .mem_w_ind(mem_w_ind),
        .mem_sel_ind(mem_sel_ind),
        .mem_ready_ind(mem_ready_ind),
        .addr_bus_ind(addr_bus_ind),
        .data_bus_ind(data_bus_ind),

        .mem_w(mem_w),
        .mem_sel(mem_sel),
        .addr_bus(addr_bus),
        .data_bus(data_bus),
        .mem_ready(mem_ready)
    );

endmodule
