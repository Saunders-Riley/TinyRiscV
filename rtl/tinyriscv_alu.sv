`include "riscv_config.svh"
`include "riscv_instruction_set.svh"
`default_nettype wire

module tinyriscv_alu #(
    parameter XLEN = `RISCV_CONFIG_XLEN
) (
    // Control inputs
    logic[6:0]          opcode,
    logic[2:0]          funct3,
    logic[4:0]          funct7,
    // Operands
    logic[XLEN-1:0]     op_1,
    logic[XLEN-1:0]     op_2,
    logic[XLEN-1:0]     op_3,
    // Results
    logic[XLEN-1:0]     res,
    logic[XLEN-1:0]     byp,
    // Exception flag
    logic               exc
);

    always_comb begin : proc_tinyriscv_alu
        exc = 0;
        case (opcode)
            // Arithmetic operations [with immediate]
            // op_1 - arithmetic operand 1
            // op_2 - arithmetic operand 2
            // op_3 - unused
            `RISCV_RV32I_OPCODE_ARITH,
            `RISCV_RV32I_OPCODE_ARITH_IMM   : begin
                byp = 0;
                case (funct3)
                    `RISCV_RV32I_FUNCT3_ARITH_ADD   : begin
                        if(funct7 == `RISCV_RV32I_FUNCT7_ARITH_SUB)
                            res = op_1 + (~op_2 + 1);
                        else
                            res = op_1 + op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_XOR   : begin
                        res = op_1 ^ op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_OR    : begin
                        res = op_1 | op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_AND   : begin
                        res = op_1 & op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SLL   : begin
                        res = op_1 << op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SRL   : begin
                        if(funct7 == `RISCV_RV32I_FUNCT7_ARITH_SRA)
                            res = op_1 >>> op_2;
                        else
                            res = op_1 >> op_2;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SLT   : begin
                        res =   ((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 0)) ? 1 :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 1)) ? 0 :
                                ((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 1)) ? ((op_1[XLEN-2:0] < op_2[XLEN-2:0]) ? 1 : 0) :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 0)) ? ((op_1[XLEN-2:0] > op_2[XLEN-2:0]) ? 1 : 0) ;
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SLTU  : begin
                        res = (op_1 < op_2) ? 1 : 0;
                    end
                    default : exc = 1;
                endcase
            end
            // Load/store operations
            // op_1 - base address
            // op_2 - offset immediate
            // op_3 - passthrough (store data)
            `RISCV_RV32I_OPCODE_LOAD,
            `RISCV_RV32I_OPCODE_STORE       : begin
                res = op_1 + op_2;
                byp = op_3;
            end
            // Branch operations
            // op_1 - comparison operand 1
            // op_2 - comparison operand 2
            // op_3 - passthrough (branch offset)
            `RISCV_RV32I_OPCODE_BRANCH      : begin
                byp = op_3;
                case (funct3)
                    `RISCV_RV32I_FUNCT3_BRANCH_BEQ  : begin
                        res =   (op_1 == op_2) ? 1 : 0;
                    end
                    `RISCV_RV32I_FUNCT3_BRANCH_BNE  : begin
                        res =   ~((op_1 == op_2) ? 1 : 0);
                    end
                    `RISCV_RV32I_FUNCT3_BRANCH_BLT  : begin
                        res =   ((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 0)) ? 1 :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 1)) ? 0 :
                                ((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 1)) ? ((op_1[XLEN-2:0] < op_2[XLEN-2:0]) ? 1 : 0) :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 0)) ? ((op_1[XLEN-2:0] > op_2[XLEN-2:0]) ? 1 : 0) ;
                    end
                    `RISCV_RV32I_FUNCT3_BRANCH_BGE  : begin
                        res =   ~(((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 0)) ? 1 :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 1)) ? 0 :
                                ((op_1[XLEN-1] == 1) && (op_2[XLEN-1] == 1)) ? ((op_1[XLEN-2:0] < op_2[XLEN-2:0]) ? 1 : 0) :
                                ((op_1[XLEN-1] == 0) && (op_2[XLEN-1] == 0)) ? ((op_1[XLEN-2:0] > op_2[XLEN-2:0]) ? 1 : 0) );
                    end
                    `RISCV_RV32I_FUNCT3_BRANCH_BLTU : begin
                        res = (op_1 < op_2) ? 1 : 0;
                    end
                    `RISCV_RV32I_FUNCT3_BRANCH_BGEU : begin
                        res = ~((op_1 < op_2) ? 1 : 0);
                    end
                    default: 
                endcase
            end
            // Jump and link operations
            // op_1 - base address
            // op_2 - offset immediate
            // op_3 - passthrough (return address)
            `RISCV_RV32I_OPCODE_JAL,
            `RISCV_RV32I_OPCODE_JALR        : begin
                res = op_1 + op_2;
                byp = op_3;
            end
            // Load upper operations
            // op_1 - arithmetic operand 1
            // op_2 - arithmetic operand 2
            // op_3 - unused
            `RISCV_RV32I_OPCODE_LUI,
            `RISCV_RV32I_OPCODE_AUIPC       : begin
                res = op_1 + op_2;
                byp = 0;
            end
            `RISCV_RV32I_OPCODE_SYSTEM      : begin

            end
            default : exc = 1;
        endcase
    end
    
endmodule