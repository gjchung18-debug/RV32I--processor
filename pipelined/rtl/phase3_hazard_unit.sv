import alu_pkg::*;

module pipelined (
    input logic clk,
    input logic rst
);

    logic [31:0] pc_out, instr_out, imm_out, write_back_mux,
    rs1_out, rs2_out, alu_b_mux, alu_result, read_data, sequential_pc_adder, bj_target_adder, next_pc_mux;

    logic zero, mem_read, mem_write, reg_write, alu_src, mem_to_reg, branch, jump, branch_cond, jalr;

    alu_op_t alu_ctrl;

    // IF

    logic stall;
    logic flush;
    logic id_ex_jalr;
    logic id_ex_jump;

    pc_reg pc_reg_inst (
        .clk(clk),
        .rst(rst),
        .pc_next(next_pc_mux),
        .pc_curr(pc_out) // output
    );

    assign sequential_pc_adder = pc_out + 32'd4;

    always_comb begin
        if(id_ex_jalr) begin
            next_pc_mux = alu_result;
        end
        else if((branch_cond) || id_ex_jump) begin
            next_pc_mux = bj_target_adder;
        end
        else if(stall) begin
            next_pc_mux = pc_out;
        end
        else begin
            next_pc_mux = sequential_pc_adder;
        end
    end

    instr_mem instr_mem_inst (
        .addr(pc_out),
        .instr(instr_out) // output
    );

    // IF-ID register

    logic [31:0] if_id_instr_out;
    logic [31:0] mem_wb_instr_out;
    logic [31:0] if_id_pc_out;
    logic mem_wb_reg_write;

    always_ff @(posedge clk or posedge rst) begin
        if(rst || flush) begin
            if_id_instr_out <= '0;
            if_id_pc_out <= '0;
        end
        else if(stall) begin
            if_id_instr_out <= '0;
        end
        else begin
            if_id_instr_out <= instr_out;
            if_id_pc_out <= pc_out;
        end
    end

    // Stall

    assign stall = ((instr_out[6:0] != 7'b0100011) && (if_id_instr_out[6:0] == 7'b0000011) && ((if_id_instr_out[11:7] == instr_out[24:20]) || (if_id_instr_out[11:7] == instr_out[19:15])));

    // ID

    imm_gen imm_gen_inst(
        .instr(if_id_instr_out),
        .imm_out(imm_out) // output
    );

    register_file register_file_inst(
        .clk(clk),
        .rs1_addr(if_id_instr_out[19:15]),
        .rs2_addr(if_id_instr_out[24:20]),
        .rd_addr(mem_wb_instr_out[11:7]),
        .rd_data(write_back_mux),
        .reg_write(mem_wb_reg_write),
        .rs1_data(rs1_out), // output
        .rs2_data(rs2_out) // output
    );

    control_unit control_unit_inst(
        .opcode(if_id_instr_out[6:0]), // input
        .funct3(if_id_instr_out[14:12]), // input
        .funct7(if_id_instr_out[31:25]), // input
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

    // ID-EX register

    logic [31:0] id_ex_imm_out;
    logic [31:0] id_ex_rs1_out;
    logic [31:0] id_ex_rs2_out;
    logic [31:0] id_ex_instr_out;
    logic [31:0] id_ex_pc_out;
    logic id_ex_reg_write;
    logic id_ex_alu_src;
    logic id_ex_mem_read;
    logic id_ex_mem_write;
    logic id_ex_mem_to_reg;
    logic id_ex_branch;
    logic [3:0] id_ex_alu_ctrl;

    always_ff @(posedge clk or posedge rst) begin
        if(rst || flush) begin
            id_ex_imm_out <= '0;
            id_ex_rs1_out <= '0;
            id_ex_rs2_out <= '0;
            id_ex_instr_out <= '0;
            id_ex_reg_write <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;;
            id_ex_jalr <= 1'b0;;
            id_ex_alu_ctrl <= '0;
            id_ex_pc_out <= '0;
        end
        else begin
            id_ex_imm_out <= imm_out;
            id_ex_rs1_out <= rs1_out;
            id_ex_rs2_out <= rs2_out;
            id_ex_instr_out <= if_id_instr_out;
            id_ex_reg_write <= reg_write;
            id_ex_alu_src <= alu_src;
            id_ex_mem_read <= mem_read;
            id_ex_mem_write <= mem_write;
            id_ex_mem_to_reg <= mem_to_reg;
            id_ex_branch <= branch;
            id_ex_jump <= jump;
            id_ex_jalr <= jalr;
            id_ex_alu_ctrl <= alu_ctrl;
            id_ex_pc_out <= if_id_pc_out;
        end
    end

    // EX

    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] ex_mem_instr_out;
    logic [31:0] ex_mem_alu_result;
    logic ex_mem_reg_write;


    always_comb begin
        if((ex_mem_instr_out[11:7] == id_ex_instr_out[19:15]) && (ex_mem_instr_out[11:7] != 5'd0) && ex_mem_reg_write) begin
            operand_a = ex_mem_alu_result;
        end
        else if((mem_wb_instr_out[11:7] == id_ex_instr_out[19:15]) && (mem_wb_instr_out[11:7] != 5'd0) && mem_wb_reg_write) begin
            operand_a = write_back_mux;
        end
        else begin
            operand_a = id_ex_rs1_out;
        end
    end

    always_comb begin
        if((ex_mem_instr_out[11:7] == id_ex_instr_out[24:20]) && (ex_mem_instr_out[11:7] != 5'd0) && ex_mem_reg_write) begin // 5'do to prevent forwarding calculated value rd to the next instruction like rs2 because it is hardwired to zero
            operand_b = ex_mem_alu_result;
        end
        else if((mem_wb_instr_out[11:7] == id_ex_instr_out[24:20]) && (mem_wb_instr_out[11:7] != 5'd0) && mem_wb_reg_write) begin
            operand_b = write_back_mux;
        end
        else begin
            operand_b = id_ex_rs2_out;
        end
    end

    assign alu_b_mux = id_ex_alu_src ? id_ex_imm_out : operand_b;

    alu alu_inst(
        .a(operand_a),
        .b(alu_b_mux),
        .alu_ctrl(id_ex_alu_ctrl),
        .result(alu_result), // output
        .zero(zero) // output
    );

    assign bj_target_adder = id_ex_pc_out + id_ex_imm_out;

    logic [31:0] ex_alu_result;

    assign ex_alu_result = (id_ex_instr_out[6:0] == 7'b0010111) ? bj_target_adder : alu_result; // first one is auipc

    logic raw_branch_cond;

    always_comb begin
        case (id_ex_instr_out[14:12])
            3'b000:  raw_branch_cond = zero;
            3'b001:  raw_branch_cond = ~zero;
            3'b100:  raw_branch_cond = alu_result[0];
            3'b110:  raw_branch_cond = alu_result[0];
            3'b101:  raw_branch_cond = ~alu_result[0];
            3'b111:  raw_branch_cond = ~alu_result[0];
            default: raw_branch_cond = 1'b0;
        endcase
    end

    assign branch_cond = id_ex_branch && raw_branch_cond;

    assign flush = id_ex_jalr || branch_cond || id_ex_jump;

    // EX-MEM register

    logic ex_mem_mem_to_reg;
    logic ex_mem_mem_read;
    logic ex_mem_mem_write;
    logic [31:0] ex_mem_rs2_out;
    logic [31:0] ex_mem_pc_out;
    logic ex_mem_jump;
    logic ex_mem_jalr;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            ex_mem_reg_write <= 1'b0;
            ex_mem_pc_out <= '0;
            ex_mem_mem_to_reg <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_alu_result <= '0;
            ex_mem_rs2_out <= '0;
            ex_mem_instr_out <= '0;
            ex_mem_jump <= 1'b0;
            ex_mem_jalr <= 1'b0;
        end
        else begin
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_rs2_out <= operand_b;
            ex_mem_instr_out <= id_ex_instr_out;
            ex_mem_jump <= id_ex_jump;
            ex_mem_jalr <= id_ex_jalr;
            ex_mem_pc_out <= id_ex_pc_out;
        end
    end

    // MEM

    logic [31:0] write_data;
    logic [31:0] mem_wb_alu_result;

    // forwarding wb to mem (1 cycle apart)
    always_comb begin
        if((mem_wb_instr_out[11:7] == ex_mem_instr_out[24:20]) && mem_wb_reg_write && (mem_wb_instr_out[11:7] != 5'd0) && ex_mem_mem_write) begin
            write_data = write_back_mux;
        end
        else begin
            write_data = ex_mem_rs2_out;
        end
    end

    data_mem data_mem_inst(
        .clk(clk),
        .addr(ex_mem_alu_result),
        .write_data(write_data),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .funct3(ex_mem_instr_out[14:12]),
        .read_data(read_data) // output
    );

    // MEM-WB register

    logic mem_wb_mem_to_reg;
    logic [31:0] mem_wb_read_data;
    logic [31:0] mem_wb_pc_out;
    logic mem_wb_jump;
    logic mem_wb_jalr;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            mem_wb_reg_write <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
            mem_wb_alu_result <= '0;
            mem_wb_pc_out <= '0;
            mem_wb_read_data <= '0;
            mem_wb_instr_out <= '0;
            mem_wb_jump <= 1'b0;
            mem_wb_jalr <= 1'b0;
        end
        else begin
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_read_data <= read_data;
            mem_wb_instr_out <= ex_mem_instr_out;
            mem_wb_jump <= ex_mem_jump;
            mem_wb_jalr <= ex_mem_jalr;
            mem_wb_pc_out <= ex_mem_pc_out;
        end
    end

    // WB
            
    assign write_back_mux = (mem_wb_jump || mem_wb_jalr) ? (mem_wb_pc_out + 32'd4) : mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;

endmodule