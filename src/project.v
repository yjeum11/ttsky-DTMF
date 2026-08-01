/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_yjeum11 #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 11,
    parameter BLOCK_SIZE = 16,
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

localparam NUM_ROWS = 4;
localparam NUM_COLS = 3;

reg [3:0] row_idx, col_idx, s_prev_idx, max_row_idx, max_col_idx;
reg row_idx_clr, col_idx_clr, row_idx_inc, col_idx_inc;
reg max_row_idx_load, max_col_idx_load, max_row_idx_clr, max_col_idx_clr;
reg [3:0] coeff_idx;

reg stop_samples, row_phase, col_phase, power_phase;

wire power_start;
wire power_ready;
reg power_valid;
reg max_power_clr, max_power_load;
reg new_max;
reg [2*(INTERNAL_WIDTH)-1:0] power, max_power;

// TODO: assign I/O pins to these
reg sample_ready, sample_valid;
reg valid;
assign uio_out[0] = sample_ready;
assign sample_valid = uio_in[1];
assign uo_out = {max_row_idx, max_col_idx};
assign uio_out[2] = valid;
assign uio_oe = 8'b0000_0101;

assign uio_out[7:3] = '0;
assign uio_out[1] = 1'b0;

wire _unused = &{uio_in[7:2], uio_in[0], ena, 1'b0};

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
                    (col_phase) ? col_idx + NUM_ROWS : '0;

assign max_row_idx_load = new_max & row_phase;
assign max_col_idx_load = new_max & col_phase;

countup_reg #(4) row_cnt (.clk, .rst_n, .D(), .Q(row_idx), .clr(row_idx_clr), .inc(row_idx_inc), .load());
countup_reg #(4) col_cnt (.clk, .rst_n, .D(), .Q(col_idx), .clr(col_idx_clr), .inc(col_idx_inc), .load());
countup_reg #(4) max_row_reg (.clk, .rst_n, .D(row_idx), .Q(max_row_idx), .clr(max_row_idx_clr), .inc(), .load(max_row_idx_load));
countup_reg #(4) max_col_reg (.clk, .rst_n, .D(col_idx), .Q(max_col_idx), .clr(max_col_idx_clr), .inc(), .load(max_col_idx_load));

reg iir_sample_ready, iir_valid;
reg [3:0] iir_coeff_idx;
reg [COEFF_WIDTH-1:0] coeff;

reg [(INTERNAL_WIDTH)-1:0] s_prev, s_prev2, s_prev_next, s_prev2_next;
reg s_prev_write;

wire signed [INTERNAL_WIDTH-1:0] A_iir, B_iir;
wire AB_ready_iir, AB_valid_iir, Q_valid_iir;
wire signed [2*INTERNAL_WIDTH-1:0] Q_iir;
assign Q_iir = (~power_phase) ? Q : '0;
assign Q_valid_iir = (~power_phase) ? Q_valid : '0;
assign AB_ready_iir = (~power_phase) ? AB_ready : '0;

goertzel_iir #(
    .INTERNAL_WIDTH(INTERNAL_WIDTH), .COEFF_WIDTH(COEFF_WIDTH)
) iir (
    .clk, .rst_n,
    .sample(ui_in),
    .sample_valid(sample_valid),
    .sample_ready(iir_sample_ready),
    // Coefficient cos(omega_0) given in Q1.10 format
    .coeff_idx(iir_coeff_idx),
    .coeff(coeff),
    .s_prev, .s_prev2,
    .s_prev_next, .s_prev2_next,
    .write_reg(s_prev_write),
    .valid(iir_valid),

    .A(A_iir), .B(B_iir),
    .AB_ready(AB_ready_iir), .AB_valid(AB_valid_iir),
    .Q(Q_iir),
    .Q_valid(Q_valid_iir)
);

// in the process of factoring out regfile out of goertzel_iir 
regfile #(INTERNAL_WIDTH) s_prev_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .idx   (coeff_idx),
    .write (s_prev_write),
    .D     (s_prev_next),
    .Q     (s_prev)
);

// in the process of factoring out regfile out of goertzel_iir 
regfile #(INTERNAL_WIDTH) s_prev2_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .idx   (coeff_idx),
    .write (s_prev_write),
    .D     (s_prev2_next),
    .Q     (s_prev2)
);

assign new_max = power_valid & (power > max_power);
assign max_power_load = new_max;

countup_reg #(2*INTERNAL_WIDTH) max_power_reg (.clk(clk), .rst_n(rst_n), .D(power), .load(max_power_load), .clr(max_power_clr), .inc(), .Q(max_power));

wire signed [INTERNAL_WIDTH-1:0] A_pow, B_pow;
wire AB_ready_pow, AB_valid_pow, Q_valid_pow;
wire signed [2*INTERNAL_WIDTH-1:0] Q_pow;
assign Q_pow = (power_phase) ? Q : '0;
assign Q_valid_pow = (power_phase) ? Q_valid : '0;
assign AB_ready_pow = (power_phase) ? AB_ready : '0;

power_calculate #(
    .INTERNAL_WIDTH(INTERNAL_WIDTH), .COEFF_WIDTH(COEFF_WIDTH)
) pow (
    .clk, .rst_n,
    .s_prev(s_prev),
    .s_prev2(s_prev2),
    .coeff(coeff),
    .start(power_start),
    .ready(power_ready), .power_valid,
    .power,
    .A(A_pow), .B(B_pow),
    .AB_ready(AB_ready_pow), .AB_valid(AB_valid_pow),
    .Q(Q_pow),
    .Q_valid(Q_valid_pow)
);

assign coeff_idx = (power_phase) ? s_prev_idx : iir_coeff_idx;

coeff_ram coefficients (.idx(coeff_idx), .coeff);

wire [INTERNAL_WIDTH-1:0] A, B;
wire [2*INTERNAL_WIDTH-1:0] Q;
wire AB_valid, AB_ready, Q_valid;
assign A = (power_phase) ? A_pow : A_iir;
assign B = (power_phase) ? B_pow : B_iir;
assign AB_valid = (power_phase) ? AB_valid_pow : AB_valid_iir;

serial_mult #(INTERNAL_WIDTH) com_mult (
    .clk      (clk      ),
    .rst_n    (rst_n    ),
    .A        (A        ),
    .B        (B        ),
    .AB_valid (AB_valid ),
    .AB_ready (AB_ready ),
    .Q        (Q        ),
    .Q_valid  (Q_valid  )
);

/******** state machine ********/

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
            if (power_ready & (row_idx != NUM_ROWS)) begin
                next_state = STATE_ROW1;
            end else if (power_ready & (row_idx == NUM_ROWS)) begin
                next_state = STATE_COL0;
            end
        end
        STATE_ROW1: begin
            if (power_valid) begin
                next_state = STATE_ROW0;
            end
        end
        STATE_COL0: begin
            if (power_ready & (col_idx != NUM_COLS)) begin
                next_state = STATE_COL1;
            end else if (power_ready & (col_idx == NUM_COLS)) begin
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
        default: begin
        end
    endcase

end

assign power_start = (state == STATE_ROW0 & row_idx != NUM_ROWS) | (state == STATE_COL0);

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
    max_power_clr = 1'b0;
    valid = 1'b0;
    case (state)
        STATE_RESET: begin
            blk_counter_dec = sample_ready & sample_valid;
        end
        STATE_ROW0: begin
            stop_samples = 1'b1;
            row_phase = 1'b1;
            if (power_ready & row_idx == NUM_ROWS) begin
                max_power_clr = 1'b1;
            end
        end
        STATE_ROW1: begin
            stop_samples = 1'b1;
            row_phase = 1'b1;
            if (power_valid) begin
                row_idx_inc = power_valid;
            end
        end
        STATE_COL0: begin
            stop_samples = 1'b1;
            col_phase = 1'b1;
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
            max_power_clr = 1'b1;
        end
        default: begin
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

