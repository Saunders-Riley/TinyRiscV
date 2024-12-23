`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_writeback_unit (
    // Core signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    input   logic       pipe_stall_in,
    // Upstream instruction interface
    input   logic[31:0] mem_pcaddr_in,
    input   logic[31:0] mem_instr_in,
    input   logic[31:0] mem_res_in,
    input   logic[31:0] mem_byp_in,
    // Writeback interface
    output  logic[11:0] wb_rd1_sel,
    output  logic[31:0] wb_rd1_data,
    output  logic       wb_rd1_wren,
    output  logic[4:0]  wb_rd2_sel,
    output  logic[31:0] wb_rd2_data,
    output  logic       wb_rd2_wren,
);

    wire[31:0]      pl_wb_instr      = mem_instr_in;
    wire[31:0]      pl_wb_pcaddr     = mem_pcaddr_in;
    wire[6:0]       pl_wb_funct7     = pl_wb_instr[31:25];
    wire[4:0]       pl_wb_rs2        = pl_wb_instr[24:20];
    wire[4:0]       pl_wb_rs1        = pl_wb_instr[19:15];
    wire[2:0]       pl_wb_funct3     = pl_wb_instr[14:12];
    wire[4:0]       pl_wb_rd         = pl_wb_instr[11:7];
    wire[6:0]       pl_wb_opcode     = pl_wb_instr[6:0];
    wire[11:0]      pl_wb_imm_I      = pl_wb_instr[31:20];
    wire[11:0]      pl_wb_imm_S      = {pl_wb_funct7, pl_wb_rd};
    wire[12:0]      pl_wb_imm_B      = {pl_wb_funct7[6], pl_wb_rd[0], pl_wb_funct7[5:0], pl_wb_rd[4:1], 1'b0};
    wire[19:0]      pl_wb_imm_U      = pl_wb_instr[31:12];
    wire[31:0]      pl_wb_imm_J      = {pl_wb_imm_U[19] ? 11'h7FF : 11'h000, pl_wb_imm_U[19], pl_wb_imm_U[7:0], pl_wb_imm_U[8], pl_wb_imm_U[18:9], 1'b0};


    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_writeback_unit
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
                case (pl_wb_opcode)
                    `RISCV_RV32I_OPCODE_ARITH,
                    `RISCV_RV32I_OPCODE_ARITH_IMM,
                    `RISCV_RV32I_OPCODE_LOAD,
                    `RISCV_RV32I_OPCODE_LUI,
                    `RISCV_RV32I_OPCODE_AUIPC : begin
                        wb_rd1_sel      <= {7'h00, pl_wb_rd};
                        wb_rd1_data     <= mem_res_in;
                        wb_rd1_wren     <= 1;
                        wb_rd2_sel      <= 5'h00;
                        wb_rd2_data     <= 32'h0000_0000;
                        wb_rd2_wren     <= 0;
                    end
                    `RISCV_RV32I_OPCODE_JAL,
                    `RISCV_RV32I_OPCODE_JAL_REG : begin
                        wb_rd1_sel      <= {7'h00, pl_wb_rd};
                        wb_rd1_data     <= mem_byp_in;
                        wb_rd1_wren     <= 1;
                        wb_rd2_sel      <= 5'h00;
                        wb_rd2_data     <= 32'h0000_0000;
                        wb_rd2_wren     <= 0;
                    end
                    `RISCV_RV32I_OPCODE_SYSTEM : begin
                        wb_rd1_sel      <= pl_wb_imm_I;
                        wb_rd1_data     <= mem_res_in;
                        wb_rd1_wren     <= 1;
                        wb_rd2_sel      <= pl_wb_rd;
                        wb_rd2_data     <= mem_byp_in;
                        wb_rd2_wren     <= 1;
                    end
                    default: begin
                        wb_rd1_sel      <= 12'h000;
                        wb_rd1_data     <= 32'h0000_0000;
                        wb_rd1_wren     <= 0;
                        wb_rd2_sel      <= 5'h00;
                        wb_rd2_data     <= 32'h0000_0000;
                        wb_rd2_wren     <= 0;
                    end
                endcase
            end
        end else begin
            wb_rd1_sel      <= 12'h000;
            wb_rd1_data     <= 32'h0000_0000;
            wb_rd1_wren     <= 0;
            wb_rd2_sel      <= 5'h00;
            wb_rd2_data     <= 32'h0000_0000;
            wb_rd2_wren     <= 0;
        end    
    end

endmodule
