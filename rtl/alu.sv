import alu_pkg::*;
module alu (
    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_t alu_ctrl,
    output logic [31:0] result,
    output logic zero
);

    always_comb begin
        case(alu_ctrl)
        ADD: result = a + b;
        SUB: result = a - b;
        OR: result = a | b;
        AND: result = a & b;
        XOR: result = a ^ b;
        SLL: result = a << b[4:0]; // b is shift amount
        SRL: result = a >> b[4:0];
        SRA: result = $signed(a) >>> b[4:0];
        SLT: result = {31'd0, $signed(a) < $signed(b)};
        SLTU: result = {31'd0, a < b};
        LUI: result = b;
        default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule

