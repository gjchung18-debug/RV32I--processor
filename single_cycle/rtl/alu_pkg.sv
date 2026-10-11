package alu_pkg;
    typedef enum logic [3:0] {
        ADD = 4'd0,
        SUB = 4'd1,
        AND = 4'd2,
        OR = 4'd3,
        XOR = 4'd4,
        SLL = 4'd5, // shift left logical
        SRL = 4'd6, // shift right logical
        SRA = 4'd7, // shift right arithmetic
        SLT = 4'd8, // set less than
        SLTU = 4'd9, // set less than unsinged
        LUI = 4'd10 // load upper immediate
    } alu_op_t;
endpackage
