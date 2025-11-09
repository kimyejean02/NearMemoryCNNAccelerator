module cu_controller #(
    parameter activation_width = 16,
    parameter weight_width = 8,
    parameter accumulator_width = 40,
    parameter array_x = 4,
    parameter array_y = 4,
    parameter tile_x = 8,
    parameter tile_y = 8
)(
    input wire clk,
    input wire rstn,
    input wire start,

    // configuration
    input wire [15:0] in_base_addr,
    input wire [15:0] weight_base_addr,
    input wire [15:0] out_base_addr,
    input wire [7:0] stride,
    input wire [7:0] kernel_size,
    input wire [15:0] channels_in,
    input wire [15:0] channels_out,

    // memory read
    output wire mem_read_req,
    output wire [31:0] mem_read_addr,
    input wire mem_read_valid,
    input wire [31:0] mem_read_data,

    // memory write
    output wire mem_write_req,
    output wire [31:0] mem_write_addr,
    output wire [31:0] mem_write_data,
    input wire mem_write_ack,

    // PE array control
    output wire [activation_width-1:0] activations,
    output wire [weight_width-1:0] weights [0:array_x-1][0:array_y-1],
    output wire enable,
    output wire clear,
    input wire [accumulator_width-1:0] acc [0:array_x-1][0:array_y-1],
    output wire done
    );

    // FSM states
    parameter IDLE=2'b00, LOAD_W=2'b01, COMPUTE=2'b10, WRITEBACK=2'b11;
    logic [1:0] state, next_state;

    // FSM sequential
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            done <= 0;
            mem_read_req <= 0;
            mem_write_req <= 0;
            enable <= 0;
            clear <= 0;
            activations <= '0;
        end
        else begin
            state <= next_state;
            enable <= 0;
            mem_read_req <= 0;
            mem_write_req <= 0;
            clear <= 0;
            done <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= LOAD_W;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                LOAD_W: begin
                    mem_read_req <= 1;
                    mem_read_addr <= weight_base_addr;
                    next_state <= (mem_read_valid ? COMPUTE : LOAD_W);
                end
                COMPUTE: begin
                    mem_read_req <= 1;
                    mem_read_addr <= in_base_addr;
                    if (mem_read_valid) begin
                        activations <= mem_read_data[activation_width-1:0];
                        // enable PEs and compute next state
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                WRITEBACK: begin
                    // read from PEs and write to memory
                    next_state <= IDLE;
                    done <= 1;
                end
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
endmodule