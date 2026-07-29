`default_nettype none

module coeff_ram (
    input [3:0] idx,
    output [10:0] coeff
);

reg signed [(7 * 11)-1:0] coeffs;
assign coeffs = {11'd1001, 11'd1006, 11'd1009, 11'd1015, 11'd1016, 11'd1018, 11'd1019};
assign coeff = coeffs[idx * 11 +: 11];

endmodule