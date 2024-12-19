`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_exec_unit (
    // Core signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    input   logic       pipe_stall_in,
    input   logic       pipe_flush_in,
    // Upstream instruction interface
    input   logic[31:0] dec_pcaddr_in,
    input   logic[31:0] dec_instr_in,
    input   logic[31:0] dec_op1_in,
    input   logic[31:0] dec_op2_in,
    input   logic[31:0] dec_op3_in,
    input   logic       dec_spec_in,
    // Downstream instruction interface
    output  logic[31:0] exec_pcaddr_out,
    output  logic[31:0] exec_instr_out,
    output  logic       exec_spec_out,
    output  logic[31:0] exec_res_out,
    output  logic[31:0] exec_byp_out,
);

    wire[31:0]      pl_dec_instr      = dec_instr_in;
    wire[31:0]      pl_dec_pcaddr     = dec_pcaddr_in;
    wire[6:0]       pl_dec_funct7     = pl_dec_instr[31:25];
    wire[4:0]       pl_dec_rs2        = pl_dec_instr[24:20];
    wire[4:0]       pl_dec_rs1        = pl_dec_instr[19:15];
    wire[2:0]       pl_dec_funct3     = pl_dec_instr[14:12];
    wire[4:0]       pl_dec_rd         = pl_dec_instr[11:7];
    wire[6:0]       pl_dec_opcode     = pl_dec_instr[6:0];
    wire[11:0]      pl_dec_imm_I      = pl_dec_instr[31:20];
    wire[11:0]      pl_dec_imm_S      = {pl_dec_funct7, pl_dec_rd};
    wire[12:0]      pl_dec_imm_B      = {pl_dec_funct7[6], pl_dec_rd[0], pl_dec_funct7[5:0], pl_dec_rd[4:1], 1'b0};
    wire[19:0]      pl_dec_imm_U      = pl_dec_instr[31:12];
    wire[31:0]      pl_dec_imm_J      = {pl_dec_imm_U[19] ? 11'h7FF : 11'h000, pl_dec_imm_U[19], pl_dec_imm_U[7:0], pl_dec_imm_U[8], pl_dec_imm_U[18:9], 1'b0};

    wire[31:0]      alu_result;
    wire[31:0]      alu_bypass;

    always_ff @( posedge_cpu_clock, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_exec_unit_pl
        if (cpu_resetn) begin
            if (pipe_flush) begin
                exec_pcaddr_out     <= 32'h0000_0000;
                exec_instr_out      <= `RISCV_RV32I_INSTR_NOP;
                exec_spec_out       <= 0;
                exec_res_out        <= 32'h0000_0000;
                exec_byp_out        <= 32'h0000_0000;
            end else begin
                if (~pipe_stall) begin
                    exec_pcaddr_out     <= dec_pcaddr_in;
                    exec_instr_out      <= dec_instr_in;
                    exec_spec_out       <= dec_spec_in;
                    exec_res_out        <= alu_result;
                    exec_byp_out        <= alu_bypass;
                end
            end
        end else begin
            exec_pcaddr_out     <= 32'h0000_0000;
            exec_instr_out      <= `RISCV_RV32I_INSTR_NOP;
            exec_spec_out       <= 0;
            exec_res_out        <= 32'h0000_0000;
            exec_byp_out        <= 32'h0000_0000;
        end
    end

    tinyriscv_cpu_alu inst_tinyriscv_cpu_alu (
        .opcode ( pl_dec_opcode ),
        .funct7 ( pl_dec_funct7 ),
        .funct3 ( pl_dec_funct3 ),
        .op1    ( dec_op1_in ),
        .op2    ( dec_op2_in ),
        .op3    ( dec_op3_in ),
        .res    ( alu_result ),
        .byp    ( alu_bypass ),
    );

endmodule

module tinyriscv_cpu_alu (
    input   logic[6:0]  opcode,
    input   logic[6:0]  funct7,
    input   logic[2:0]  funct3,
    input   logic[31:0] op1,
    input   logic[31:0] op2,
    input   logic[31:0] op3,
    output  logic[31:0] res,
    output  logic[31:0] byp,
);
    always_comb begin : proc_tinyriscv_cpu_alu_comb
        case (opcode)
            // Arithmetic operations
            // res - arithmetic result
            // byp - (unused)
            `RISCV_RV32I_OPCODE_ARITH,
            `RISCV_RV32I_OPCODE_ARITH_IMM   : begin
                case (funct3)
                    `RISCV_RV32I_FUNCT3_ARITH_ADD   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_XOR   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_OR    : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_AND   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_LSH   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_RSH   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SLT   : begin
                    end
                    `RISCV_RV32I_FUNCT3_ARITH_SLTU  : begin
                    end
                    default: 
                endcase
            end
            // Load/Store operations
            // res - memory address
            // byp - store data (if applicable)
            `RISCV_RV32I_OPCODE_LOAD,
            `RISCV_RV32I_OPCODE_STORE       : begin
            end
            // Branch operations
            // res - branch result
            // byp - branch offset
            `RISCV_RV32I_OPCODE_BRANCH      : begin
                case (funct3)
                    `RISCV_RV32I_FUNCT3_BEQ         : begin
                    end
                    `RISCV_RV32I_FUNCT3_BNE         : begin
                    end
                    `RISCV_RV32I_FUNCT3_BLT         : begin
                    end
                    `RISCV_RV32I_FUNCT3_BGE         : begin
                    end
                    `RISCV_RV32I_FUNCT3_BLTU        : begin
                    end
                    `RISCV_RV32I_FUNCT3_BGEU        : begin
                    end
                    default: 
                endcase
            end
            // Jump and Link operations
            // res - jump address
            // byp - link address
            `RISCV_RV32I_OPCODE_JAL,
            `RISCV_RV32I_OPCODE_JAL_REG     : begin
            end
            // Load upper operations
            // res - result
            // byp - (unused)
            `RISCV_RV32I_OPCODE_LUI,
            `RISCV_RV32I_OPCODE_AUIPC       : begin
            end
            // System operations
            // res - new system register value
            // byp - old system register value
            `RISCV_RV32I_OPCODE_SYSTEM      : begin
                // TODO - implement system instructions
            end
            default: begin
                // TODO - implement bad instruction exception
            end
        endcase 
    end
endmodule