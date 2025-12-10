module nmcu_ctrl #(
    parameter NUM_NMCUS = 4,
    parameter ADDR_WIDTH = 16,
    parameter DATABUS_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire start,
    output reg done,

    input wire [ADDR_WIDTH-1:0] nmcu_desc, // memory loc containing full description of NMCU network
    input wire [ADDR_WIDTH-1:0] input_addr, // beginning input address
    input wire [ADDR_WIDTH-1:0] output_addr, // final output address
    input wire [$clog2(MAX_INPUT_DIM):0] full_input_width,
    input wire [$clog2(MAX_INPUT_DIM):0] full_input_height,
    input wire [$clog2(MAX_INPUT_DIM):0] full_output_width,
    input wire [$clog2(MAX_INPUT_DIM):0] full_output_height,

    output reg [NUM_NMCUS-1:0] nmcu_start,
    input wire [3:0] nmcu_state [NUM_NMCUS-1:0],
    input wire [NUM_NMCUS-1:0] nmcu_mem_sel,
    input wire [NUM_NMCUS-1:0] nmcu_mem_w,
    output reg [NUM_NMCUS-1:0] nmcu_mem_ready,
    output reg [ADDR_WIDTH-1:0] nmcu_addr_bus,
    inout wire [DATABUS_WIDTH-1:0] nmcu_data_bus [NUM_NMCUS-1:0],

    // mem interface
    output reg mem_w,
    output reg mem_sel,
    input wire ready,
    output wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus
);

    typedef enum logic [2:0] {
        IDLE,
        READ_DESCS,
        READ_KERNELS,
        READ_INPUTS,
        WRITE,
        FINISHED
    } state_t;
    
    state_t state;

    // descriptor stuff
    reg [31:0] descriptors [0:MAX_DESCS-1];
    reg [$clog2(MAX_DESCS):0] desc_iter;

    wire [31:0] curr_desc = descriptors[desc_iter];
    wire [1:0] layer_type = curr_desc[1:0];
    wire [3:0] inp_width = curr_desc[5:2];
    wire [3:0] inp_height = curr_desc[9:6];
    wire [2:0] kernel_size = curr_desc[12:10];
    wire [15:0] kernel_addr = curr_desc[31:16];

    wire [31:0] next_desc = descriptors[desc_iter+1];
    wire [1:0] next_layer_type = next_desc[1:0];
    wire [3:0] next_inp_width = next_desc[5:2];
    wire [3:0] next_inp_height = next_desc[9:6];
    wire [2:0] next_kernel_size = next_desc[12:10];
    wire [15:0] next_kernel_addr = next_desc[31:16];

    // input iterators
    reg [$clog2(MAX_INPUT_DIM)-1:0] x, y;
    // kernel iterators
    reg [$clog2(MAX_KERNEL_DIM)-1:0] i, j;

    // stall reg for memory read
    reg mem_stall;

    // address reg
    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = mem_sel ? address : {ADDR_WIDTH{1'bZ}};

    // data reg
    reg [DATABUS_WIDTH-1:0] data;
    assign data_bus = (mem_sel && mem_w) ? data : {DATABUS_WIDTH{1'bZ}};
    
    genvar i;
    generate
        for (i = 0; i < NUM_NMCUS; i = i + 1) begin
            assign nmcu_data_bus[i] = (nmcu_mem_sel[i] && !nmcu_mem_w[i] && nmcu_mem_ready[i]) ? data_bus : 'z;
        end
    endgenerate

    reg [$clog2(NUM_NMCUS)-1:0] nmcu_ind;

    initial begin 
        state <= IDLE;
        desc_iter <= 0;
        x <= 0;
        y <= 0;
        i <= 0;
        j <= 0;
        mem_sel <= 0;
        mem_w <= 0;
        mem_stall <= 0;
        address <= 0;
        data <= 0;
        done <= 0;
        nmcu_start <= '0;
        nmcu_mem_ready <= '0;
        nmcu_addr_bus <= '0;
        nmcu_ind <= 0;
    end

    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            state <= IDLE;
            desc_iter <= 0;
            x <= 0;
            y <= 0;
            i <= 0;
            j <= 0;
            mem_sel <= 0;
            mem_w <= 0;
            mem_stall <= 0;
            address <= 0;
            data <= 0;
            done <= 0;
            nmcu_start <= '0;
            nmcu_mem_ready <= '0;
            nmcu_addr_bus <= '0;
            nmcu_ind <= 0;
       end else begin
            if (mem_stall) begin 
                mem_sel <= 0;
                mem_w <= 0;
                mem_stall <= 0;
            end else begin
                case (state)
                    IDLE: begin 
                        state <= IDLE;
                        done <= 0;
                        i <= 0;
                        if (start) begin 
                            i <= 0;
                            address <= nmcu_desc;
                            state <= READ_DESCS;
                            nmcu_start <= '1;
                        end
                    end

                    READ_DESCS: begin
                        if (nmcu_state[0] == READ_DESCS) begin
                            mem_sel <= 1;
                            mem_w <= 0;
                            if (ready) begin 
                                nmcu_mem_ready <= '1;
                                nmcu_addr_bus <= address;
                                mem_stall <= 1;
                                if (desc_iter == MAX_DESCS-1 || data_bus[1:0] == NOP_TYPE) begin
                                    state <= READ_KERNELS;
                                    desc_iter <= 0;
                                    address <= kernel_addr;
                                end else begin
                                    address <= address + 1;
                                    desc_iter <= desc_iter + 1;
                                end
                            end
                        end
                    end

                    READ_KERNELS: begin 
                        if (nmcu_state[0] == READ_KERNELS) begin
                            if (layer_type == CONV_TYPE) begin 
                                // if conv, load kernel
                                mem_sel <= 1;
                                mem_w <= 0;
                                
                                if (ready) begin
                                    nmcu_mem_ready <= '1;
                                    nmcu_addr_bus <= address;
                                    mem_stall <= 1;

                                    if (i == kernel_size - 1 && j == kernel_size - 1) begin 
                                        i <= 0;
                                        j <= 0;

                                        mem_sel <= 0;
                                        mem_w <= 0;
                                        
                                        desc_iter <= desc_iter + 1;
                                    end else if (j == kernel_size - 1) begin 
                                        i <= i + 1;
                                        j <= 0;
                                        // we assume the kernel is stored in row
                                        // major order and since we're loading in
                                        // the whole thing we don't have to do any
                                        // funky stuff
                                        address <= address + 1;
                                    end else begin 
                                        j <= j + 1;
                                        address <= address + 1;
                                    end
                                end
                            end

                            if (layer_type == NOP_TYPE || desc_iter == MAX_DESCS-1) begin 
                                // end iteration
                                desc_iter <= 0;
                                mem_sel <= 0;
                                mem_w <= 0;
                                x <= 0;
                                y <= 0;
                                state <= READ_INPUTS;
                                address <= input_addr;
                            end else if (layer_type != CONV_TYPE) begin 
                                desc_iter <= desc_iter + 1;
                                address <= descriptors[desc_iter+1][31:16]; // next kernel address
                            end
                        end
                    end

                    READ_INPUTS: begin
                        if (nmcu_state[0] == READ_INPUTS) begin
                            mem_sel <= 1;
                            mem_w <= 0;
                            if (ready) begin
                                nmcu_mem_ready <= '1;
                                nmcu_addr_bus <= address;
                                mem_stall <= 1;

                                if (x == full_input_height - 1 && y == full_input_width - 1) begin
                                    x <= 0;
                                    y <= 0;

                                    mem_sel <= 0;
                                    mem_w <= 0;

                                    state <= WRITE;
                                end else if (y == full_input_width - 1) begin
                                    x <= x + 1;
                                    y <= 0;
                                    
                                    // go back to first elem in row, then go to
                                    // next row entirely
                                    address <= address + 1;
                                end else begin 
                                    y <= y+1;
                                    address <= address + 1;
                                end
                            end
                        end
                    end

                    WRITE: begin
                        // writeback here
                        if (nmcu_mem_sel[nmcu_ind] && nmcu_mem_w[nmcu_ind] && !nmcu_mem_ready[nmcu_ind]) begin // unserviced request
                            mem_w <= 1;
                            mem_sel <= 1;
                            address  <= output_addr + nmcu_ind;
                            data <= nmcu_data_bus[nmcu_ind];
                            nmcu_mem_ready[nmcu_ind] <= ready;
                            if (ready) begin 
                                mem_stall <= 1;
                            end
                        end else begin 
                            nmcu_mem_ready[nmcu_ind] <= 0;
                            nmcu_ind <= (nmcu_ind + 1) % NUM_NMCUS;
                        end
                    end

                    FINISHED: begin 
                        mem_sel <= 0;
                        mem_w <= 0;
                        done <= 1;
                    end
                endcase
            end
        end
    end
endmodule
