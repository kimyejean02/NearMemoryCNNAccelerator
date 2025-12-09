module maxpool2_with_mem #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter DATABUS_WIDTH = 32,
    parameter HEIGHT = 4,
    parameter WIDTH = 4,
    parameter POOL_SIZE = 2,
    parameter STRIDE = 2
)(
    input  wire clk,
    input  wire rst,

    input  wire start,
    output reg  done,

    input wire [ADDR_WIDTH-1:0] input_addr,
    input wire [ADDR_WIDTH-1:0] output_addr,

    // Memory interface
    output reg mem_w,
    output reg mem_sel,
    inout wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus,
    input  wire ready
);

    // Output dimensions
    localparam OUT_H = (HEIGHT - POOL_SIZE) / STRIDE + 1;
    localparam OUT_W = (WIDTH - POOL_SIZE) / STRIDE + 1;

    integer i, j;

    // Pooling window coordinates
    reg [$clog2(WIDTH):0]  x;
    reg [$clog2(HEIGHT):0] y;

    // Internal storage for input matrix
    reg [DATA_WIDTH-1:0] input_mat [0:HEIGHT-1][0:WIDTH-1];

    // Temporary storage for max value
    reg [DATA_WIDTH-1:0] max_val;
    reg [$clog2(POOL_SIZE):0] pool_i, pool_j;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_INPUT,
        INIT_WINDOW,
        COMPUTE,
        WRITE_OUTPUT,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    wire driving_mem;
    assign driving_mem = (state == LOAD_INPUT) || (state == WRITE_OUTPUT);

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = (mem_sel)? address : {ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (mem_sel && mem_w)? data : {DATABUS_WIDTH{1'bZ}};

    reg stall;

    initial begin
        state   <= IDLE;
        x       <= 0;
        y       <= 0;
        i       <= 0;
        j       <= 0;
        mem_w   <= 0;
        mem_sel <= 0;
        address <= 0;
        done    <= 0;
        max_val <= 0;
        stall   <= 0;
        pool_i  <= 0;
        pool_j  <= 0;
        data    <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            x       <= 0;
            y       <= 0;
            i       <= 0;
            j       <= 0;
            mem_w   <= 0;
            mem_sel <= 0;
            address <= 0;
            data    <= 0;
            done    <= 0;
            max_val <= 0;
            stall   <= 0;
            pool_i  <= 0;
            pool_j  <= 0;
        end else begin
            if (stall) begin
                mem_sel <= 0;
                mem_w   <= 0;
                stall   <= 0;
            end else begin
                case (state)
                    IDLE: begin
                        done <= 0;
                        if (start) begin
                            x <= 0;
                            y <= 0;
                            i <= 0;
                            j <= 0;
                            mem_w <= 0;
                            mem_sel <= 0;
                            address <= input_addr;
                            state <= LOAD_INPUT;
                        end
                    end

                    // Load entire input matrix from memory
                    LOAD_INPUT: begin
                        mem_sel <= 1;
                        mem_w   <= 0;
                        if (ready) begin
                            input_mat[i][j] <= data_bus[DATA_WIDTH-1:0];
                            address <= address + 1;
                            mem_sel <= 0;
                            stall <= 1;

                            if (i == HEIGHT-1 && j == WIDTH-1) begin
                                i <= 0;
                                j <= 0;
                                mem_w <= 1;
                                address <= output_addr;
                                state <= INIT_WINDOW;
                            end else if (j == WIDTH-1) begin
                                i <= i + 1;
                                j <= 0;
                            end else begin
                                j <= j + 1;
                            end
                        end
                    end

                    // Initialize pooling window
                    INIT_WINDOW: begin
                        pool_i <= 0;
                        pool_j <= 0;
                        max_val <= input_mat[y][x];
                        state <= COMPUTE;
                    end

                    // Compute max pool for current window
                    COMPUTE: begin
                        if (input_mat[y + pool_i][x + pool_j] > max_val)
                            max_val <= input_mat[y + pool_i][x + pool_j];

                        if (pool_j == POOL_SIZE-1) begin
                            pool_j <= 0;
                            if (pool_i == POOL_SIZE-1) begin
                                pool_i <= 0;
                                state <= WRITE_OUTPUT;
                            end else begin
                                pool_i <= pool_i + 1;
                            end
                        end else begin
                            pool_j <= pool_j + 1;
                        end
                    end

                    // Write output to memory
                    WRITE_OUTPUT: begin
                        mem_sel <= 1;
                        mem_w <= 1;
                        data <= {{(DATABUS_WIDTH-DATA_WIDTH){1'b0}}, max_val};
                        if (ready) begin
                            mem_sel <= 0;
                            mem_w <= 0;
                            stall <= 1;
                            state <= NEXT;
                        end
                    end

                    // Move sliding window
                    NEXT: begin
                        if (x < OUT_W - 1) begin
                            x <= x + STRIDE;
                            state <= INIT_WINDOW;
                        end else begin
                            x <= 0;
                            if (y < OUT_H - 1) begin
                                y <= y + STRIDE;
                                state <= INIT_WINDOW;
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
    end
endmodule

