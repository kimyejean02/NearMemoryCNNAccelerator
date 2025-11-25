module relu #(
    parameter DATA_WIDTH = 8
)(
    input  signed [DATA_WIDTH-1:0] in,
    output signed [DATA_WIDTH-1:0] out
);

    assign out = (in > 0) ? in : 0;

endmodule
