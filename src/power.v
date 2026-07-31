`default_nettype none

module power_calculate #(
    parameter INTERNAL_WIDTH = 24,
    parameter COEFF_WIDTH = 11
)(
    input reg clk, rst_n,
    input reg signed [INTERNAL_WIDTH-1:0] s_prev, s_prev2,
    input reg signed [COEFF_WIDTH-1:0] coeff,
    input wire start,
    output reg ready, power_valid,
    output reg signed [(2*INTERNAL_WIDTH)-1:0] power
);

reg signed [INTERNAL_WIDTH-1:0] A, B;
reg [1:0] selA, selB;
reg AB_valid, AB_ready;
reg signed [(2*INTERNAL_WIDTH)-1:0] Q;
reg Q_valid;

assign A = (selA == 0) ? s_prev :
           (selA == 1) ? -s_prev2 :
           '0;
assign B = (selB == 0) ? s_prev :
           (selB == 1) ? -s_prev2 :
           (selB == 2) ? {{(INTERNAL_WIDTH-COEFF_WIDTH){'0}}, coeff} :
           (selB == 3) ? Q[INTERNAL_WIDTH-1+COEFF_WIDTH-2:COEFF_WIDTH-2] :
           '0;

serial_mult #(INTERNAL_WIDTH) mult (
    .clk(clk), .rst_n(rst_n),
    .A(A), .B(B),
    .AB_valid(AB_valid), .AB_ready(AB_ready),
    .Q(Q),
    .Q_valid(Q_valid)
);

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
