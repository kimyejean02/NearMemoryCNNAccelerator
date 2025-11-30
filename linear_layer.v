module linear_layer #(
    parameter DATA_WIDTH = 8,
    parameter W_WIDTH    = 8,
    parameter ACC_WIDTH  = 32,
    parameter N = 8,
    parameter M = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] activations [0:N-1],
    input  wire signed [W_WIDTH-1:0]    weights [0:M-1][0:N-1],
    input  wire signed [ACC_WIDTH-1:0]  bias [0:M-1],

    output reg  signed [ACC_WIDTH-1:0]  out,
    output reg                          out_valid,
    output reg                          done
);

    integer i, j;

    reg signed [ACC_WIDTH-1:0] acc;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        OUTPUT,
        FINISH
    } state_t;

    state_t state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            i         <= 0;
            j         <= 0;
            acc       <= 0;
            out       <= 0;
            out_valid <= 0;
            done      <= 0;
        end else begin
            case (state)

                IDLE: begin
                    out_valid <= 0;
                    done      <= 0;
                    if (start) begin
                        i     <= 0;
                        j     <= 0;
                        acc   <= bias[0];
                        state <= COMPUTE;
                    end
                end

                // activations[j] * weights[i][j]
                COMPUTE: begin
                    acc <= acc + activations[j] * weights[i][j];
                    if (j == N-1) begin
                        state <= OUTPUT;
                    end else begin
                        j <= j + 1;
                    end
                end

                // Output out[i]
                OUTPUT: begin
                    out       <= acc;
                    out_valid <= 1;
                    j         <= 0;
                    if (i == M-1) begin
                        state <= FINISH;
                    end else begin
                        i     <= i + 1;
                        acc   <= bias[i+1];
                        state <= COMPUTE;
                    end
                end

                FINISH: begin
                    out_valid <= 0;
                    done      <= 1;
                end
            endcase
        end
    end
endmodule
