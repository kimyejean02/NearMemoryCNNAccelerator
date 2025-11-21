module dot_product #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input  wire signed [N*DATA_WIDTH-1:0] in_a,
    input  wire signed [N*DATA_WIDTH-1:0] in_b,
    output wire signed [ACC_WIDTH-1:0]    out
);

    // Unpack into 2D arrays
    wire signed [DATA_WIDTH-1:0] a [0:N-1];
    wire signed [DATA_WIDTH-1:0] b [0:N-1];

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : UNPACK
            assign a[i] = in_a[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            assign b[i] = in_b[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    // Multiply arrays
    wire signed [2*DATA_WIDTH-1:0] products [0:N-1];
    generate
        for (i = 0; i < N; i = i + 1) begin : MULT
            assign products[i] = a[i] * b[i];
        end
    endgenerate

    // Adder tree
    function integer ceil_div2(input integer v);
        ceil_div2 = (v >> 1) + (v & 1);
    endfunction

    localparam MAX_LEVELS = $clog2(N);

    wire signed [ACC_WIDTH-1:0] level [0:MAX_LEVELS][0:N-1];

    generate
        for (i = 0; i < N; i = i + 1) begin : LEVEL0
            assign level[0][i] = {{(ACC_WIDTH-2*DATA_WIDTH){products[i][2*DATA_WIDTH-1]}}, products[i]};
        end
    endgenerate

    genvar lvl, idx;
    generate
        for (lvl = 0; lvl < MAX_LEVELS; lvl = lvl + 1) begin : REDUCE_LEVEL
            for (idx = 0; idx < ceil_div2(N >> lvl); idx = idx + 1) begin : ADD
                if (2*idx+1 < (N >> lvl))
                    assign level[lvl+1][idx] = (level[lvl][2*idx] + level[lvl][2*idx+1]);
                else
                    assign level[lvl+1][idx] = level[lvl][2*idx];
            end
        end
    endgenerate

    assign out = level[MAX_LEVELS][0];

endmodule