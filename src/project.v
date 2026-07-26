/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_yjeum11 #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 24,
) (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire sample_ready;
    assign uio_out[1] = sample_ready;
    reg signed [3:0][10:0] row_coeffs;
    reg signed [2:0][10:0] col_coeffs;
    reg [2:0] row_idx, col_idx;
    reg signed [23:0] s_prev, s_prev2;
    reg signed [10:0] coeff;
    reg iir_valid;



endmodule

