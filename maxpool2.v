module maxpool2 #(
    parameter DATA_WIDTH = 8
)(
    input  wire [DATA_WIDTH*2*2-1:0] in,
    output wire [DATA_WIDTH-1:0] out
);

    wire [DATA_WIDTH-1:0] max_ab;
    wire [DATA_WIDTH-1:0] max_cd;

    assign max_ab = (in[0] > in[1]) ? in[0] : in[1];
    assign max_cd = (in[2] > in[3]) ? in[2] : in[3];

    assign max_out = (max_ab > max_cd) ? max_ab : max_cd;

endmodule