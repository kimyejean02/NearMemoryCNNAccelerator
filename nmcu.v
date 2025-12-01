module nmcu #(
    parameter ADDR_WIDTH = 16,
    parameter DATABUS_WIDTH = 32,
    parameter MAX_DESCS = 8,
    parameter MAX_INPUT_DIM=15,
    parameter MAX_KERNEL_DIM=7,
    parameter MAX_CNNS=2,
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

    // mem interface
    output reg mem_w,
    output reg mem_sel,

    inout wire [ADDR_WIDTH-1:0] address_bus,
    inout wire [DATABUS_WIDTH-1:0] data_bus,
    input wire ready
);
    // Functions to be done by NMCU module:
    // - Convolution (MAC)
    // - Maxpool (fixed size)
    // - ReLU
    
    // To specify layer parameters and order, a set of 32-bit
    // descriptors will be laid out in memory and loaded
    // in at start of operation

    // Descriptor format:
    // - layer type [1:0]: NOP, CONV, MAXP, RELU
    // - layer input width [5:2] (0 - 15)
    // - layer input height [9:6] (0 - 15)
    // - kernel size [12:10] (0 - 7) (only for conv)
    // - kernel_addr [31:16] (16 bit address) (only for conv)

    // Stages:
    // - read in all descriptors from global mem
    // - read in all relevant inputs to local mem
    // - run loop over each descriptor, read in all relevant kernels 
    // - run loop over each descriptor, doing each operation
    // - if output dim is one, stop
    // - if we run out of descriptors, stop
    // - output to output address, keeping in mind the output dimensions

    // If this is only processing one 'cone' of the matrix,
    // we need to know the full input and output widths to properly
    // extract the matrices we need to process (since they won't
    // be in row-major order)

    typedef enum logic [2:0] {
        IDLE,
        READ_DESCS,
        READ_INPUTS,
        READ_KERNELS,
        NOP,
        CONV,
        MAXP,
        RELU,
    } state_t;

    state_t state;
    
    // descriptors and curr_desc
    reg [31:0] descriptors [0:MAX_DESCS-1];
    reg [31:0] curr_desc;
    wire [1:0] layer_type = curr_desc[1:0];
    wire [3:0] inp_width = curr_desc[5:2];
    wire [3:0] inp_height = curr_desc[9:6];
    wire [2:0] kernel_size = curr_desc[12:10];
    wire [15:0] kernel_addr = curr_desc[31:16];

    // descriptor iterator
    reg [$clog2(MAX_DESCS)-1:0] i;

    // stall reg for memory read
    reg stall;

    // address reg
    reg [ADDR_WIDTH-1:0] address;
    assign address_bus = mem_sel ? address : {ADDR_WIDTH{1'bZ}};

    // local inputs
    reg [DATABUS_WIDTH-1:0] local_kernels [0:MAX_DESCS-1][0:MAX_KERNEL_DIM-1][0:MAX_KERNEL_DIM-1];
    reg [DATABUS_WIDTH-1:0] local_activations [0:MAX_DESCS-1][0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1];

    // conv processing element
    reg conv_pe_rst;
    reg conv_pe_start;
    wire conv_pe_done;
    wire [$clog2(MAX_INPUT_DIM)-1:0] conv_pe_input_width;
    wire [$clog2(MAX_INPUT_DIM)-1:0] conv_pe_input_height;
    wire [$clog2(MAX_INPUT_DIM)-1:0] conv_pe_kernel_size;
    wire [DATABUS_WIDTH-1:0] conv_pe_local_kernel [0:MAX_KERNEL_DIM-1][0:MAX_KERNEL_DIM-1];
    wire [DATABUS_WIDTH-1:0] conv_pe_local_activation_in [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1];
    wire [DATABUS_WIDTH-1:0] conv_pe_local_activation_out [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1];

    conv_for_nmcu #(
        .MAX_INPUT_DIM(MAX_INPUT_DIM),
        .MAX_KERNEL_DIM(MAX_KERNEL_DIM),
        .DATABUS_WIDTH(DATABUS_WIDTH)
    ) conv_pe (
        .clk(clk),
        .rst(conv_pe_rst),
        .start(conv_pe_start),
        .done(conv_pe_done),
        .input_width(conv_pe_input_width),
        .input_height(conv_pe_input_height),
        .kernel_size(conv_pe_kernel_size),
        .local_kernel(conv_pe_local_kernel),
        .local_activation_in(conv_pe_local_activation_in),
        .local_activation_out(conv_pe_local_activation_out)
    );

    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            state <= IDLE;
            curr_desc <= 0;
            done <= 0;
            i <= 0;
       end else begin
            if (stall) begin 
                mem_sel <= 0;
                mem_w <= 0;
                stall <= 0;
            end else begin
                case (state)
                    IDLE: begin 
                        state <= IDLE;
                        curr_desc <= 0;
                        done <= 0;
                        i <= 0;
                        if (start) begin 
                            i <= 0;
                            address <= nmcu_desc;
                            state <= READ_DESCS;
                        end
                    end

                    READ_DESCS: begin 
                        mem_sel <= 1;
                        mem_w <= 0;
                        if (ready) begin 
                            descriptors[i] <= data_bus;
                            stall <= 1;
                            if (i == MAX_DESCS-1) begin
                                curr_desc <= descriptors[0];
                                state <= READ_INPUTS;
                                address <= input_addr;
                            end else begin
                                address <= address + 1;
                                i <= i + 1;
                            end
                        end
                    end

                    READ_INPUTS: begin 
                        mem_sel <= 1;
                        mem_w <= 0;
                        if (ready) begin
                            local_activations[0][i][j] <= data_bus;
                            stall <= 1;

                            if (i == inp_height - 1 && j == inp_width - 1) begin
                                i <= 0;
                                j <= 0;

                                mem_sel <= 0;
                                mem_w <= 0;

                                state <= READ_KERNELS;
                            end else if (j == inp_width - 1) begin
                                i <= i+1;
                                j <= 0;
                                
                                // go back to first elem in row, then go to
                                // next row entirely
                                address <= address - j + full_input_width;
                            end else begin 
                                j <= j+1;
                                address <= address + 1;
                            end
                        end
                    end

                    READ_KERNELS: begin 
                        
                    end

                    INIT: begin 
                    end

                    NOP: begin
                    end

                    CONV: begin 

                    end

                    MAXP: begin 
                    end

                    RELU: begin 
                    end
                endcase
            end
        end
    end

endmodule
