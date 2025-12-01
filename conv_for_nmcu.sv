module conv_for_nmcu #(
    parameter MAX_INPUT_DIM=15,
    parameter MAX_KERNEL_DIM=7,
    parameter DATABUS_WIDTH=32
)(
    input wire clk,
    input wire rst,

    input wire start,
    output reg done,

    input wire [$clog2(MAX_INPUT_DIM):0] input_width,
    input wire [$clog2(MAX_INPUT_DIM):0] input_height,
    input wire [$clog2(MAX_KERNEL_DIM):0] kernel_size,

    input wire [DATABUS_WIDTH-1:0] local_kernel [0:MAX_KERNEL_DIM-1][0:MAX_KERNEL_DIM-1],
    input wire [DATABUS_WIDTH-1:0] local_activation_in [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1],
    output reg [DATABUS_WIDTH-1:0] local_activation_out [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1]
);
    wire [$clog2(MAX_INPUT_DIM):0] out_width  = input_width  - kernel_size + 1;
    wire [$clog2(MAX_INPUT_DIM):0] out_height = input_height - kernel_size + 1;

    // kernel iterators
    reg [$clog2(MAX_KERNEL_DIM):0] i, j;

    // sliding window iterators
    reg [$clog2(MAX_INPUT_DIM):0] x, y;

    // accumulator
    reg signed [DATABUS_WIDTH-1:0] acc;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    initial begin 
        state     <= IDLE;
        x         <= 0;
        y         <= 0;
        i         <= 0;
        j         <= 0;
        acc       <= 0;
        done      <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            x         <= 0;
            y         <= 0;
            i         <= 0;
            j         <= 0;
            acc       <= 0;
            done      <= 0;
        end else begin
            case (state)
                IDLE: begin
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
                    acc <= acc + local_activation_in[y+i][x+j] * local_kernel[i][j];
                    if (i == kernel_size-1 & j == kernel_size-1) begin
                        i <= 0;
                        j <= 0;
                        local_activation_out[y][x] <= acc + local_activation_in[y+i][x+j] * local_kernel[i][j];
                        state <= NEXT;
                    end else if (j == kernel_size-1) begin
                        i <= i + 1;
                        j <= 0;
                    end else begin
                        j <= j + 1;
                    end
                end

                // Move to next output pixel
                NEXT: begin
                    acc <= 0;

                    if (x < out_width - 1) begin
                        x <= x + 1;
                        state <= COMPUTE;
                    end else begin
                        x <= 0;
                        if (y < out_height - 1) begin
                            y <= y + 1;
                            state <= COMPUTE;
                        end else begin
                            state <= FINISHED;
                        end
                    end
                end

                FINISHED: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule
