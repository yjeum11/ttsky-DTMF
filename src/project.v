/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`define ROW1_COEFF 32607
`define FRAC_BITS 10
`define BLOCK_SIZE 512

module tt_um_yjeum11 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  reg [7:0] sample;
  reg sample_valid, sample_ready;
  reg [10:0] coeff;
  reg signed [23:0] s_prev, s_prev2;
  reg valid;

  goertzel_iir my_iir (
    .clk(clk), .rst_n(rst_n),
    .sample(sample),
    .sample_valid(sample_valid),
    .sample_ready(sample_ready),
    .coeff(coeff),
    .s_prev(s_prev), .s_prev2(s_prev2),
    .valid(valid)
  );

  assign sample = ui_in;
  assign uo_out = s_prev[7:0];
  assign uio_out = s_prev[15:8];
  assign uio_oe = '1;
  assign coeff = '1;
  assign sample_valid = '1;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};

endmodule

