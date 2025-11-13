module mac2 #(
    parameter width = 8;
)(
    input a [(2 * 2 * width) - 1 : 0];
    input kernel [(2 * 2 * width) - 1 : 0];
    output [width-1:0] out;
);
    wire [width - 1 : 0] dot_prod [2][2];
    wire [width - 1 : 0] add_l1 [2];

    integer i;
    always @(*) begin
        dot_prod[0][0] = a[0:7] * kernel[0:7];
        dot_prod[0][1] = a[8:15] * kernel[8:15];
        dot_prod[1][0] = a[16:23] * kernel[16:23];
        dot_prod[1][1] = a[24:31] * kernel[24:31];

        add_l1[0] = dot_prod[0][0] + dot_prod[0][1];
        add_l1[1] = dot_prod[1][0] + dot_prod[1][1];

        out = add_l1[0] + add_l1[1];
    end
endmodule