`timescale 1ns/1ps; 

// 2nd try
module tb_self;

    logic clk;
    logic rst;
    int error_count;

    datapath dut (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        error_count = 0;
    end

    always #5 clk = ~clk;

    task automatic check_answer (input logic [4:0] register_number, input logic [31:0] actual_value, input string test_name);

    begin

        logic [31:0] calculated_value;
        calculated_value = dut.register_file_inst.regfile[register_number];

        /*if(calculated_value !== actual_value) begin
            $display("FAILED! REG%d = 0x%08h, ANSWER = 0x%08h, TEST = %s", register_number, calculated_value, actual_value, test_name);
            error_count++;
        end
        else begin
            $display("PASS!");
        end*/

        assert(calculated_value == actual_value) 
        else begin
            $error("FAILED! REG%d = 0x%08h, ANSWER = 0x%08h, TEST = %s", register_number, calculated_value, actual_value, test_name);
            error_count++;
        end

    end

    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_self);
    end

    initial begin

        @(posedge clk); // wait one time unit to avoid race time issue, so we can compare the updated calculated value in the current clock cycle with the actual value
        #1;
        rst = 1'b0;

        // Instr 1: addi x1, x0, -1
        @(posedge clk); #1;
        check_answer(1, 32'hFFFFFFFF, "Immediate Sign-Extension (-1 -> 0xFFFFFFFF)");

        // Instr 2: addi x2, x0, 2
        @(posedge clk); #1;
        check_answer(2, 32'h00000002, "Setup x2 = +2 (compare/shift operand)");

        // --- EDGE CASE: SLT vs SLTU on Negative Operand ---
        // Instr 3: slt x3, x1, x2 (signed: -1 < 2 -> true)
        @(posedge clk); #1;
        check_answer(3, 32'h00000001, "SLT Signed Comparison (-1 < 2 is True)");

        // Instr 4: sltu x4, x1, x2 (unsigned: 0xFFFFFFFF < 2 -> false)
        @(posedge clk); #1;
        check_answer(4, 32'h00000000, "SLTU Unsigned Comparison (4.29B < 2 is False)");

        // --- EDGE CASE: SRA vs SRL Sign-Extension on Negative Operand ---
        // Instr 5: srl x5, x1, x2 (logical: zero-fill, top 2 bits become 0)
        @(posedge clk); #1;
        check_answer(5, 32'h3FFFFFFF, "SRL Zero-Fill Shift Right (No Sign Extension)");

        // Instr 6: sra x6, x1, x2 (arithmetic: sign-fill, top 2 bits stay 1)
        @(posedge clk); #1;
        check_answer(6, 32'hFFFFFFFF, "SRA Sign-Preserving Shift Right");

        @(posedge clk); 
        #1;
        $display("Error count = %d", error_count);

        $finish;
    end
endmodule