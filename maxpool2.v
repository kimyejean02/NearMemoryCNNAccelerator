module maxpool2 #(
    parameter DATA_WIDTH = 8
)(
    input  wire [DATA_WIDTH-1:0] in [0:1][0:1],
    output wire [DATA_WIDTH-1:0] out
);

    wire [DATA_WIDTH-1:0] max_ab;
    wire [DATA_WIDTH-1:0] max_cd;

    assign max_ab = (in[0][0] > in[0][1]) ? in[0][0] : in[0][1];
    assign max_cd = (in[1][0] > in[1][1]) ? in[1][0] : in[1][1];

    assign out = (max_ab > max_cd) ? max_ab : max_cd;

endmodule
