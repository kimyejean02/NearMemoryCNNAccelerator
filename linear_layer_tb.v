module linear_layer_tb;

	localparam DATA_WIDTH = 8;
	localparam W_WIDTH    = 8;
	localparam ACC_WIDTH  = 32;
	localparam N = 4;
	localparam M = 3;

	reg clk;
	reg rst;
	reg start;

	reg signed [DATA_WIDTH-1:0]	activations [0:N-1];
	reg signed [W_WIDTH-1:0]	weights [0:M-1][0:N-1];
	reg signed [ACC_WIDTH-1:0]	bias [0:M-1];

	wire signed [ACC_WIDTH-1:0]	out;
	wire				out_valid;
	wire				done;

	linear_layer #(
		.DATA_WIDTH(DATA_WIDTH),
		.W_WIDTH(W_WIDTH),
		.ACC_WIDTH(ACC_WIDTH),
		.N(N),
		.M(M)
	) dut (
		.clk(clk),
		.rst(rst),
		.start(start),
		.activations(activations),
		.weights(weights),
		.bias(bias),
		.out(out),
		.out_valid(out_valid),
		.done(done)
	);

	// Clock generation (100 MHz)
	always begin
		#5 clk = ~clk;
	end

	task apply_input(
		input reg signed [DATA_WIDTH-1:0]  act0,
		input reg signed [DATA_WIDTH-1:0]  act1,
		input reg signed [DATA_WIDTH-1:0]  act2,
		input reg signed [DATA_WIDTH-1:0]  act3,

		input reg signed [W_WIDTH-1:0] w00, input reg signed [W_WIDTH-1:0] w01,
		input reg signed [W_WIDTH-1:0] w02, input reg signed [W_WIDTH-1:0] w03,
		input reg signed [W_WIDTH-1:0] w10, input reg signed [W_WIDTH-1:0] w11,
		input reg signed [W_WIDTH-1:0] w12, input reg signed [W_WIDTH-1:0] w13,
		input reg signed [W_WIDTH-1:0] w20, input reg signed [W_WIDTH-1:0] w21,
		input reg signed [W_WIDTH-1:0] w22, input reg signed [W_WIDTH-1:0] w23,

		input reg signed [ACC_WIDTH-1:0] b0,
		input reg signed [ACC_WIDTH-1:0] b1,
		input reg signed [ACC_WIDTH-1:0] b2
	);
	begin
		// Load activations
		activations[0] = act0;
		activations[1] = act1;
		activations[2] = act2;
		activations[3] = act3;

		// Load weights
		weights[0][0] = w00; weights[0][1] = w01; weights[0][2] = w02; weights[0][3] = w03;
		weights[1][0] = w10; weights[1][1] = w11; weights[1][2] = w12; weights[1][3] = w13;
		weights[2][0] = w20; weights[2][1] = w21; weights[2][2] = w22; weights[2][3] = w23;

		// Load biases
		bias[0] = b0;
		bias[1] = b1;
		bias[2] = b2;

		// Trigger start pulse
		start = 1;
		#10;
		start = 0;

		// Wait for out_valid pulses
		@(posedge clk);
		while (!done) begin
			@(posedge clk);
				if (out_valid) begin
					$display("Output = %0d", out);
				end
		end
	end
	endtask

	initial begin
		clk = 0;
		rst = 1;
		start = 0;

		#20 rst = 0;

		$display("=== LINEAR LAYER TEST ===");

		apply_input(
			1, 2, -1, 3,	// activations

			1, 1, 1, 1,	// weights row 0
			2, 2, 2, 2,	// weights row 1
			3, 3, 3, 3,	// weights row 2

			10, 20, 30	// biases
		);
		// Should return [15, 30, 45]

                apply_input(
                        1, 2, -1, 3,    // activations

                        1, 0, 0, 0,     // weights row 0
                        0, 1, 0, 0,     // weights row 1
                        0, 0, 1, 0,     // weights row 2

                        0, 0, 0      // biases
                );
		// Should return [1, 2, 3]

                apply_input(
                        5, -5, 10, -10,    // activations

                        1, 1, 1, 1,     // weights row 0
                        1, 1, 1, 1,     // weights row 1
                        1, 1, 1, 1,     // weights row 2

                        3, 4, 5      // biases
                );


		$display("=== DONE ===");
		$finish;
	end
	
endmodule

