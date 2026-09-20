module data_mem (
    input logic clk,
    input logic [31:0] addr,
    input logic [31:0] write_data,
    input logic mem_read,
    input logic mem_write,
    input logic [2:0] funct3, //for byte/half/word size
    output logic [31:0] read_data
);

    logic [7:0] mem [0:1023]; // packed 8 bit so we can directly access byte

    // write or store
    always_ff @(posedge clk) begin
        if(mem_write) begin
            case(funct3)
            3'b000: mem[addr] <= write_data[7:0]; //store byte
            3'b001: begin
                mem[addr] <= write_data[7:0];
                mem[addr + 1] <= write_data[15:8];
            end
            3'b010: begin
                mem[addr] <= write_data[7:0];
                mem[addr + 1] <= write_data[15:8];
                mem[addr + 2] <= write_data[23:16];
                mem[addr + 3] <= write_data[31:24];
            end

            endcase
        end
    end

    // load or read
    always_comb begin
        if(mem_read) begin
            case(funct3)
            3'b000: read_data = $signed(mem[addr]);
            3'b100: read_data = mem[addr];
            3'b001: begin
                read_data[7:0] = mem[addr];
                read_data[15:8] = mem[addr + 1];
                read_data[31:16] = {16{read_data[15]}};
            end
            3'b101: begin
                read_data[7:0] = mem[addr];
                read_data[15:8] = mem[addr + 1];
                read_data[31:16] = {16{1'b0}};
            end
            3'b010: begin
                read_data[7:0] = mem[addr];
                read_data[15:8] = mem[addr + 1];
                read_data[23:16] = mem[addr + 2];
                read_data[31:24] = mem[addr + 3];
            end
            endcase
        end
        else begin
            read_data = '0;
        end
    end

endmodule
