module relu_with_mem #(
    parameter DATA_WIDTH     = 8,
    parameter ADDR_WIDTH     = 8,
    parameter DATABUS_WIDTH  = 32,
    parameter HEIGHT         = 4,
    parameter WIDTH          = 4
)(
    input  wire clk,
    input  wire rst,

    input  wire start,
    output reg  done,

    input  wire [ADDR_WIDTH-1:0] input_addr,
    input  wire [ADDR_WIDTH-1:0] output_addr,

    // Memory interface
    output reg mem_w,
    output reg mem_sel,
    inout wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus,
    input  wire ready
);

    integer i, j;

    // Internal matrix storage
    reg signed [DATA_WIDTH-1:0] matrix [0:HEIGHT-1][0:WIDTH-1];
    reg signed [DATA_WIDTH-1:0] result [0:HEIGHT-1][0:WIDTH-1];

    // Sliding indices for load/write
    reg [$clog2(WIDTH):0]  x;
    reg [$clog2(HEIGHT):0] y;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_MAT,
        COMPUTE,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    wire driving_mem;
    // drive address during loads, computes (when writing) and next state transitions
    assign driving_mem = (state == LOAD_MAT) || (state == NEXT) || (state == COMPUTE);

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = (driving_mem) ? address : {ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (driving_mem && mem_w) ? data : {DATABUS_WIDTH{1'bZ}};

    reg stall;

    initial begin
        state     <= IDLE;
        x         <= 0;
        y         <= 0;
        i         <= 0;
        j         <= 0;
        mem_w     <= 0;
        mem_sel   <= 0;
        address   <= 0;
        data      <= 0;
        done      <= 0;
        stall     <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            x         <= 0;
            y         <= 0;
            i         <= 0;
            j         <= 0;
            mem_w     <= 0;
            mem_sel   <= 0;
            address   <= 0;
            data      <= 0;
            done      <= 0;
            stall     <= 0;
        end else begin
            if (stall) begin
                mem_w   <= 0;
                mem_sel <= 0;
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

                            mem_w <= 0;      // read
                            mem_sel <= 1;    // select memory for read
                            address <= input_addr;

                            state <= LOAD_MAT;
                        end
                    end

                    // Load entire input matrix from memory (assumes memory provides data when ready)
                    LOAD_MAT: begin
                        mem_sel <= 1;
                        mem_w   <= 0;
                        if (ready) begin
                            matrix[i][j] <= data_bus[DATA_WIDTH-1:0];
                            address <= address + 1;
                            stall <= 1;

                            if (i == HEIGHT-1 && j == WIDTH-1) begin
                                i <= 0;
                                j <= 0;

                                // prepare to compute and set write address base
                                address <= output_addr;
                                mem_sel <= 0; // switch to write semantics for subsequent writes

                                state <= COMPUTE;
                                x <= 0;
                                y <= 0;
                            end else if (j == WIDTH-1) begin
                                i <= i + 1;
                                j <= 0;
                            end else begin
                                j <= j + 1;
                            end
                        end
                    end

                    // Compute ReLU over current window element (element-wise)
                    COMPUTE: begin
                        if (matrix[y][x] > 0) begin
                            result[y][x] <= matrix[y][x];
                            data <= {{(DATABUS_WIDTH-DATA_WIDTH){matrix[y][x][DATA_WIDTH-1]}}, matrix[y][x]};
                        end else begin
                            result[y][x] <= 0;
                            data <= {DATABUS_WIDTH{1'b0}};
                        end
                        mem_w <= 1;
                        mem_sel <= 1;

                        if (ready) begin
                            stall <= 1;
                            state <= NEXT;
                        end
                    end

                    // move to next element and increment output address
                    NEXT: begin
                        mem_w <= 0;
                        mem_sel <= 0;
                        address <= address + 1;

                        if (x < WIDTH - 1) begin
                            x <= x + 1;
                            state <= COMPUTE;
                        end else begin
                            x <= 0;
                            if (y < HEIGHT - 1) begin
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

                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule

