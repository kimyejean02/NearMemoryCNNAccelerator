module convolution #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32,
    parameter HEIGHT     = 4,
    parameter WIDTH      = 4,
    parameter K          = 2
)(
    input  wire clk,
    input  wire rst,

    input  wire start,
    output reg  done,

    input  wire signed [DATA_WIDTH-1:0] matrix [0:HEIGHT-1][0:WIDTH-1],
    input  wire signed [DATA_WIDTH-1:0] kernel [0:K-1][0:K-1],

    output reg signed [ACC_WIDTH-1:0] out_pixel,
    output reg                        out_valid
);

    // Output dimensions
    localparam OUT_H = HEIGHT - K + 1;
    localparam OUT_W = WIDTH  - K + 1;

    integer i, j;

    // Sliding window coordinates
    reg [$clog2(HEIGHT):0] y;
    reg [$clog2(WIDTH):0]  x;

    reg signed [ACC_WIDTH-1:0] acc;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            x         <= 0;
            y         <= 0;
            out_valid <= 0;
            done      <= 0;
            acc       <= 0;
        end else begin
            case (state)

                IDLE: begin
                    out_valid <= 0;
                    done      <= 0;
                    if (start) begin
                        x <= 0;
                        y <= 0;
                        acc <= 0;
                        state <= COMPUTE;
                    end
                end

                // Compute convolution for current window
                COMPUTE: begin
                    // acc = 0;
                    // for (i = 0; i < K; i = i + 1) begin
                    //     for (j = 0; j < K; j = j + 1) begin
                    //         acc = acc + 
                    //             matrix[y+i][x+j] * kernel[i][j];
                    //     end
                    // end
                    acc <= acc + matrix[y+i][x+j] * kernel[i][j];
                    if (i == K-1 & j == K-1) begin
                        i <= 0;
                        j <= 0;
                        out_pixel <= acc;
                        out_valid <= 1;
                        state <= NEXT;
                    end else if (j == K-1) begin
                        i <= i + 1;
                        j <= 0;
                    end else begin
                        j <= j + 1;
                    end
                end

                // Move to next output pixel
                NEXT: begin
                    out_valid <= 0;

                    if (x < OUT_W - 1) begin
                        x <= x + 1;
                    end else begin
                        x <= 0;
                        if (y < OUT_H - 1) begin
                            y <= y + 1;
                        end else begin
                            state <= FINISHED;
                        end
                    end

                    state <= (state == FINISHED) ? FINISHED : COMPUTE;
                end

                FINISHED: begin
                    done <= 1;
                    out_valid <= 0;
                end
            endcase
        end
    end
endmodule
