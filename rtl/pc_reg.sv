module pc_reg (
    input logic clk,
    input logic rst,
    input logic [31:0] pc_next,
    output logic [31:0] pc_curr
);

    always_ff @(posedge clk) begin
        if(rst) begin
            pc_curr <= '0;
        end
        else begin
            pc_curr <= pc_next;
        end
    end



endmodule
