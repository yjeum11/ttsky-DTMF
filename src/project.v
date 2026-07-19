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

// module goertzel_core (
//     input wire clk, rst_n,
//     input wire [7:0] i_sample,
//     input wire i_sample_valid,
//     output wire o_sample_ready
// );
// 
// reg [7:0] sample;
// reg [$clog2(BLOCK_SIZE)-1:0] sample_counter, next_sample_counter;
// wire block_done;
// 
// reg [23:0] s_prev, s_prev2;
// reg [23:0] row1_coeff;
// 
// // every cycle, 2 * (s_prev * ROW1_COEFF) >> frac_bits
// 
// assign block_done = sample_counter == 511;
// 
// always @* begin
//     if (~block_done) begin
//         next_sample_counter = sample_counter + 1;
//     end else begin
//         next_sample_counter = '0;
//     end
// end
// 
// always @(posedge clk) begin
//     if (~rst_n) begin
//         sample <= '0;
//         row1_coeff <= 24'd1019
//     end else begin
//         if (i_sample_valid) begin
//             sample <= i_sample;
//             sample_counter <= next_sample_counter;
//         end
//     end
// end
// 
// endmodule
