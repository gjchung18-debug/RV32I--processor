`timescale 1ns/1ps;

module tb_pipelined;

    logic clk;
    logic rst;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
    end

    always #5 clk = ~clk;

    pipelined dut(
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_pipelined);
    end

    task automatic check_ans(int register_num, logic [31:0] true_value, string test_name);

        begin
            logic [31:0] register_value;
            register_value = dut.register_file_inst.regfile[register_num];

            assert(register_value === true_value)
            else $error("Failed! Register number: %d, True value: 0x%h, Register value: 0x%h, Test: %s", register_num, true_value, register_value, test_name);
        end

    endtask

    initial begin
        @(posedge clk) #1;
        rst = 1'b0;

        repeat (3) @(posedge clk);

        @(posedge clk); #1;
        check_ans(1, 32'h0000_0000, "Cycle 4: Check x1 (x1 = 0)");

        @(posedge clk); #1; check_ans(1,  32'h0000_0005, "Cycle 5: addi x1 = 5");
        @(posedge clk); #1; check_ans(2,  32'hFFFF_FFFD, "Cycle 6: addi x2 = -3");
        @(posedge clk); #1; check_ans(3,  32'h0000_0002, "Cycle 7: add x3 = 2 (fwd EX/MEM + MEM/WB)");
        @(posedge clk); #1; check_ans(4,  32'h0000_0008, "Cycle 8: sub x4 = 8 (fwd)");
        @(posedge clk); #1; check_ans(5,  32'h0000_0005, "Cycle 9: and x5 = 5");
        @(posedge clk); #1; check_ans(6,  32'hFFFF_FFFD, "Cycle 10: or x6");
        @(posedge clk); #1; check_ans(7,  32'hFFFF_FFF8, "Cycle 11: xor x7");
        @(posedge clk); #1; check_ans(8,  32'h0000_0001, "Cycle 12: slt x8 = 1 (signed -3 < 5)");
        @(posedge clk); #1; check_ans(9,  32'h0000_0000, "Cycle 13: sltu x9 = 0 (unsigned)");
        @(posedge clk); #1; check_ans(10, 32'h0000_0001, "Cycle 14: slti x10 = 1");
        @(posedge clk); #1; check_ans(11, 32'h0000_0001, "Cycle 15: sltiu x11 = 1 (5 < 0xFFFFFFFF)");
        @(posedge clk); #1; check_ans(12, 32'h0000_00A0, "Cycle 16: sll x12 = 5<<5");
        @(posedge clk); #1; check_ans(13, 32'h07FF_FFFF, "Cycle 17: srl x13");
        @(posedge clk); #1; check_ans(14, 32'hFFFF_FFFF, "Cycle 18: sra x14");
        @(posedge clk); #1; check_ans(15, 32'h0000_0050, "Cycle 19: slli x15");
        @(posedge clk); #1; check_ans(16, 32'h0FFF_FFFF, "Cycle 20: srli x16");
        @(posedge clk); #1; check_ans(17, 32'hFFFF_FFFF, "Cycle 21: srai x17");
        @(posedge clk); #1; check_ans(18, 32'hFFFF_FFFA, "Cycle 22: xori x18");
        @(posedge clk); #1; check_ans(19, 32'h0000_0075, "Cycle 23: ori x19");
        @(posedge clk); #1; check_ans(20, 32'h0000_00FD, "Cycle 24: andi x20");
        @(posedge clk); #1; check_ans(21, 32'h1234_5000, "Cycle 25: lui x21");
        @(posedge clk); #1; check_ans(22, 32'h0000_1054, "Cycle 26: auipc x22 = 0x1000 + PC(0x54)");
        @(posedge clk); #1; check_ans(23, 32'h0000_0040, "Cycle 27: addi x23 = 0x40");
        @(posedge clk); #1; check_ans(24, 32'h8081_F000, "Cycle 28: lui x24");
        @(posedge clk); #1; check_ans(24, 32'h8081_F2F3, "Cycle 29: addi x24 (fwd from lui)");
        @(posedge clk); #1; // Cycle 30: sw x24,0(x23) (no reg result)
        @(posedge clk); #1; check_ans(25, 32'h8081_F2F3, "Cycle 31: lw x25 (sw->lw same addr)");
        @(posedge clk); #1; check_ans(26, 32'hFFFF_FFF3, "Cycle 32: lb x26 sign-ext");
        @(posedge clk); #1; check_ans(27, 32'h0000_00F3, "Cycle 33: lbu x27 zero-ext");
        @(posedge clk); #1; check_ans(28, 32'hFFFF_F2F3, "Cycle 34: lh x28 sign-ext");
        @(posedge clk); #1; check_ans(29, 32'h0000_F2F3, "Cycle 35: lhu x29 zero-ext");
        @(posedge clk); #1; check_ans(30, 32'hFFFF_FF80, "Cycle 36: lb x30 byte3 = 0x80");
        @(posedge clk); #1; check_ans(31, 32'h0000_0081, "Cycle 37: lbu x31 byte2 = 0x81");

        repeat (93) @(posedge clk); #1;   // now ~cycle 130, CPU parked in jal x0,0

        check_ans(0,  32'h0000_0000, "x0 stays 0 after addi x0,x0,5");
        check_ans(1,  32'h8081_F2F3, "lw x1");
        check_ans(2,  32'h0103_E5E6, "load-use stall: add x2 = x1+x1");
        check_ans(3,  32'h8081_F2F3, "lw x3");
        check_ans(4,  32'h8081_F2F3, "load-use->sw->lw round trip x4");
        check_ans(5,  32'h0000_0007, "x5 = 7");
        check_ans(6,  32'h0000_0007, "x6 = 7");
        check_ans(7,  32'h0000_0000, "beq taken: wrong-path addi x7 flushed");
        check_ans(8,  32'h0000_0001, "bne not taken: next instr executes");
        check_ans(9,  32'hFFFF_FFFF, "x9 = -1");
        check_ans(10, 32'h0000_0001, "x10 = 1");
        check_ans(11, 32'h0000_0000, "blt (signed) taken: x11 flushed");
        check_ans(12, 32'h0000_0001, "bltu not taken: x12 executes");
        check_ans(13, 32'h0000_0000, "bgeu taken: x13 flushed");
        check_ans(14, 32'h0000_0000, "bge taken: x14 flushed");
        check_ans(15, 32'h0000_00F8, "jal link = PC(0xF4)+4");
        check_ans(16, 32'h0000_0000, "jal: x16 flushed");
        check_ans(17, 32'hFFFF_FFFF, "x17 untouched since srai");
        check_ans(18, 32'h0000_00FC, "auipc x18 = PC 0xFC");
        check_ans(19, 32'h0000_0104, "jalr link = 0x104");
        check_ans(20, 32'h0000_0000, "jalr: x20 flushed");
        check_ans(21, 32'h0000_0000, "add x21 = x0+x0");
        check_ans(22, 32'h0000_0000, "loop counter reached 0");
        check_ans(23, 32'h0000_0040, "x23 base unchanged");
        check_ans(24, 32'h8081_F2F3, "x24 unchanged");
        check_ans(25, 32'h0000_0006, "loop ran 3x: x25 = 6 (backward bne taken twice)");
        check_ans(26, 32'h8081_F2F3, "lw x26");
        check_ans(27, 32'h0000_0000, "lw->beq load-use branch: x27 flushed");
        check_ans(28, 32'h0000_FFFF, "sh then lhu x28");
        check_ans(29, 32'hFFFF_FFFF, "x29 = -1");
        check_ans(30, 32'hFFFF_FF00, "sw 0, sb @+1, sh @+2 -> lw x30");
        check_ans(31, 32'hFFFF_FFFF, "lb x31 of 0xFF byte (sign-ext)");

        $finish;
     end

endmodule
