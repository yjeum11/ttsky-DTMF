`default_nettype none

module power_calculate #(
    parameter BLOCK_SIZE = 512,
    parameter BLOCK_SIZE_BITS = $clog2(BLOCK_SIZE)
)(
    input reg clk, rst_n,
    input reg signed [7:0] sample,
    input reg signed [10:0] coeff,
    input reg sample_valid,
    output reg sample_ready,
    input reg start,
    output reg ready, power_valid,
    output reg signed [47:0] power
);

// iterate thru 12 different coefficients
    // calculate the power for each coefficient.

reg signed [23:0] s_prev, s_prev2;
reg iir_valid, iir_sample_ready;
reg stop_samples;
reg [BLOCK_SIZE_BITS:0] blk_counter;
reg counter_dec, counter_load, counter_0;

assign sample_ready = ~stop_samples & iir_sample_ready;

goertzel_iir iir (
    .clk(clk), .rst_n(rst_n),
    .sample(sample),
    .sample_valid(sample_valid),
    .sample_ready(iir_sample_ready),
    .coeff(coeff),
    .s_prev(s_prev), .s_prev2(s_prev2),
    .valid(iir_valid)
);

reg signed [23:0] A, B;
reg [1:0] selA, selB;
reg AB_valid, AB_ready;
reg signed [47:0] Q;
reg Q_valid;

assign A = (selA == 0) ? s_prev :
           (selA == 1) ? -s_prev2 :
           '0;
assign B = (selB == 0) ? s_prev :
           (selB == 1) ? -s_prev2 :
           (selB == 2) ? {13'b0, coeff} :
           (selB == 3) ? Q[23+9:0+9] :
           '0;

serial_mult #(24) mult (
    .clk(clk), .rst_n(rst_n),
    .A(A), .B(B),
    .AB_valid(AB_valid), .AB_ready(AB_ready),
    .Q(Q),
    .Q_valid(Q_valid)
);

assign counter_0 = blk_counter == 0;

always @(posedge clk) begin
    if (~rst_n)
        blk_counter <= BLOCK_SIZE;
    else begin
        if (counter_load)
            blk_counter <= BLOCK_SIZE;
        else if (counter_dec)
            blk_counter <= blk_counter - 1;
    end
end

reg power_acc, power_clr;

always @(posedge clk) begin
    if (~rst_n)
        power <= '0;
    else begin
        if (power_clr)
            power <= '0;
        else if (power_acc)
            power <= power + Q;
    end
end

reg [3:0] state, next_state;
localparam STATE_INIT = 0;
localparam STATE_WAIT_IIR = 1;
localparam STATE_WAIT_MULT0  = 2;
localparam STATE_SETUP_MULT1 = 3;
localparam STATE_WAIT_MULT1  = 4;
localparam STATE_SETUP_MULT2 = 5;
localparam STATE_WAIT_MULT2  = 6;
localparam STATE_SETUP_MULT3 = 7;
localparam STATE_WAIT_MULT3  = 8;
localparam STATE_OUTPUT  =     9;

always @* begin
    next_state = state;
    case (state)
        STATE_INIT: begin
            if (start) begin
                next_state = STATE_WAIT_IIR;
            end
        end
        STATE_WAIT_IIR: begin
            if (counter_0) begin
                next_state = STATE_WAIT_MULT0;
            end
        end
        STATE_WAIT_MULT0: begin
            if (Q_valid) begin
                next_state = STATE_SETUP_MULT1;
            end
        end
        STATE_SETUP_MULT1: begin
            if (AB_ready) begin
                next_state = STATE_WAIT_MULT1;
            end
        end
        STATE_WAIT_MULT1: begin
            if (Q_valid) begin
                next_state = STATE_SETUP_MULT2;
            end
        end
        STATE_SETUP_MULT2: begin
            if (AB_ready) begin
                next_state = STATE_WAIT_MULT2;
            end
        end
        STATE_WAIT_MULT2: begin
            if (Q_valid) begin
                next_state = STATE_SETUP_MULT3;
            end
        end
        STATE_SETUP_MULT3: begin
            if (AB_ready) begin
                next_state = STATE_WAIT_MULT3;
            end
        end
        STATE_WAIT_MULT3: begin
            if (Q_valid) begin
                next_state = STATE_OUTPUT;
            end
        end
        STATE_OUTPUT: begin
            if (start) begin
                next_state = STATE_WAIT_IIR;
            end
        end
    endcase
end

always @* begin
    counter_load = 1'b0;
    counter_dec = 1'b0;
    stop_samples = 1'b0;
    selA = 2'b0;
    selB = 2'b0;
    AB_valid = 1'b0;
    power_acc = 1'b0;
    power_clr = 1'b0;
    power_valid = 1'b0;
    ready = 1'b0;
    case (state)
        STATE_INIT: begin
            ready = 1'b1;
            if (start) begin
                counter_load = 1'b1;
            end
        end
        STATE_WAIT_IIR: begin
            if (iir_valid) begin
                counter_dec = 1'b1;
            end
            if (counter_0) begin
                stop_samples = 1'b1;
                selA = 2'b0;
                selB = 2'b0;
                AB_valid = 1'b1;
            end
        end
        STATE_WAIT_MULT0: begin
            stop_samples = 1'b1;
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_SETUP_MULT1: begin
            stop_samples = 1'b1;
            selA = 2'b1;
            selB = 2'b1;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT1: begin
            stop_samples = 1'b1;
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_SETUP_MULT2: begin
            stop_samples = 1'b1;
            selA = 2'b0;
            selB = 2'd2;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT2: begin
            stop_samples = 1'b1;
        end
        STATE_SETUP_MULT3: begin
            stop_samples = 1'b1;
            selA = 2'b1;
            selB = 2'd3;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT3: begin
            stop_samples = 1'b1;
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_OUTPUT: begin
            power_valid = 1'b1;
            ready = 1'b1;
            if (start) begin
                counter_load = 1'b1;
                power_clr = 1'b1;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (~rst_n) begin
        state <= STATE_INIT;
    end else begin
        state <= next_state;
    end
end

endmodule
