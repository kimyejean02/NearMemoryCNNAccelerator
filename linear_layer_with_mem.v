module linear_layer_with_mem #(
    parameter DATA_WIDTH    = 8,
    parameter W_WIDTH       = 8,
    parameter ACC_WIDTH     = 32,
    parameter ADDR_WIDTH    = 8,
    parameter DATABUS_WIDTH = 32,
    parameter N = 8,
    parameter M = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    input  wire [ADDR_WIDTH-1:0] activ_base,
    input  wire [ADDR_WIDTH-1:0] weight_base,
    input  wire [ADDR_WIDTH-1:0] bias_base,
    input  wire [ADDR_WIDTH-1:0] output_base,

    output reg mem_w,
    output reg mem_sel,
    output reg done,
    output reg out_valid,

    inout  wire [ADDR_WIDTH-1:0]    address_bus,
    inout  wire [DATABUS_WIDTH-1:0] data_bus,
    input  wire                     ready
);

    integer i, j;

    reg signed [DATA_WIDTH-1:0] activations [0:N-1];
    reg signed [W_WIDTH-1:0]    weights     [0:M-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  bias        [0:M-1];
    reg signed [ACC_WIDTH-1:0]  acc;

    typedef enum logic [2:0] {
        IDLE,
        LOAD_ACTIV,
        LOAD_WEIGHTS,
        LOAD_BIAS,
        COMPUTE,
        WRITE_OUT,
        NEXT,
        FINISH
    } state_t;

    state_t state;

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = mem_sel ? address : {ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (mem_sel && mem_w) ? data : {DATABUS_WIDTH{1'bZ}};

    reg stall; // 1-cycle gap between accesses

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            i <= 0; j <= 0;
            mem_w <= 0; mem_sel <= 0;
            done <= 0; out_valid <= 0;
            acc <= 0;
            address <= 0; data <= 0;
            stall <= 0;
        end else begin

            if (stall) begin
                // 1-cycle gap to avoid memory latching old address/data
                mem_sel <= 0;
                mem_w   <= 0;
                stall   <= 0;
            end else begin
                case(state)

                IDLE: begin
                    done <= 0;
                    out_valid <= 0;
                    mem_sel <= 0;
                    mem_w   <= 0;
                    if (start) begin
                        i <= 0;
                        address <= activ_base;
                        state <= LOAD_ACTIV;
                    end
                end

                LOAD_ACTIV: begin
                    mem_sel <= 1;
                    mem_w   <= 0;
                    if (ready) begin
                        activations[i] <= data_bus[DATA_WIDTH-1:0];
                        i <= i + 1;
                        address <= address + 1;
                        mem_sel <= 0;
                        stall <= 1; // 1-cycle pulse
                        if (i == N-1) begin
                            i <= 0; j <= 0;
                            address <= weight_base;
                            state <= LOAD_WEIGHTS;
                        end
                    end
                end

                LOAD_WEIGHTS: begin
                    mem_sel <= 1;
                    mem_w   <= 0;
                    if (ready) begin
                        weights[i][j] <= data_bus[W_WIDTH-1:0];
                        j <= j + 1;
                        address <= address + 1;
                        mem_sel <= 0;
                        stall <= 1;
                        if (i == M-1 && j == N-1) begin
                            i <= 0; j <= 0;
                            address <= bias_base;
                            state <= LOAD_BIAS;
                        end else if (j == N-1) begin
                            j <= 0; i <= i + 1;
                        end
                    end
                end

                LOAD_BIAS: begin
                    mem_sel <= 1;
                    mem_w   <= 0;
                    if (ready) begin
                        bias[i] <= data_bus[ACC_WIDTH-1:0];
                        i <= i + 1;
                        address <= address + 1;
                        mem_sel <= 0;
                        stall <= 1;
                        if (i == M-1) begin
                            i <= 0; j <= 0;
                            acc <= bias[0];
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    acc <= acc + activations[j] * weights[i][j];
                    if (j == N-1) begin
                        data <= {{(DATABUS_WIDTH-ACC_WIDTH){1'b0}}, acc};
                        address <= output_base + i;
                        state <= WRITE_OUT;
                        j <= 0;
                    end else begin
                        j <= j + 1;
                    end
                end

                WRITE_OUT: begin
                    mem_sel <= 1;
                    mem_w   <= 1;
                    if (ready) begin
                        mem_sel <= 0;
                        mem_w   <= 0;
                        stall   <= 1;
                        out_valid <= 1;
                        state <= NEXT;
                    end
                end

                NEXT: begin
                    out_valid <= 0;
                    if (i == M-1) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 1;
                        acc <= bias[i+1];
                        state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1;
                end

                endcase
            end
        end
    end

endmodule

