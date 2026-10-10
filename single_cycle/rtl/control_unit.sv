import alu_pkg::*;
module control_unit (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    output logic reg_write,
    output logic alu_src, // 1 for immediate, 0 for register
    output logic mem_read,
    output logic mem_write,
    output logic mem_to_reg, // 1 for rg[] = mem[]
    output logic branch,
    output logic jump,
    output logic jalr,
    output alu_op_t alu_op
);


    always_comb begin
        reg_write = 1'b0;
        alu_src = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        alu_op = ADD;
        jalr = 1'b0;
        case(opcode)
        7'b0110011: begin // R-type
            reg_write = 1'b1;
            case(funct3)
            3'b000: alu_op = alu_op_t'((funct7[5]) ? SUB : ADD);
            3'b111: alu_op = AND;
            3'b110: alu_op = OR;
            3'b100: alu_op = XOR;
            3'b001: alu_op = SLL;
            3'b101: alu_op = alu_op_t'((funct7[5]) ? SRA : SRL);
            3'b010: alu_op = SLT;
            3'b011: alu_op = SLTU;
            endcase
        end
        7'b0010011: begin // I-type
            reg_write = 1'b1;
            alu_src = 1'b1;
            case(funct3)
            3'b000: alu_op = ADD;
            3'b111: alu_op = AND;
            3'b110: alu_op = OR;
            3'b100: alu_op = XOR;
            3'b010: alu_op = SLT;
            3'b011: alu_op = SLTU;
            3'b001: alu_op = SLL;
            3'b101: alu_op = alu_op_t'((funct7[5]) ? SRA : SRL);
            endcase
        end
        7'b0000011: begin
            reg_write = 1'b1;
            alu_src = 1'b1;
            mem_read = 1'b1;
            mem_to_reg = 1'b1;
            alu_op = ADD;
        end
        7'b0100011: begin
            alu_src = 1'b1;
            mem_write = 1'b1;
            alu_op = ADD;
        end
        7'b1100011: begin
            branch = 1'b1;
            case(funct3)
            3'b000: alu_op = SUB;
            3'b001: alu_op = SUB;
            3'b100: alu_op = SLT;
            3'b110: alu_op = SLTU;
            3'b101: alu_op = SLT;
            3'b111: alu_op = SLTU;
            endcase
        end
        7'b1101111: begin
            jump = 1'b1;
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = ADD;
        end
        7'b1100111: begin
            jalr = 1'b1;
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = ADD;
        end
        7'b0010111: begin
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = ADD;
        end
        7'b0110111: begin
            reg_write = 1'b1;
            alu_src = 1'b1;
            alu_op = LUI;
        end
        endcase
    end

endmodule
