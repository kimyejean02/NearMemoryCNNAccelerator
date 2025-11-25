`timescale 1ns/1ps

module tb_convolution;

  reg clk;
  reg rst;
  reg start;
 
  reg signed [7:0] matrix [0:3][0:3];
  reg signed [7:0] kernel [0:1][0:1];

  wire done;
  wire signed [31:0] out_pixel;
  wire out_valid;

  convolution dut(
    .clk(clk),
    .rst(rst),
    .start(start),
    .done(done),
    .matrix(matrix),
    .kernel(kernel),
    .out_pixel(out_pixel),
    .out_valid(out_valid)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    integer oy = 0;
    integer ox = 0;

    rst = 1;
    start = 0;

    repeat(4) @(posedge clk);
    rst = 0;

    matrix = '{
      '{1, 2, 3, 4},
      '{5, 6, 7, 8},
      '{9, 10, 11, 12},
      '{13, 14, 15, 16}
    };

    kernel = '{
      '{1, 0},
      '{0, -1}
    };

    // Start convolution
    @(posedge clk);
    start <= 1;
    @(posedge clk);
    start <= 0;

    // Monitor results
    while (!done) begin
      @(posedge clk);
      if (out_valid) begin
        $display("Output (%0d,%0d) = %0d", oy, ox, out_pixel);
        ox++;

        // Move coords in raster order
        if (ox == 3) begin
          ox = 0;
          oy++;
        end
      end
    end

    $display("Convolution finished!");
    $finish;
  end
endmodule
