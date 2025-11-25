module mac2 (
    input [31:0] a,
    input [31:0] kernel,
    output [31:0] out
);
    reg [31:0] dot_prod [1:0][1:0];
    reg [31:0] add_l1 [1:0];
    reg [31:0] add_l2;

    assign out = add_l2;

    always @(*) begin
        dot_prod[0][0] = a[7:0] * kernel[7:0];
        dot_prod[0][1] = a[15:8] * kernel[15:8];
        dot_prod[1][0] = a[23:16] * kernel[23:16];
        dot_prod[1][1] = a[31:24] * kernel[31:24];

        add_l1[0] = dot_prod[0][0] + dot_prod[0][1];
        add_l1[1] = dot_prod[1][0] + dot_prod[1][1];

        add_l2 = add_l1[0] + add_l1[1];
    end
endmodule
