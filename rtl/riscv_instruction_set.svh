`ifndef RISCV_INSTRUCTION_SET_SVH
`define RISCV_INSTRUCTION_SET_SVH

////////////////////////////////////////////////////////////////
// Base instruction set opcodes
////////////////////////////////////////////////////////////////
`define RISCV_RV32I_OPCODE_ARITH        7'h33
`define RISCV_RV32I_OPCODE_ARITH_IMM    7'h13
`define RISCV_RV32I_OPCODE_LOAD         7'h03
`define RISCV_RV32I_OPCODE_STORE        7'h23
`define RISCV_RV32I_OPCODE_BRANCH       7'h63
`define RISCV_RV32I_OPCODE_JAL          7'h6F
`define RISCV_RV32I_OPCODE_JALR         7'h67
`define RISCV_RV32I_OPCODE_LUI          7'h37
`define RISCV_RV32I_OPCODE_AUIPC        7'h17
`define RISCV_RV32I_OPCODE_SYSTEM       7'h73

////////////////////////////////////////////////////////////////
// Arithmetic Instructions
////////////////////////////////////////////////////////////////
`define RISCV_RV32I_FUNCT3_ARITH_ADD    3'h0
`define RISCV_RV32I_FUNCT7_ARITH_SUB    7'h20
`define RISCV_RV32I_FUNCT3_ARITH_XOR    3'h4
`define RISCV_RV32I_FUNCT3_ARITH_OR     3'h6
`define RISCV_RV32I_FUNCT3_ARITH_AND    3'h7
`define RISCV_RV32I_FUNCT3_ARITH_SLL    3'h1
`define RISCV_RV32I_FUNCT3_ARITH_SRL    3'h5
`define RISCV_RV32I_FUNCT7_ARITH_SRA    7'h20
`define RISCV_RV32I_FUNCT3_ARITH_SLT    3'h2
`define RISCV_RV32I_FUNCT3_ARITH_SLTU   3'h3

////////////////////////////////////////////////////////////////
// Load/store instructions
////////////////////////////////////////////////////////////////
`define RISCV_RV32I_FUNCT3_LOAD_BYTE    3'h0
`define RISCV_RV32I_FUNCT3_LOAD_HALF    3'h1
`define RISCV_RV32I_FUNCT3_LOAD_WORD    3'h2
`define RISCV_RV32I_FUNCT3_LOAD_BYTEU   3'h4
`define RISCV_RV32I_FUNCT3_LOAD_HALFU   3'h5
`define RISCV_RV32I_FUNCT3_STORE_BYTE   3'h0
`define RISCV_RV32I_FUNCT3_STORE_HALF   3'h1
`define RISCV_RV32I_FUNCT3_STORE_WORD   3'h2

////////////////////////////////////////////////////////////////
// Branch instructions
////////////////////////////////////////////////////////////////
`define RISCV_RV32I_FUNCT3_BRANCH_BEQ   3'h0
`define RISCV_RV32I_FUNCT3_BRANCH_BNE   3'h1
`define RISCV_RV32I_FUNCT3_BRANCH_BLT   3'h4
`define RISCV_RV32I_FUNCT3_BRANCH_BGE   3'h5
`define RISCV_RV32I_FUNCT3_BRANCH_BLTU  3'h6
`define RISCV_RV32I_FUNCT3_BRANCH_BGEU  3'h7

////////////////////////////////////////////////////////////////
// System instructions
////////////////////////////////////////////////////////////////
`define RISCV_RV32I_FUNCT3_SYS_RET      3'h0
`define RISCV_RV32I_IMMI_SYS_MRET       12'h302
`define RISCV_RV32I_IMMI_SYS_WFI        12'h105
`define RISCV_RV32I_FUNCT3_SYS_CSRRW    3'h1
`define RISCV_RV32I_FUNCT3_SYS_CSRRS    3'h2
`define RISCV_RV32I_FUNCT3_SYS_CSRRC    3'h3
`define RISCV_RV32I_FUNCT3_SYS_CSRRWI   3'h5
`define RISCV_RV32I_FUNCT3_SYS_CSRRSI   3'h6
`define RISCV_RV32I_FUNCT3_SYS_CSRRCI   3'h7

////////////////////////////////////////////////////////////////
// Base instruction set formats
////////////////////////////////////////////////////////////////
`define RISCV_INSTR_OPCODE(__inst)      __inst[6:0]
`define RISCV_INSTR_RD(__inst)          __inst[11:7]
`define RISCV_INSTR_FUNCT3(__inst)      __inst[14:12]
`define RISCV_INSTR_RS1(__inst)         __inst[19:15]
`define RISCV_INSTR_RS2(__inst)         __inst[24:20]
`define RISCV_INSTR_FUNCT7(__inst)      __inst[31:25]
`define RISCV_INSTR_IMM_I(__inst)       __inst[31:20]
`define RISCV_INSTR_IMM_S(__inst)       {__inst[31:25], __inst[11:7]}
`define RISCV_INSTR_IMM_B(__inst)       {__inst[31], __inst[7], __inst[30:25], __inst[11:8], 1'b0}
`define RISCV_INSTR_IMM_U(__inst)       {__inst[31:12], 12'h000}
`define RISCV_INSTR_IMM_J(__inst)       {__inst[31], __inst[19:12], __inst[20], __inst[30:21], 1'b0}
`define RISCV_INSTR_UIMM4(__inst)       __inst[19:15]


`ifdef RISCV_ENABLE_RV32M
////////////////////////////////////////////////////////////////
// RV32M Multiplication extension
////////////////////////////////////////////////////////////////
// Multiply/Divide instructions are under opcode == RISCV_RV32I_OPCODE_ARITH with funct7 == RISCV_RV32M_FUNCT7_MULTIPLY
`define RISCV_RV32M_FUNCT7_MULTIPLY     7'h01
`define RISCV_RV32M_FUNCT3_MUL          3'h0
`define RISCV_RV32M_FUNCT3_MULH         3'h1
`define RISCV_RV32M_FUNCT3_MULSU        3'h2
`define RISCV_RV32M_FUNCT3_MULU         3'h3
`define RISCV_RV32M_FUNCT3_DIV          3'h4
`define RISCV_RV32M_FUNCT3_DIVU         3'h5
`define RISCV_RV32M_FUNCT3_REM          3'h6
`define RISCV_RV32M_FUNCT3_REMU         3'h7
`endif // RISCV_ENABLE_RV32M

`ifdef RISCV_ENABLE_RV32A
////////////////////////////////////////////////////////////////
// RV32A Atomic access extension
////////////////////////////////////////////////////////////////
// Multiply/Divide instructions are under opcode == RISCV_RV32A_OPCODE_ATOMIC with funct3 == RISCV_RV32A_FUNCT3_ATOMIC
`define RISCV_RV32A_OPCODE_ATOMIC       7'h2F
`define RISCV_RV32A_FUNCT3_ATOMIC       3'h2
`define RISCV_RV32A_FUNCT5_LRW          5'h02
`define RISCV_RV32A_FUNCT5_SCW          5'h03
`define RISCV_RV32A_FUNCT5_AMOSWAPW     5'h01
`define RISCV_RV32A_FUNCT5_AMOADDW      5'h00
`define RISCV_RV32A_FUNCT5_AMOANDW      5'h0C
`define RISCV_RV32A_FUNCT5_AMOORW       5'h0A
`define RISCV_RV32A_FUNCT5_AMOXORW      5'h04
`define RISCV_RV32A_FUNCT5_AMOMAXW      5'h14
`define RISCV_RV32A_FUNCT5_AMOMINW      5'h10

`define RISCV_INSTR_A_AQ(__inst)        __inst[26]
`define RISCV_INSTR_A_RL(__inst)        __inst[25]
`define RISCV_INSTR_A_FUNCT5(__inst)    __inst[31:27]
`endif // RISCV_ENABLE_RV32A

////////////////////////////////////////////////////////////////
// Exception cause codes
////////////////////////////////////////////////////////////////
`define RISCV_EXC_CAUSE_UNALIGNED_FETCH     8'h0
`define RISCV_EXC_CAUSE_FETCH_ACCESS        8'h1
`define RISCV_EXC_CAUSE_BAD_INSTRUCTION     8'h2
`define RISCV_EXC_CAUSE_BREAKPOINT          8'h3
`define RISCV_EXC_CAUSE_UNALIGNED_LOAD      8'h4
`define RISCV_EXC_CAUSE_LOAD_ACCESS         8'h5
`define RISCV_EXC_CAUSE_UNALIGNED_STORE     8'h6
`define RISCV_EXC_CAUSE_STORE_ACCESS        8'h7
`define RISCV_EXC_CAUSE_USER_ECALL          8'h8
`define RISCV_EXC_CAUSE_MACHINE_ECALL       8'hB

`endif // RISCV_INSTRUCTION_SET_SVH
