module imm_gen (
    input logic [31:0] instr,
    output logic [31:0] imm_out //sign-extended
);

    always_comb begin
        case(instr[6:0])
        7'b0010011, // I-type
        7'b0000011,
        7'b1100111,
        7'b1110011: begin
            imm_out = {{20{instr[31]}}, instr[31:20]};
        end
        7'b0100011: begin // S-type
            imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end
        7'b1100011: begin // B-type
            imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        end
        7'b1101111: begin // J-type
            imm_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
        end
        7'b0010111,
        7'b0110111: begin // U-type
            imm_out = {instr[31:12], {12{1'b0}}};
        end
        endcase
    end




endmodule
