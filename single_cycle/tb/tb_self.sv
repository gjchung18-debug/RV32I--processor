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

        @(posedge clk); #1;
        rst = 1'b0;

        // 1. AUIPC Check
        @(posedge clk); #1;
        check_answer(2, 32'h00800000, "AUIPC: PC relative address");
        
        // 2. LUI Check
        @(posedge clk); #1;
        check_answer(1, 32'h12345000, "LUI: Upper 20-bit immediate");

        // 3. SW Execution (Cycle N)
        @(posedge clk); #1;

        // 4. LW Execution (Cycle N+1) -> Wait 1 additional cycle for Register Write-back
        @(posedge clk); #1;
        @(posedge clk); #1;
        check_answer(6, 32'h00800000, "LW: Correct data loaded from memory into x6");

        // 5. ADD Execution
        @(posedge clk); #1;

        // 6. BEQ Branch Taken Check
        @(posedge clk); #1; 
        check_answer(3, 32'h00800000, "Branch: BEQ Taken check");

        // Delay across BNE Not-Taken branch skip logic
        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        // 7. JAL Check (Wait 2 cycles for register write-back)
        @(posedge clk); #1;
        @(posedge clk); #1;
        check_answer(4, 32'h00000028, "JAL: Correct return address (PC+4)"); // PC shifted by +4 due to inserted LW

        // 8. JALR Check (Wait 2 cycles for register write-back)
        @(posedge clk); #1;
        @(posedge clk); #1;
        check_answer(5, 32'h00000030, "JALR: Correct return address (PC+4)"); // PC shifted by +4 due to inserted LW

        @(posedge clk); 
        #1;
        $display("Error count = %d", error_count);

        $finish;
    end
endmodule