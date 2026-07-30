/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_yjeum11 #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 11,
    parameter BLOCK_SIZE = 8,
    parameter BLOCK_SIZE_BITS = $clog2(BLOCK_SIZE)
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

reg [3:0] row_idx, col_idx, s_prev_idx, max_row_idx, max_col_idx;
reg row_idx_clr, col_idx_clr, row_idx_inc, col_idx_inc;
reg max_row_idx_load, max_col_idx_load, max_row_idx_clr, max_col_idx_clr;

reg stop_samples, row_phase, col_phase, power_phase;

wire power_start;
wire power_ready;
reg power_valid;
reg max_power_clr, max_power_load;
reg new_max;
reg [2*24-1:0] power, max_power;


// TODO: assign I/O pins to these
reg sample_ready, sample_valid;
reg valid;
assign uio_out[0] = sample_ready;
assign sample_valid = uio_in[1];
assign uo_out = {max_row_idx, max_col_idx};
assign uio_out[1] = valid;

reg [BLOCK_SIZE_BITS:0] blk_counter;
reg blk_counter_dec, blk_counter_load, blk_counter_0;
assign blk_counter_0 = blk_counter == 0;

always @(posedge clk) begin
    if (~rst_n)
        blk_counter <= BLOCK_SIZE;
    else begin
        if (blk_counter_load)
            blk_counter <= BLOCK_SIZE;
        else if (blk_counter_dec)
            blk_counter <= blk_counter - 1;
    end
end

assign s_prev_idx = (row_phase) ? row_idx : 
                    (col_phase) ? col_idx + 4 : '0;

assign max_row_idx_load = new_max & row_phase;
assign max_col_idx_load = new_max & col_phase;

always @(posedge clk) begin
    if (~rst_n)
        row_idx <= '0;
    else begin
        if (row_idx_clr)
            row_idx <= '0;
        else if (row_idx_inc)
            row_idx <= row_idx + 1;
    end
end

always @(posedge clk) begin
    if (~rst_n)
        col_idx <= '0;
    else begin
        if (col_idx_clr)
            col_idx <= '0;
        else if (col_idx_inc)
            col_idx <= col_idx + 1;
    end
end

always @(posedge clk) begin
    if (~rst_n)
        max_row_idx <= '0;
    else begin
        if (max_row_idx_clr)
            max_row_idx <= '0;
        else if (max_row_idx_load)
            max_row_idx <= row_idx;
    end
end

always @(posedge clk) begin
    if (~rst_n)
        max_col_idx <= '0;
    else begin
        if (max_col_idx_clr)
            max_col_idx <= '0;
        else if (max_col_idx_load)
            max_col_idx <= col_idx;
    end
end

reg iir_sample_ready, iir_valid;
reg [3:0] iir_coeff_idx;
reg [10:0] coeff;

reg [7*24-1:0] s_prev, s_prev2;

goertzel_iir iir (
    .clk, .rst_n,
    .sample(ui_in),
    .sample_valid(sample_valid),
    .sample_ready(iir_sample_ready),
    // Coefficient cos(omega_0) given in Q1.10 format
    .coeff_idx(iir_coeff_idx),
    .coeff(coeff),
    .s_prev, .s_prev2,
    .valid(iir_valid)
);

assign new_max = power_valid & (power > max_power);

always @(posedge clk) begin
    if (~rst_n)
        max_power <= '0;
    else begin
        if (max_power_clr)
            max_power <= '0;
        else if (max_power_load)
            max_power <= power;
    end
end

power_calculate pow (
    .clk, .rst_n,
    .s_prev(s_prev[s_prev_idx * 24 +: 24]),
    .s_prev2(s_prev2[s_prev_idx * 24 +: 24]),
    .coeff(coeff),
    .start(power_start),
    .ready(power_ready), .power_valid,
    .power
);

reg [3:0] coeff_idx;
assign coeff_idx = (power_phase) ? s_prev_idx : iir_coeff_idx;

coeff_ram coefficients (.idx(coeff_idx), .coeff);

reg [2:0] state, next_state;

localparam STATE_RESET = 3'd0;
localparam STATE_ROW0  = 3'd1;
localparam STATE_ROW1  = 3'd2;
localparam STATE_COL0  = 3'd3;
localparam STATE_COL1  = 3'd4;
localparam STATE_OUT   = 3'd5;

assign power_phase = row_phase | col_phase;

assign sample_ready = iir_sample_ready & ~stop_samples;

always @* begin
    next_state = state;
    case (state)
        STATE_RESET: begin
            if (blk_counter_0 & iir_valid) begin
                next_state = STATE_ROW0;
            end
        end
        STATE_ROW0: begin
            if (power_ready & (row_idx != 3)) begin
                next_state = STATE_ROW1;
            end else if (power_ready & (row_idx == 3)) begin
                next_state = STATE_COL0;
            end
        end
        STATE_ROW1: begin
            if (power_valid) begin
                next_state = STATE_ROW0;
            end
        end
        STATE_COL0: begin
            if (power_ready & (col_idx != 2)) begin
                next_state = STATE_COL1;
            end else if (power_ready & (col_idx == 2)) begin
                next_state = STATE_OUT;
            end
        end
        STATE_COL1: begin
            if (power_valid) begin
                next_state = STATE_COL0;
            end
        end
        STATE_OUT: begin
            next_state = STATE_RESET;
        end
    endcase

end

assign power_start = (state == STATE_ROW0) | (state == STATE_COL0);

always @* begin
    stop_samples = 1'b0;
    blk_counter_dec = 1'b0;
    blk_counter_load = 1'b0;
    row_phase = 1'b0;
    col_phase = 1'b0;
    // power_start = 1'b0;
    row_idx_inc = 1'b0;
    col_idx_inc = 1'b0;
    row_idx_clr = 1'b0;
    col_idx_clr = 1'b0;
    max_row_idx_clr = 1'b0;
    max_col_idx_clr = 1'b0;
    valid = 1'b0;
    case (state)
        STATE_RESET: begin
            // if (sample_ready & sample_valid) begin
            //     blk_counter_dec = 1'b1;
            // end
            blk_counter_dec = sample_ready & sample_valid;
        end
        STATE_ROW0: begin
            stop_samples = 1'b1;
            row_phase = 1'b1;
            // power_start = 1'b1;
            // if (power_ready) begin
            //     power_start = 1'b1;
            // end
        end
        STATE_ROW1: begin
            stop_samples = 1'b1;
            row_phase = 1'b1;
            // if (power_valid) begin
            //     row_idx_inc = 1'b1;
            // end
            row_idx_inc = power_valid;
        end
        STATE_COL0: begin
            stop_samples = 1'b1;
            col_phase = 1'b1;
            // if (power_ready) begin
            //     power_start = 1'b1;
            // end
        end
        STATE_COL1: begin
            stop_samples = 1'b1;
            col_phase = 1'b1;
            if (power_valid) begin
                col_idx_inc = 1'b1;
            end
        end
        STATE_OUT: begin
            stop_samples = 1'b1;
            row_idx_clr = 1'b1;
            col_idx_clr = 1'b1;
            max_row_idx_clr = 1'b1;
            max_col_idx_clr = 1'b1;
            valid = 1'b1;
            blk_counter_load = 1'b1;
        end
    endcase

end

always @(posedge clk) begin
    if (~rst_n) begin
        state <= STATE_RESET;
    end else begin
        state <= next_state;
    end
end

endmodule

