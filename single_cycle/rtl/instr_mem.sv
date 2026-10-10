module instr_mem (
    input logic [31:0] addr,
    output logic [31:0] instr
);

    logic [31:0] mem [0:1023];

    initial begin

        for(int i = 0; i < 1024; i++) begin
            mem[i] = 32'd0;
        end
        $readmemh("tb/pipelined.hex", mem);
    end

    assign instr = mem[addr[31:2]];


endmodule

