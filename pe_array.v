module pe_array #(
    parameter activation_width = 16,
    parameter weight_width = 8,
    parameter accumulator_width = 40,
    parameter array_x = 4,
    parameter array_y = 4
)(
    input wire clk,
    input wire rstn,
    input wire [activation_width-1:0] activations,
    input wire [weight_width-1:0] weights [0:array_x-1][0:array_y-1],
    input wire enable,
    input wire clear,
    output wire [accumulator_width-1:0] acc_out [0:array_x-1][0:array_y-1]
);
    genvar i, j;
    generate
        for (i = 0; i < array_x; i = i + 1) begin : genx
            for (j = 0; j < array_y; j = j + 1) begin : geny
                pe #(.activation_width(activation_width), .weight_width(weight_width), .accumulator_width(accumulator_width)) pe_i (
                    .clk(clk),
                    .rstn(rstn),
                    .enable(enable),
                    .clear(clear),
                    .A_in(activations),
                    .W_in(weights[i][j]),
                    .acc_out(acc_out[i][j])
                );
            end
        end
    endgenerate
endmodule
