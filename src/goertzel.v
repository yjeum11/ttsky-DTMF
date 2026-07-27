module goertzel_iir #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 11
) (
    input reg clk, rst_n,
    input reg signed [7:0] sample,
    input reg sample_valid,
    output reg sample_ready,
    // Coefficient cos(omega_0) given in Q1.10 format
    input reg [COEFF_WIDTH-1:0] coeff,
    output reg signed [INTERNAL_WIDTH-1:0] s_prev, s_prev2,
    output reg valid
);


reg signed [7:0] sample_reg;
reg signed [INTERNAL_WIDTH-1:0] s;
reg signed [2*INTERNAL_WIDTH-1:0] Q_temp;
wire signed [INTERNAL_WIDTH-1:0] Q;
reg AB_valid, AB_ready, Q_valid;
reg sample_load, internal_load;

// NOTE: coeff represents number <= 1. So Q will require as many bits to
// represent as s_prev. Safely discard higher bits

/* verilator lint_off WIDTHTRUNC */
assign Q = Q_temp >>> (COEFF_WIDTH-2);

assign s = (Q - s_prev2) + {{(INTERNAL_WIDTH-8){sample_reg[7]}},sample_reg}; 

serial_mult #(INTERNAL_WIDTH) mult (
    .clk(clk), .rst_n(rst_n),
    .A(s_prev),
    .B({{(INTERNAL_WIDTH-COEFF_WIDTH){1'b0}}, coeff}),
    .AB_valid(AB_valid),
    .AB_ready(AB_ready),
    .Q(Q_temp),
    .Q_valid(Q_valid)
);

always @(posedge clk) begin
    if (~rst_n) begin
        sample_reg <= '0;
        s_prev <= '0;
        s_prev2 <= '0;
    end else begin
        if (sample_load) begin
            sample_reg <= sample;
        end
        if (internal_load) begin
            s_prev <= s;
            s_prev2 <= s_prev;
        end
    end
end

// state machine
reg [3:0] state, next_state;
localparam STATE_RST       = 0;
localparam STATE_MULT_INIT = 1;
localparam STATE_MULT_WAIT = 2;
localparam STATE_OUTPUT    = 3;

always @* begin
    sample_ready = 1'b0;
    sample_load = 1'b0;
    AB_valid = 1'b0;
    internal_load = 1'b0;
    valid = 1'b0;
    case (state)
        STATE_RST: begin
            sample_ready = 1'b1;
            if (sample_valid) begin
                sample_load = 1'b1;
            end
        end
        STATE_MULT_INIT: begin
            AB_valid = 1'b1;
        end
        STATE_MULT_WAIT: begin
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
