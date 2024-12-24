`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_decode_unit (
    // Core signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    input   logic       pipe_stall_in,
    input   logic       pipe_flush_in,
    // Upstream instruction interface
    input   logic[31:0] fetch_pcaddr_in,
    input   logic[31:0] fetch_instr_in,
    input   logic[1:0]  fetch_spec_in,
    // Downstream instruction interface
    output  logic[31:0] dec_pcaddr_out,
    output  logic[31:0] dec_instr_out,
    output  logic[1:0]  dec_spec_out,
    output  logic[31:0] dec_op1_out,
    output  logic[31:0] dec_op2_out,
    output  logic[31:0] dec_op3_out,
    // Sideband interface - execution stage
    input   logic[31:0] exec_instr_in,
    input   logic[31:0] exec_res_in,
    input   logic[31:0] exec_byp_in,
    // Sideband interface - memory stage
    input   logic[31:0] mem_instr_in,
    input   logic[31:0] mem_res_in,
    input   logic[31:0] mem_byp_in,
    // Writeback interface
    input   logic[11:0] wb_rd1_sel,
    input   logic[31:0] wb_rd1_data,
    input   logic       wb_rd1_wren,
    input   logic[4:0]  wb_rd2_sel,
    input   logic[31:0] wb_rd2_data,
    input   logic       wb_rd2_wren,
);

    wire[31:0]      pl_fetch_instr      = fetch_instr_in;
    wire[31:0]      pl_fetch_pcaddr     = fetch_pcaddr_in;
    wire[6:0]       pl_fetch_funct7     = pl_fetch_instr[31:25];
    wire[4:0]       pl_fetch_rs2        = pl_fetch_instr[24:20];
    wire[4:0]       pl_fetch_rs1        = pl_fetch_instr[19:15];
    wire[2:0]       pl_fetch_funct3     = pl_fetch_instr[14:12];
    wire[4:0]       pl_fetch_rd         = pl_fetch_instr[11:7];
    wire[6:0]       pl_fetch_opcode     = pl_fetch_instr[6:0];
    wire[11:0]      pl_fetch_imm_I      = pl_fetch_instr[31:20];
    wire[11:0]      pl_fetch_imm_S      = {pl_fetch_funct7, pl_fetch_rd};
    wire[12:0]      pl_fetch_imm_B      = {pl_fetch_funct7[6], pl_fetch_rd[0], pl_fetch_funct7[5:0], pl_fetch_rd[4:1], 1'b0};
    wire[19:0]      pl_fetch_imm_U      = pl_fetch_instr[31:12];
    wire[31:0]      pl_fetch_imm_J      = {pl_fetch_imm_U[19] ? 11'h7FF : 11'h000, pl_fetch_imm_U[19], pl_fetch_imm_U[7:0], pl_fetch_imm_U[8], pl_fetch_imm_U[18:9], 1'b0};

    wire[31:0]      rs1_data;
    wire[31:0]      rs2_data;

    wire            fwd_op1_exec        = ((exec_instr_in[6:0] != `RISCV_RV32I_OPCODE_STORE) && (exec_instr_in[6:0] != `RISCV_RV32I_OPCODE_BRANCH) && (pl_fetch_rs1 == exec_instr_in[11:7])) ? 1 : 0;
    wire            fwd_op2_exec        = ((exec_instr_in[6:0] != `RISCV_RV32I_OPCODE_STORE) && (exec_instr_in[6:0] != `RISCV_RV32I_OPCODE_BRANCH) && (pl_fetch_rs2 == exec_instr_in[11:7])) ? 1 : 0;
    wire            fwd_op1_mem         = ((mem_instr_in[6:0] != `RISCV_RV32I_OPCODE_STORE) && (mem_instr_in[6:0] != `RISCV_RV32I_OPCODE_BRANCH) && (pl_fetch_rs1 == mem_instr_in[11:7])) ? 1 : 0;
    wire            fwd_op2_mem         = ((mem_instr_in[6:0] != `RISCV_RV32I_OPCODE_STORE) && (mem_instr_in[6:0] != `RISCV_RV32I_OPCODE_BRANCH) && (pl_fetch_rs2 == mem_instr_in[11:7])) ? 1 : 0;
    wire            fwd_op1_wb_rd1      = (pl_fetch_opcode == `RISCV_RV32I_OPCODE_SYSTEM) ?
                                                ((rd1_sel[11:0] == pl_fetch_imm_I) ? wb_rd1_wren : 0) :
                                                ((rd1_sel[4:0] == pl_fetch_rs1) ? wb_rd1_wren : 0);
    wire            fwd_op1_wb_rd2      = (rd2_sel == pl_fetch_rs1) ? wb_rd2_wren : 0;
    wire            fwd_op2_wb_rd1      = ((rd1_sel[11:5] == 7'h00) && rd1_sel[4:0] == pl_fetch_rs2) ? wb_rd1_wren : 0;
    wire            fwd_op2_wb_rd2      = (rd2_sel == pl_fetch_rs2) ? wb_rd2_wren : 0;

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_decode_unit_pl
        if(cpu_resetn) begin
            if(pipe_flush_in) begin
                dec_pcaddr_out  <= 32'h0000_0000;
                dec_instr_out   <= `RISCV_RV32I_INSTR_NOP;
                dec_spec_out    <= 2'b00;
                dec_op1_out     <= 32'h0000_0000;
                dec_op2_out     <= 32'h0000_0000;
                dec_op3_out     <= 32'h0000_0000;
            end else if(~pipe_stall_in) begin
                dec_pcaddr_out  <= fetch_pcaddr_in;
                dec_instr_out   <= fetch_instr_in;
                dec_spec_out    <= fetch_spec_in;
                case(pl_fetch_opcode)
                // Arithmetic operations
                // op1 - arithmetic operand 1
                // op2 - arithmetic operand 2
                // op3 - (unused)
                `RISCV_RV32I_OPCODE_ARITH:      begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  (fwd_op2_exec) ? exec_res_in :
                                        (fwd_op2_mem) ? mem_res_in :
                                        (fwd_op2_wb_rd1) ? wb_rd1_data :
                                        (fwd_op2_wb_rd2) ? wb_rd2_data :
                                        rs2_data;
                    dec_op3_out     <=  32'h0000_0000;
                end
                // Arithmetic operations with immediate
                // op1 - arithmetic operand 1 (register)
                // op2 - arithmetic operand 2 (immediate)
                // op3 - (unused)
                `RISCV_RV32I_OPCODE_ARITH_IMM:  begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  pl_fetch_imm_I;
                    dec_op3_out     <=  32'h0000_0000;
                end
                // Load operations
                // op1 - memory base address
                // op2 - memory offset
                // op3 - (unused)
                `RISCV_RV32I_OPCODE_LOAD:       begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  pl_fetch_imm_I;
                    dec_op3_out     <=  32'h0000_0000;
                end
                // Store operations
                // op1 - memory base address
                // op2 - memory offset
                // op3 - store data
                `RISCV_RV32I_OPCODE_STORE:      begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  pl_fetch_imm_S;
                    dec_op3_out     <=  (fwd_op2_exec) ? exec_res_in :
                                        (fwd_op2_mem) ? mem_res_in :
                                        (fwd_op2_wb_rd1) ? wb_rd1_data :
                                        (fwd_op2_wb_rd2) ? wb_rd2_data :
                                        rs2_data;
                end
                // Branch operations
                // op1 - comparison operand 1
                // op2 - comparison operand 2
                // op3 - branch offset
                `RISCV_RV32I_OPCODE_BRANCH:     begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  (fwd_op2_exec) ? exec_res_in :
                                        (fwd_op2_mem) ? mem_res_in :
                                        (fwd_op2_wb_rd1) ? wb_rd1_data :
                                        (fwd_op2_wb_rd2) ? wb_rd2_data :
                                        rs2_data;
                    dec_op3_out     <=  pl_fetch_imm_B;
                end
                // PC-relative jump operation
                // op1 - (unused)
                // op2 - (unused)
                // op3 - link address
                `RISCV_RV32I_OPCODE_JAL:        begin
                    // This is a bit of a special case since it was already handled upstream
                    // in the fetch unit, but the link address still needs to make it through
                    // the pipeline and into rd at the correct timing. Nothing otherwise
                    // happens downstream for a JAL.
                    dec_op1_out     <=  32'h0000_0000;
                    dec_op2_out     <=  32'h0000_0000;
                    dec_op3_out     <=  pl_fetch_pcaddr + 4;
                end
                // Indirect jump operation
                // op1 - jump base
                // op2 - jump offset
                // op3 - link address
                `RISCV_RV32I_OPCODE_JAL_REG:    begin
                    dec_op1_out     <=  (fwd_op1_exec) ? exec_res_in :
                                        (fwd_op1_mem) ? mem_res_in :
                                        (fwd_op1_wb_rd1) ? wb_rd1_data :
                                        (fwd_op1_wb_rd2) ? wb_rd2_data :
                                        rs1_data;
                    dec_op2_out     <=  pl_fetch_imm_J;
                    dec_op3_out     <=  pl_fetch_pcaddr + 4;
                end
                `RISCV_RV32I_OPCODE_LUI:        begin
                    dec_op1_out     <=  32'h0000_0000;
                    dec_op2_out     <=  pl_fetch_imm_U;
                    dec_op3_out     <=  32'h0000_0000;
                end
                `RISCV_RV32I_OPCODE_AUIPC:      begin
                    dec_op1_out     <=  pl_fetch_pcaddr;
                    dec_op2_out     <=  pl_fetch_imm_U;
                    dec_op3_out     <=  32'h0000_0000;
                end
                `RISCV_RV32I_OPCODE_SYSTEM:     begin
                // TODO - implement system instructions
                end
                default:
                // TODO - implement bad instruction exception
                endcase
            end
        end else begin
            dec_pcaddr_out  <= 32'h0000_0000;
            dec_instr_out   <= `RISCV_RV32I_INSTR_NOP;
            dec_spec_out    <= 2'b00;
            dec_op1_out     <= 32'h0000_0000;
            dec_op2_out     <= 32'h0000_0000;
            dec_op3_out     <= 32'h0000_0000;
        end
    end

    tinyriscv_cpu_register_file inst_tinyriscv_cpu_register_file (
        .cpu_clk    ( cpu_clk ),
        .cpu_resetn ( cpu_resetn ),
        .rs1_sel    ( pl_fetch_rs1 ),
        .rs1_data   ( rs1_data ),
        .rs2_sel    ( pl_fetch_rs2 ),
        .rs2_data   ( rs2_data ),
        .rd1_sel    ( wb_rd1_sel ),
        .rd1_data   ( wb_rd1_data ),
        .rd1_wren   ( wb_rd1_wren ),
        .rd2_sel    ( wb_rd2_sel ),
        .rd2_data   ( wb_rd2_data ),
        .rd2_wren   ( wb_rd2_wren )
    );

endmodule

module tinyriscv_cpu_register_file #(
    parameter MISA_DEFAULT = 32'h0000_0000,
    parameter MVENDORID_DEFAULT = 32'h0000_0000,
    parameter MARCHID_DEFAULT = 32'h0000_0000,
    parameter MIMPID_DEFAULT = 32'h0000_0000,
    parameter MHARTID_DEFAULT = 32'h0000_0000
) (
    // Core signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    // Read-side interface
    input   logic[11:0] rs1_sel,
    output  logic[31:0] rs1_data,
    input   logic[11:0] rs2_sel,
    output  logic[31:0] rs2_data,
    // Write-side interface
    input   logic[11:0] rd1_sel,
    input   logic[31:0] rd1_data,
    input   logic       rd1_wren,
    input   logic[4:0]  rd2_sel,
    input   logic[31:0] rd2_data,
    input   logic       rd2_wren
    // System Register Input/Outputs
    // TODO - system register lines
    // Exception handling
    input   logic[31:0] mepc_in,
    input   logic[31:0] mcause_in,
    input   logic[31:0] mtval_in,
    input   logic[31:0] mip_in,
    input   logic[31:0] mtinst_in,
    input   logic[31:0] mtval2_in,
    input   logic       exc_int_in,
    // NMI handling
    input   logic[31:0] mnepc_in,
    input   logic[31:0] mncause_in,
    input   logic[31:0] mnstatus_in,
    input   logic       nmi_in,
    // page 0x300 - machine status registers
    output  logic[63:0] mstatus_out,
    output  logic[31:0] medeleg_out,
    output  logic[31:0] mideleg_out,
    output  logic[31:0] mie_out,
    output  logic[31:0] mtvec_out,
    output  logic[31:0] mcounteren_out,
    // page 0xB00 - timer counter registers
    input   logic[63:0] mcycle_in,
    input   logic[63:0] minstret_in,
);
    integer i;
    logic[31:0]     core_registers[31:0];       ///< page 0x000 - core registers
    logic[31:0]     m_id_registers[21:17];      ///< page 0xF00 (0x78) [R/O] - machine id registers
    m_id_registers[17]  = MVENDORID_DEFAULT;
    m_id_registers[18]  = MARCHID_DEFAULT;
    m_id_registers[19]  = MIMPID_DEFAULT;
    m_id_registers[20]  = MHARTID_DEFAULT;
    m_id_registers[21]  = 32'hFFFF_FFFF;
    logic[31:0]     m_status_registers[6:0];    ///< page 0x300 (0x18) [R/W] - machine status registers
    logic[31:0]     m_statush_registers[18:16]; ///< page 0x300 (0x18) [R/W] - machine status registers (high bits)
    logic[31:0]     m_trap_registers[4:0];      ///< page 0x340 (0x1A) [R/W] - machine trap handling registers
    logic[31:0]     m_trap_registers_2[11:10];  ///< page 0x340 (0X1A) [R/W] - machine trap handling registers 2
    logic[31:0]     m_nmi_registers[4:0];       ///< page 0x740 (0x3A) [R/W] - machine NMI handling registers

    // Source Register 1 read
    always_comb begin : proc_tinyriscv_cpu_register_file_rs1_read
        case(rs1_sel[11:5])
            // TODO - system register pages
            7'h78:      rs1_data = m_id_registers[rs1_sel[4:0]];
            7'h18:      rs1_data = (rs1_sel[4]) ? m_statush_registers[rs1_sel[3:0]] : m_status_registers[rs1_sel[3:0]];
            7'h1A:      rs1_data = (rs1_sel > 9) ? m_trap_registers_2[rs1_sel[3:0]] : m_trap_registers[rs1_sel[3:0]];
            7'h00:      rs1_data = core_registers[rs1_sel[4:0]];
            default:    rs1_data = 32'h0000_0000;
        endcase
    end

    // Source Register 2 read
    always_comb begin : proc_tinyriscv_cpu_register_file_rs2_read
        case(rs2_sel[11:5])
            // TODO - system register pages
            7'h00:      rs2_data = core_registers[rs2_sel[4:0]];
            default:    rs2_data = 32'h0000_0000;
        endcase
    end

    // Destination Register writes
    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_register_file_write
        if(cpu_resetn) begin
            // Destination Register 1 write
            if(rd1_wren) begin
                case(rd1_sel[11:5])
                    // TODO - system register pages
                    7'h18:  begin
                        if(rd1_sel[4]) m_statush_registers[rd1_sel[3:0]] <= rd1_data;
                        else m_status_registers[rd1_sel[3:0]] <= rd1_data;
                    end
                    7'h1A:  begin
                        if(rd1_sel > 9) m_trap_registers_2[rd1_sel[3:0]] <= rd1_data;
                        else m_trap_registers[rd1_sel[3:0]] <= rd1_data;
                    end
                    7'h00:  core_registers[rd1_sel[4:0]] <= (rd1_sel[4:0] = 5'h00) ? 32'h0000_0000 : rd1_data;
                    default:    // do nothing
                endcase
            end
            // Destination register 2 write
            if(rd2_wren && rd1_sel[11:5] != 7'h00) begin
                core_registers[rd2_sel[4:0]] <= (rd2_sel[4:0] = 5'h00) ? 32'h0000_0000 : rd2_data;
            end
            // Exception/Interrupt register latch
            if(exc_int_in) begin
                m_trap_registers[1]     <= mepc_in;
                m_trap_registers[2]     <= mcause_in;
                m_trap_registers[3]     <= mtval_in;
                m_trap_registers[4]     <= mip_in;
                m_trap_registers_2[10]  <= mtinst_in;
                m_trap_registers_2[11]  <= mtval2_in;
            end
            // Non-Maskable Interrupt register latch
            if(nmi_in) begin
                m_nmi_registers[1]      <= mnepc_in;
                m_nmi_registers[2]      <= mncause_in;
                m_nmi_registers[4]      <= mnstatus_in; // TODO - is this an input?
            end
        end else begin
            // TODO - system register pages
            for(i = 0; i < 32; i = i + 1) core_registers[i] <= 32'h0000_0000;
        end
    end

endmodule