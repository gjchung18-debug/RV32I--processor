import alu_pkg::*;

module datapath (
    input logic clk,
    input logic rst
);

    logic [31:0] pc_out, instr_out, imm_out, write_back_mux,
    rs1_out, rs2_out, alu_b_mux, alu_result, read_data, sequential_pc_adder, bj_target_adder, next_pc_mux;

    logic zero, mem_read, mem_write, reg_write, alu_src, mem_to_reg, branch, jump, branch_cond, jalr;

    alu_op_t alu_ctrl;

    pc_reg pc_reg_inst (
        .clk(clk),
        .rst(rst),
        .pc_next(next_pc_mux),
        .pc_curr(pc_out)
    );

    assign sequential_pc_adder = pc_out + 32'd4;

    assign bj_target_adder = pc_out + imm_out;

    logic raw_branch_cond;

    always_comb begin
        case (instr_out[14:12])
            3'b000:  raw_branch_cond = zero;
            3'b001:  raw_branch_cond = ~zero;
            3'b100:  raw_branch_cond = alu_result[0];
            3'b110:  raw_branch_cond = ~alu_result[0];
            3'b101:  raw_branch_cond = alu_result[0];
            3'b111:  raw_branch_cond = ~alu_result[0];
            default: raw_branch_cond = 1'b0;
        endcase
    end

    assign branch_cond = branch & raw_branch_cond;

    assign next_pc_mux = jalr ? alu_result : ((branch_cond) || jump) ? bj_target_adder : sequential_pc_adder;

    instr_mem instr_mem_inst (
        .addr(pc_out),
        .instr(instr_out)
    );

    imm_gen imm_gen_inst(
        .instr(instr_out),
        .imm_out(imm_out)
    );

    register_file register_file_inst(
        .clk(clk),
        .rs1_addr(instr_out[19:15]),
        .rs2_addr(instr_out[24:20]),
        .rd_addr(instr_out[11:7]),
        .rd_data(write_back_mux),
        .reg_write(reg_write),
        .rs1_data(rs1_out), // output
        .rs2_data(rs2_out) // output
    );

    assign alu_b_mux = alu_src ? imm_out : rs2_out;

    alu alu_inst(
        .a(rs1_out),
        .b(alu_b_mux),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    assign write_back_mux = (jump || jalr) ? sequential_pc_adder : mem_to_reg ? read_data : alu_result;


    data_mem data_mem_inst(
        .clk(clk),
        .addr(alu_result),
        .write_data(rs2_out),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .funct3(instr_out[14:12]),
        .read_data(read_data) // output
    );

    control_unit control_unit_inst(
        .opcode(instr_out[6:0]),
        .funct3(instr_out[14:12]),
        .funct7(instr_out[31:25]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .alu_op(alu_ctrl)
    );

endmodule