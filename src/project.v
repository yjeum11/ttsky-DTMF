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

  reg [15:0] res;
  assign uo_out = res[7:0];

  assign uio_oe = '0;
  assign uio_out = '0;

  serial_mult #(8) my_mult (
      .clk(clk), .rst_n(rst_n),
      .A(ui_in), .B(uio_in),
      .AB_valid(1'b1),
      .AB_ready(),
      .Q(res),
      .Q_valid()
  );

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};

endmodule

