module goertzel_iir #(
    parameter INTERNAL_WIDTH = 20,
    parameter COEFF_WIDTH = 11,
    parameter B_WIDTH = 11
) (
    input reg clk, rst_n,
    input reg signed [7:0] sample,
    input reg sample_valid,
    output reg sample_ready,
    // Coefficient cos(omega_0) given in Q1.10 format
    output reg [3:0] coeff_idx,
    input reg [COEFF_WIDTH-1:0] coeff,
    input reg signed [INTERNAL_WIDTH-1:0] s_prev, s_prev2,
    output reg signed [INTERNAL_WIDTH-1:0] s_prev_next, s_prev2_next,
    output reg write_reg,
    output reg valid,

    output reg signed [INTERNAL_WIDTH-1:0] A,
    output reg signed [B_WIDTH-1:0] B,
    input reg AB_ready,
    output reg  AB_valid,
    input reg signed [INTERNAL_WIDTH+B_WIDTH-1:0] Q,
    input reg Q_valid
);


reg signed [7:0] sample_reg;
reg signed [INTERNAL_WIDTH-1:0] s;
wire signed [INTERNAL_WIDTH-1:0] Q_shifted;
reg sample_load, internal_load;

reg idx_load, idx_inc;

// NOTE: coeff represents number <= 1. So Q will require as many bits to
// represent as s_prev. Safely discard higher bits

/* verilator lint_off WIDTHTRUNC */
assign Q_shifted = Q >>> (COEFF_WIDTH-2);

assign s = (Q_shifted - s_prev2) + {{(INTERNAL_WIDTH-8){sample_reg[7]}},sample_reg}; 

assign A = s_prev;
assign B = coeff;

assign write_reg = internal_load;
assign s_prev_next = s;
assign s_prev2_next = s_prev;

always @(posedge clk) begin
    if (~rst_n) begin
        sample_reg <= '0;
        coeff_idx <= 4'd0;
    end else begin
        if (sample_load) begin
            sample_reg <= sample;
        end
        if (idx_load) begin
            coeff_idx <= 4'd0;
        end else if (idx_inc) begin
            coeff_idx <= coeff_idx + 1;
        end

    end
end

// state machine
reg [3:0] state, next_state;
localparam STATE_RST       = 0;
localparam STATE_MULT_INIT = 1;
localparam STATE_MULT_WAIT = 2;
localparam STATE_LAST_MULT_WAIT = 3;
localparam STATE_OUTPUT    = 4;

always @* begin
    sample_ready = 1'b0;
    sample_load = 1'b0;
    AB_valid = 1'b0;
    internal_load = 1'b0;
    valid = 1'b0;
    idx_inc = 1'b0;
    idx_load = 1'b0;
    case (state)
        STATE_RST: begin
            sample_ready = 1'b1;
            if (sample_valid) begin
                sample_load = 1'b1;
                idx_load = 1'b1;
            end
        end
        STATE_MULT_INIT: begin
            AB_valid = 1'b1;
        end
        STATE_MULT_WAIT: begin
            if (Q_valid) begin
                internal_load = 1'b1;
                if (coeff_idx != 4'd6)
                    idx_inc = 1'b1;
            end
        end
        STATE_LAST_MULT_WAIT: begin
            if (Q_valid) begin
                internal_load = 1'b1;
            end
        end
        STATE_OUTPUT: begin
            valid = 1'b1;
        end
    endcase
end

always @* begin
    next_state = state;
    case (state)
        STATE_RST: begin
            if (sample_valid) begin
                next_state = STATE_MULT_INIT;
            end
        end
        STATE_MULT_INIT: begin
            if (AB_ready) begin
                next_state = STATE_MULT_WAIT;
            end
        end
        STATE_MULT_WAIT: begin
            if (Q_valid) begin
                if (coeff_idx == 4'd6) begin
                    next_state = STATE_OUTPUT;
                end else begin
                    next_state = STATE_MULT_INIT;
                end
            end
        end
        STATE_LAST_MULT_WAIT: begin
            if (Q_valid) begin
                next_state = STATE_OUTPUT;
            end
        end
        STATE_OUTPUT: begin
            next_state = STATE_RST;
        end
    endcase
end

always @(posedge clk) begin
    if (~rst_n) begin
        state <= STATE_RST;
    end else begin
        state <= next_state;
    end
end

endmodule
