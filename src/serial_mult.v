`default_nettype none

module serial_mult #(
    parameter WIDTH_A = 4'd8,
    parameter WIDTH_B = 4'd8
) (
    input clk, rst_n,
    input reg signed [WIDTH_A-1:0] A,
    input reg signed [WIDTH_B-1:0] B,
    input reg AB_valid,
    output reg AB_ready,
    output reg signed [WIDTH_A+WIDTH_B-1:0] Q,
    output reg Q_valid
);

    // A is multiplier, B is multiplicand
    // "add multiplicand `multiplier` amount of times"

    reg [WIDTH_A+WIDTH_B-1:0] Q_orig, Q_subbed;

    reg [WIDTH_B-1:0] sum_reg, B_reg;
    reg [$clog2(WIDTH_A):0] counter;

    reg [1:0] state, next_state;
    reg load_inputs, shift_regs;
    reg counter_dec, counter_load;
    reg multiplier_neg, multiplicand_neg;
    reg carry;

    assign Q = multiplier_neg ? Q_subbed : Q_orig;

    assign Q_subbed = Q_orig - {B_reg, {WIDTH_A{1'b0}}};

    always @(posedge clk) begin
        if (~rst_n) begin
            counter <= WIDTH_A;
            Q_orig <= '0;
            B_reg <= '0;
            multiplier_neg <= '0;
            multiplicand_neg <= '0;
        end else begin
            if (counter_dec) begin
                counter <= counter - 1;
            end else if (counter_load) begin
                counter <= WIDTH_A;
            end

            if (load_inputs) begin
                Q_orig <= {{WIDTH_B{1'b0}}, A};
                B_reg <= B;
                multiplier_neg <= A[WIDTH_A-1];
                multiplicand_neg <= B[WIDTH_B-1];
            end
            if (shift_regs) begin
                Q_orig <= {carry | (sum_reg[WIDTH_B-1] & multiplicand_neg), sum_reg, Q_orig[WIDTH_A-1:1]};
            end
        end
    end

    always @* begin
        if (Q_orig[0]) begin
            // {carry, sum_reg} = Q_orig[2*WIDTH-1:WIDTH] + B_reg;
            {carry, sum_reg} = Q_orig[WIDTH_A +: WIDTH_B] + B_reg;
        end else begin
            sum_reg = Q_orig[WIDTH_A +: WIDTH_B];
            carry = 0;
        end
    end

    localparam STATE_WAITING = 0;
    localparam STATE_CALC = 1;
    localparam STATE_OUTPUT = 2;

    // state machine
    //
    always @* begin
        next_state = state;
        case (state) 
            STATE_WAITING: begin
                if (AB_valid) begin
                    next_state = STATE_CALC;
                end
            end
            STATE_CALC: begin
                if (counter == 0) begin
                    next_state = STATE_OUTPUT;
                end 
            end
            STATE_OUTPUT: begin
                next_state = STATE_WAITING;
            end
        endcase 
    end

    always @* begin
        load_inputs = 0;
        counter_load = 0;
        counter_dec = 0;
        Q_valid = 0;
        AB_ready = 0;
        shift_regs = 0;
        case (state) 
            STATE_WAITING: begin
                if (AB_valid) begin
                    load_inputs = 1;
                end
                AB_ready = 1;
            end
            STATE_CALC: begin
                if (counter != 0) begin
                    shift_regs = 1;
                    counter_dec = 1;
                end
            end
            STATE_OUTPUT: begin
                Q_valid = 1;
                counter_load = 1;
            end
        endcase 
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            state <= STATE_WAITING;
        end else begin
            state <= next_state;
        end
    end


endmodule
