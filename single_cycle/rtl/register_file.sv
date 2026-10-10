module register_file (
    input logic clk,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic [31:0] rd_data,
    input logic reg_write,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    logic [31:0] regfile [0:31]; // 32 registers each worth 32 bits

    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : ((rs1_addr == rd_addr) && reg_write) ? rd_data : regfile[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : ((rs2_addr == rd_addr) && reg_write) ? rd_data : regfile[rs2_addr];

    initial begin
        for(int i = 0; i < 32; i++) begin
            regfile[i] = '0;
        end
    end

    always_ff @(posedge clk) begin
        if(reg_write) begin
            if(rd_addr == 0) begin
                regfile[rd_addr] <= '0;
            end
            else begin
            regfile[rd_addr] <= rd_data;
            end
        end
    end


endmodule 
