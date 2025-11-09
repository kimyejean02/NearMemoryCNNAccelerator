module cu #(
    parameter activation_width = 16,
    parameter weight_width = 8,
    parameter accumulator_width = 40,
    parameter array_x = 4,
    parameter array_y = 4,
    parameter tile_x = 8,
    parameter tile_y = 8
)(
    input wire clk,
    input wire rstn,
    input wire start,

    // configuration
    input wire [15:0] in_base_addr,
    input wire [15:0] weight_base_addr,
    input wire [15:0] out_base_addr,
    input wire [7:0] stride,
    input wire [7:0] kernel_size,
    input wire [15:0] channels_in,
    input wire [15:0] channels_out,
    output wire done,

    // memory read
    output wire mem_read_req,
    output wire [31:0] mem_read_addr,
    input wire mem_read_valid,
    input wire [31:0] mem_read_data,

    // memory write
    output wire mem_write_req,
    output wire [31:0] mem_write_addr,
    output wire [31:0] mem_write_data,
    input wire mem_write_ack
);

    wire [activation_width-1:0] activations;
    wire [weight_width-1:0] weights [0:array_x-1][0:array_y-1];
    wire enable, clear;
    wire [accumulator_width-1:0] acc [0:array_x-1][0:array_y-1];

    pe_array #(.activation_width(activation_width), .weight_width(weight_width), .accumulator_width(accumulator_width), .array_x(array_x), .array_y(array_y)) pe_array_i (
        .clk(clk),
        .rstn(rstn),
        .activations(activations),
        .weights(weights),
        .enable(enable),
        .clear(clear),
        .acc_out(acc)
    );

    cu_controller #(.activation_width(activation_width), .weight_width(weight_width), .accumulator_width(accumulator_width), .array_x(array_x), .array_y(array_y), .tile_x(tile_x), .tile_y(tile_y)) ctrl_i (
        .clk(clk),
        .rstn(rstn),
        .start(start),
        .in_base_addr(in_base_addr),
        .weight_base_addr(weight_base_addr),
        .out_base_addr(out_base_addr),
        .stride(stride),
        .kernel_size(kernel_size),
        .channels_in(channels_in),
        .channels_out(channels_out),

        .mem_read_req(mem_read_req),
        .mem_read_addr(mem_read_addr),
        .mem_read_valid(mem_read_valid),
        .mem_read_data(mem_read_data),

        .mem_write_req(mem_write_req),
        .mem_write_addr(mem_write_addr),
        .mem_write_data(mem_write_data),
        .mem_write_ack(mem_write_ack),

        .activations(activations),
        .weights(weights),
        .enable(enable),
        .clear(clear),
        .acc(acc),
        .done(done)
    );
endmodule