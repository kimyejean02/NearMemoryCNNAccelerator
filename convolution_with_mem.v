module convolution_with_mem #(
    parameter MAT_WIDTH  = 8,
    parameter K_WIDTH    = 8,
    parameter ADDR_WIDTH = 8,
    parameter DATABUS_WIDTH = 32,
    parameter ACC_WIDTH  = 32,
    parameter HEIGHT     = 4,
    parameter WIDTH      = 4,
    parameter K          = 2
)(
    input  wire clk,
    input  wire rst,

    input  wire start,
    output reg  done,

    input wire [ADDR_WIDTH-1:0] matrix_addr,
    input wire [ADDR_WIDTH-1:0] kernel_addr,
    input wire [ADDR_WIDTH-1:0] output_addr,

    // mem interface
    output reg mem_w,
    output reg mem_sel,
    inout wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus
);

    // Output dimensions
    localparam OUT_H = HEIGHT - K + 1;
    localparam OUT_W = WIDTH  - K + 1;

    integer i, j;

    // Sliding window coordinates
    reg [$clog2(WIDTH):0]  x;
    reg [$clog2(HEIGHT):0] y;

    reg signed [MAT_WIDTH-1:0] matrix [0:HEIGHT-1][0:WIDTH-1];
    reg signed [K_WIDTH-1:0] kernel [0:K-1][0:K-1];
    reg signed [ACC_WIDTH-1:0] acc;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_MAT,
        LOAD_KERN,
        COMPUTE,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    wire driving_mem;
    assign driving_mem = (state == LOAD_MAT) || (state == LOAD_KERN) || (state == NEXT);

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = (driving_mem)?address:{ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (driving_mem && mem_w)?data:{DATABUS_WIDTH{1'bZ}};

    initial begin 
        state     <= IDLE;
        x         <= 0;
        y         <= 0;
        i         <= 0;
        j         <= 0;
        mem_w      <= 0;
        mem_sel       <= 0;
        address   <= 0;
        done      <= 0;
        acc       <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            x         <= 0;
            y         <= 0;
            i         <= 0;
            j         <= 0;
            mem_w     <= 0;
            mem_sel       <= 0;
            address   <= 0;
            data <= 0;
            done      <= 0;
            acc       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done      <= 0;
                    if (start) begin
                        x <= 0;
                        y <= 0;
                        i <= 0;
                        j <= 0;
                        acc <= 0;

                        mem_w <= 0;
                        mem_sel <= 1;
                        address <= matrix_addr;

                        state <= LOAD_MAT;
                    end
                end

                LOAD_MAT: begin 
                    matrix[i][j] <= data_bus;
                    address <= address + 1;
                    if (i == HEIGHT-1 && j == WIDTH-1) begin 
                        i <= 0;
                        j <= 0;

                        mem_w <= 0;
                        mem_sel <= 1;
                        address <= kernel_addr;

                        state <= LOAD_KERN;
                    end else if (j == WIDTH-1) begin
                        i <= i+1;
                        j <= 0;
                    end else begin 
                        j <= j+1;
                    end
                end

                LOAD_KERN: begin 
                    kernel[i][j] <= data_bus;
                    address <= address + 1;
                    if (i == K-1 && j == K-1) begin 
                        i <= 0;
                        j <= 0;

                        mem_w <= 1;
                        mem_sel <= 0;
                        address <= output_addr;

                        state <= COMPUTE;
                    end else if (j == K-1) begin 
                        i <= i+1;
                        j <= 0;
                    end else begin 
                        j <= j+1;
                    end
                end

                // Compute convolution for current window
                COMPUTE: begin
                    acc <= acc + matrix[y+i][x+j] * kernel[i][j];
                    if (i == K-1 && j == K-1) begin
                        i <= 0;
                        j <= 0;

                        data <= acc + matrix[y+i][x+j] * kernel[i][j];
                        mem_sel <= 1;

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
                    mem_sel <= 0;
                    acc <= 0;
                    address <= address + 1;

                    if (x < OUT_W - 1) begin
                        x <= x + 1;
                        state <= COMPUTE;
                    end else begin
                        x <= 0;
                        if (y < OUT_H - 1) begin
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
