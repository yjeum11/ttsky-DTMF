`default_nettype none

module power_calculate #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 11,
    parameter POWER_SHIFT = 4
)(
    input clk, rst_n,
    input signed [INTERNAL_WIDTH-1:0] s_prev, s_prev2,
    input signed [COEFF_WIDTH-1:0] coeff,
    input wire start,
    output reg ready, power_valid,
    output reg signed [(2*INTERNAL_WIDTH - 2*POWER_SHIFT)-1:0] power,
    output signed [INTERNAL_WIDTH-1:0] A, B,
    input AB_ready,
    output reg  AB_valid,
    input signed [(2*INTERNAL_WIDTH)-1:0] Q,
    input Q_valid
);

// in order to get rid of max_power in project.v
// use `power` as the max_power register.
// so we just need signals telling us when to reset the max power register
// this is impossible? we need the power register to build up the product 
// and we don't know how big the next value will be until we have built up the entire thing.
// 

// pre-shift the s_prevs prior to multiplication. this will result in the power result already being
// shifted to the right by POWER_SHIFT*2
// POWER_SHIFT is bitlength(N^2). so instead of 48 bits it will be like 30.
// final calculation is s_prev^2 + s_prev2^2 - coeff * s_prev * s_prev2
// for the iir calculation we actually dont need the upper 24 bits of Q.
// the only reason we keep the upper bits of Q is because of power.
// 
// so the multiplier can be log2(16) = 4 bits smaller in the input for 20bit A and B
// and 8 bits smaller in the output for 40bit Q.
// for IIR, we have 24bit inputs and 24bit output. we are throwing away the top 24 bits of the multiplier result.

// we can just do the shift and throw away the upper 8 bits of power. this will save space in max_power result

reg [1:0] selA, selB;



assign A = (selA == 0) ? (s_prev >>> POWER_SHIFT) :
           (selA == 1) ? -(s_prev2 >>> POWER_SHIFT) :
           '0;
assign B = (selB == 0) ? (s_prev >>> POWER_SHIFT) :
           (selB == 1) ? -(s_prev2 >>> POWER_SHIFT) :
           (selB == 2) ? {{(INTERNAL_WIDTH-COEFF_WIDTH){'0}}, coeff} :
           (selB == 3) ? Q[COEFF_WIDTH-2 +: INTERNAL_WIDTH] :
           '0;

reg power_acc, power_clr;

always @(posedge clk) begin
    if (~rst_n)
        power <= '0;
    else begin
        if (power_clr)
            power <= '0;
        else if (power_acc)
            power <= power + Q[2*INTERNAL_WIDTH-2*POWER_SHIFT-1:0];
    end
end

reg [3:0] state, next_state;
localparam STATE_INIT        = 0;
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
            next_state = STATE_INIT;
        end
    endcase
end

always @* begin
    selA = 2'b0;
    selB = 2'b0;
    AB_valid = 1'b0;
    power_acc = 1'b0;
    power_clr = 1'b0;
    power_valid = 1'b0;
    ready = 1'b0;
    case (state)
        STATE_INIT: begin
            if (start) begin
                AB_valid = 1'b1;
            end
            ready = 1'b1;
        end
        STATE_WAIT_MULT0: begin
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_SETUP_MULT1: begin
            selA = 2'b1;
            selB = 2'b1;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT1: begin
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_SETUP_MULT2: begin
            selA = 2'b0;
            selB = 2'd2;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT2: begin
        end
        STATE_SETUP_MULT3: begin
            selA = 2'b1;
            selB = 2'd3;
            AB_valid = 1'b1;
        end
        STATE_WAIT_MULT3: begin
            if (Q_valid) begin
                power_acc = 1'b1;
            end
        end
        STATE_OUTPUT: begin
            power_valid = 1'b1;
            power_clr = 1'b1;
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
