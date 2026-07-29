`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

    // reg signed [7:0] sample;
    // reg signed [10:0] coeff;
    // reg sample_valid;
    // reg sample_ready;
    // reg start;
    // reg ready, power_valid;
    // reg signed [47:0] power;

    // power_calculate #(.BLOCK_SIZE(512)) my_power (
    //     .clk, .rst_n,
    //     .sample,
    //     .coeff(11'd1018),
    //     .sample_valid,
    //     .sample_ready,
    //     .start,
    //     .ready,
    //     .power_valid,
    //     .power
    // );


  // reg AB_valid, Q_valid, AB_ready;
  // reg [15:0] Q;
  // reg [7:0] A, B;

  // serial_mult #(8) my_mult (
  //     .clk (clk),
  //     .rst_n (rst_n),
  //     .A(A),
  //     .B(B),
  //     .AB_valid(AB_valid),
  //     .AB_ready(AB_ready),
  //     .Q(Q),
  //     .Q_valid(Q_valid)
  // );

  // reg [7:0] sample;
  // reg sample_valid, sample_ready;
  // reg [10:0] coeff;
  // reg signed [6:0][23:0] s_prev, s_prev2;
  // reg valid;

  // goertzel_iir my_iir (
  //   .clk(clk), .rst_n(rst_n),
  //   .sample(sample),
  //   .sample_valid(sample_valid),
  //   .sample_ready(sample_ready),
  //   .s_prev(s_prev), .s_prev2(s_prev2),
  //   .valid(valid)
  // );

  // Replace tt_um_example with your module name:
  tt_um_yjeum11 user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );


endmodule
