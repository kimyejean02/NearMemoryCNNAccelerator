module mac2_with_mem #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 8,
    parameter DATABUS_WIDTH  = 32
)(
    input  wire clk,
    input  wire rst,

    input  wire start,
    output reg  done,

    input  wire [ADDR_WIDTH-1:0] a_addr,
    input  wire [ADDR_WIDTH-1:0] kernel_addr,
    input  wire [ADDR_WIDTH-1:0] output_addr,

    // Memory interface
    output reg mem_w,
    output reg mem_sel,
    inout wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus
);

    // Internal registers to hold operands
    reg [DATA_WIDTH-1:0] a_val;
    reg [DATA_WIDTH-1:0] kernel_val;
    reg [DATA_WIDTH-1:0] result;

    typedef enum logic [2:0] {
        IDLE,
        READ_A,
        READ_KERNEL,
        COMPUTE,
        NEXT,
        FINISHED
    } state_t;

    state_t state;

    wire driving_mem;
    // drive address during read and write phases
    assign driving_mem = (state == READ_A) || (state == READ_KERNEL) || (state == NEXT);

    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = (driving_mem) ? address : {ADDR_WIDTH{1'bZ}};

    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (driving_mem && mem_w) ? data : {DATABUS_WIDTH{1'bZ}};

    initial begin
        state     <= IDLE;
        a_val     <= 0;
        kernel_val <= 0;
        result    <= 0;
        mem_w     <= 0;
        mem_sel   <= 0;
        address   <= 0;
        data      <= 0;
        done      <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            a_val     <= 0;
            kernel_val <= 0;
            result    <= 0;
            mem_w     <= 0;
            mem_sel   <= 0;
            address   <= 0;
            data      <= 0;
            done      <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // prepare to read 'a' from memory
                        address <= a_addr;
                        mem_w <= 0;      // read mode
                        mem_sel <= 1;    // select memory
                        state <= READ_A;
                    end
                end

                // Read first operand 'a' from memory
                READ_A: begin
                    a_val <= data_bus[DATA_WIDTH-1:0];
                    
                    // prepare to read kernel
                    address <= kernel_addr;
                    state <= READ_KERNEL;
                end

                // Read second operand 'kernel' from memory
                READ_KERNEL: begin
                    kernel_val <= data_bus[DATA_WIDTH-1:0];
                    
                    // next state: compute (no memory access needed)
                    state <= COMPUTE;
                end

                // Compute MAC: extract 4 bytes from each operand, multiply, and sum
                COMPUTE: begin
                    // Use combinational MAC2 logic inline:
                    // a_val: [a3, a2, a1, a0]
                    // kernel_val: [k3, k2, k1, k0]
                    // result = (a0*k0) + (a1*k1) + (a2*k2) + (a3*k3)
                    data <= (a_val[7:0] * kernel_val[7:0]) +
                              (a_val[15:8] * kernel_val[15:8]) +
                              (a_val[23:16] * kernel_val[23:16]) +
                              (a_val[31:24] * kernel_val[31:24]);

                    // prepare to write result
                    address <= output_addr;
                    mem_w <= 1;      // will be set to 1 in WRITE
                    mem_sel <= 1;    // switch to write semantics
                    state <= NEXT;
                end

                // Write result back to memory
                NEXT: begin
                    // drive result onto data_bus
                    mem_w <= 0;      // assert write enable
                    mem_sel <= 0;    // write mode (follow convention)
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1;
                    mem_w <= 0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
