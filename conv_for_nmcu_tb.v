`timescale 1ns/1ps

module conv_for_nmcu_tb;

    localparam MAX_INPUT_DIM  = 15;
    localparam MAX_KERNEL_DIM = 7;
    localparam DATABUS_WIDTH  = 32;

    // DUT IO
    reg clk = 0;
    reg rst = 0;

    reg start;
    wire done;

    reg [$clog2(MAX_INPUT_DIM):0]  input_width;
    reg [$clog2(MAX_INPUT_DIM):0]  input_height;
    reg [$clog2(MAX_KERNEL_DIM):0] kernel_size;

    reg  [DATABUS_WIDTH-1:0] local_kernel      [0:MAX_KERNEL_DIM-1][0:MAX_KERNEL_DIM-1];
    reg  [DATABUS_WIDTH-1:0] local_activation_in  [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1];
    wire signed [DATABUS_WIDTH-1:0] local_activation_out [0:MAX_INPUT_DIM-1][0:MAX_INPUT_DIM-1];

    // Clock
    always #5 clk = ~clk;

    // Instantiate DUT
    conv_for_nmcu #(
        .MAX_INPUT_DIM(MAX_INPUT_DIM),
        .MAX_KERNEL_DIM(MAX_KERNEL_DIM),
        .DATABUS_WIDTH(DATABUS_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .input_width(input_width),
        .input_height(input_height),
        .kernel_size(kernel_size),
        .local_kernel(local_kernel),
        .local_activation_in(local_activation_in),
        .local_activation_out(local_activation_out)
    );

    // Test
    integer i, j;

    initial begin
        // Initialize all memories
        for (i = 0; i < MAX_INPUT_DIM; i++) begin
            for (j = 0; j < MAX_INPUT_DIM; j++) begin
                local_activation_in[i][j] = 0;
            end
        end

        for (i = 0; i < MAX_KERNEL_DIM; i++) begin
            for (j = 0; j < MAX_KERNEL_DIM; j++) begin
                local_kernel[i][j] = 0;
            end
        end

        // Example dimensions
        input_width  = 5;
        input_height = 5;
        kernel_size  = 3;

        // Example activation map
        // Fill activation with simple ramp so it’s easy to verify
        for (i = 0; i < 5; i++) begin
            for (j = 0; j < 5; j++) begin
                local_activation_in[i][j] = i*5 + j;
            end
        end

        // Example kernel (3×3 identity-like)
        local_kernel[0][0] = 1; local_kernel[0][1] = 0; local_kernel[0][2] = -1;
        local_kernel[1][0] = 1; local_kernel[1][1] = 0; local_kernel[1][2] = -1;
        local_kernel[2][0] = 1; local_kernel[2][1] = 0; local_kernel[2][2] = -1;

        // Reset sequence
        rst   = 1;
        start = 0;
        #20;
        rst = 0;
        #20;

        // Start DUT
        start = 1;
        #10;
        start = 0;

        // Wait until done
        wait(done == 1);

        // Print output
        $display("\nConvolution result:");
        for (i = 0; i < input_height - kernel_size + 1; i++) begin
            for (j = 0; j < input_width - kernel_size + 1; j++) begin
                $write("%0d ", local_activation_out[i][j]);
            end
            $write("\n");
        end

        #20;
        $finish;
    end

endmodule
