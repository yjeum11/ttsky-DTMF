`default_nettype none

`define STATE_WAITING 0
`define STATE_CALC 1
`define STATE_OUTPUT 2

module serial_mult #(
    parameter WIDTH = 4'd8
) (
    input clk, rst_n,
    input reg [WIDTH-1:0] A, B,
    input reg AB_valid,
    output reg AB_ready,
    output reg [2*WIDTH-1:0] Q,
    output reg Q_valid
);

    reg [WIDTH-1:0] sum_reg, B_reg;
    reg [4:0] counter;

    reg [1:0] state, next_state;
    reg load_inputs, shift_regs;
    reg counter_dec, counter_load;
    reg carry;

    always @(posedge clk) begin
        if (~rst_n) begin
            counter <= WIDTH;
            Q <= '0;
            B_reg <= '0;
        end else begin
            if (counter_dec) begin
                counter <= counter - 1;
            end else if (counter_load) begin
                counter <= WIDTH;
            end

            if (load_inputs) begin
                Q <= {{WIDTH{1'b0}}, A};
                B_reg <= B;
            end
            if (shift_regs) begin
                Q <= {carry, sum_reg, Q[WIDTH-1:1]};
            end
        end
    end

    always @* begin
        if (Q[0]) begin
            {carry, sum_reg} = Q[2*WIDTH-1:WIDTH] + B_reg;
        end else begin
            sum_reg = Q[2*WIDTH-1:WIDTH];
            carry = 0;
        end
    end

    // state machine

    always @* begin
        load_inputs = 0;
        counter_load = 0;
        counter_dec = 0;
        Q_valid = 0;
        AB_ready = 0;
        shift_regs = 0;
        next_state = state;
        case (state) 
            `STATE_WAITING: begin
                if (AB_valid) begin
                    next_state = `STATE_CALC;
                    load_inputs = 1;
                end
                AB_ready = 1;
            end
            `STATE_CALC: begin
                if (counter == 0) begin
                    next_state = `STATE_OUTPUT;
                end else begin
                    shift_regs = 1;
                    counter_dec = 1;
                end
            end
            `STATE_OUTPUT: begin
                next_state = `STATE_WAITING;
                Q_valid = 1;
                counter_load = 1;
            end
        endcase 
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            state <= `STATE_WAITING;
        end else begin
            state <= next_state;
        end
    end


endmodule
