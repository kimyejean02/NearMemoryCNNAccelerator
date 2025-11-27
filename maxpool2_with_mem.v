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
    inout wire [DATABUS_WIDTH-1:0] data_bus
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
    
    // Temporary storage for pooling window
    reg [DATA_WIDTH-1:0] pool_window [0:POOL_SIZE-1][0:POOL_SIZE-1];
    reg [DATA_WIDTH-1:0] max_val;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_INPUT,
        LOAD_WINDOW,
        COMPUTE,
        WRITE_OUTPUT,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    wire driving_mem;
    assign driving_mem = (state == LOAD_INPUT) || (state == WRITE_OUTPUT);

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = (driving_mem) ? address : {ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (driving_mem && mem_w) ? data : {DATABUS_WIDTH{1'bZ}};

    initial begin 
        state     <= IDLE;
        x         <= 0;
        y         <= 0;
        i         <= 0;
        j         <= 0;
        mem_w     <= 0;
        mem_sel   <= 0;
        address   <= 0;
        done      <= 0;
        max_val   <= 0;
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
            max_val   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        x <= 0;
                        y <= 0;
                        i <= 0;
                        j <= 0;
                        max_val <= 0;

                        mem_w <= 0;
                        mem_sel <= 1;
                        address <= input_addr;

                        state <= LOAD_INPUT;
                    end
                end

                // Load entire input matrix from memory
                LOAD_INPUT: begin 
                    input_mat[i][j] <= data_bus[DATA_WIDTH-1:0];
                    address <= address + 1;

                    if (i == HEIGHT-1 && j == WIDTH-1) begin 
                        i <= 0;
                        j <= 0;

                        mem_w <= 1;
                        mem_sel <= 0;
                        address <= output_addr;

                        state <= LOAD_WINDOW;
                    end else if (j == WIDTH-1) begin
                        i <= i + 1;
                        j <= 0;
                    end else begin 
                        j <= j + 1;
                    end
                end

                // Load pooling window from input matrix
                LOAD_WINDOW: begin
                    pool_window[i][j] <= input_mat[y+i][x+j];

                    if (i == POOL_SIZE-1 && j == POOL_SIZE-1) begin
                        i <= 0;
                        j <= 0;
                        max_val <= input_mat[y][x];  // Initialize with first element
                        state <= COMPUTE;
                    end else if (j == POOL_SIZE-1) begin
                        i <= i + 1;
                        j <= 0;
                    end else begin
                        j <= j + 1;
                    end
                end

                // Compute max pooling for current window
                COMPUTE: begin
                    // Update max value if current element is larger
                    if (pool_window[i][j] > max_val) begin
                        max_val <= pool_window[i][j];
                    end

                    if (i == POOL_SIZE-1 && j == POOL_SIZE-1) begin
                        i <= 0;
                        j <= 0;
                        state <= WRITE_OUTPUT;
                    end else if (j == POOL_SIZE-1) begin
                        i <= i + 1;
                        j <= 0;
                    end else begin
                        j <= j + 1;
                    end
                end

                // Write output to memory
                WRITE_OUTPUT: begin
                    data <= {{(DATABUS_WIDTH-DATA_WIDTH){1'b0}}, max_val};
                    mem_sel <= 1;
                    state <= NEXT;
                end

                // Move to next output pixel
                NEXT: begin
                    mem_sel <= 0;
                    max_val <= 0;
                    address <= address + 1;

                    if (x < OUT_W - 1) begin
                        x <= x + STRIDE;
                        state <= LOAD_WINDOW;
                    end else begin
                        x <= 0;
                        if (y < OUT_H - 1) begin
                            y <= y + STRIDE;
                            state <= LOAD_WINDOW;
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
