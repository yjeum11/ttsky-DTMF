module countup_reg #(parameter WIDTH = 8) (
    input clk, rst_n,
    input [WIDTH-1:0] D,
    input load, clr, inc,
    output reg [WIDTH-1:0] Q
);

always @(posedge clk) begin
    if (~rst_n)
        Q <= '0;
    else begin
        if (clr)
            Q <= '0;
        else if (load)
            Q <= D;
        else if (inc)
            Q <= Q + 1;
    end
end
endmodule: countup_reg

// combinational read, sequential write
module regfile #(parameter WIDTH = 24) (
    input clk, rst_n,
    input [3:0] idx,
    input write,
    input [WIDTH-1:0] D,
    output [WIDTH-1:0] Q
);

reg [7*WIDTH-1:0] internal;

assign Q = internal[WIDTH*idx +: WIDTH];

always @(posedge clk) begin
    if (~rst_n) begin
        internal <= '0;
    end else begin
        if (write) begin
            internal[WIDTH*idx +: WIDTH] <= D;
        end
    end
end

endmodule: regfile