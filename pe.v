module pe #(
    parameter activation_width = 16,
    parameter weight_width = 8,
    parameter accumulator_width = 40
)(
    input wire clk,
    input wire rstn,
    input wire enable,
    input wire clear,
    input wire [activation_width-1:0] A_in,
    input wire [weight_width-1:0] W_in,
    output wire [accumulator_width-1:0] acc_out
);

    reg [accumulator_width-1:0] acc;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            acc <= 0;
        end
        else begin
            if (clear) begin
                acc <= 0;
            end
            else if (enable) begin
                acc <= acc + A_in * W_in;
            end
        end
    end

    assign acc_out = acc;
endmodule