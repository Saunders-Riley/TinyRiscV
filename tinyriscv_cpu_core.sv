`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_core #(
    parameter RESET_VECTOR = `TINYRISCV_RESET_VECTOR;
) (
    // Global signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    // AHB instruction memory interface
    input   logic       imem_m_ahb_hready,
    input   logic       imem_m_ahb_hresp,
    output  logic[31:0] imem_m_ahb_haddr,
    output  logic       imem_m_ahb_hwrite,
    output  logic[3:0]  imem_m_ahb_hwstrb,
    output  logic[1:0]  imem_m_ahb_htrans,
    output  logic[2:0]  imem_m_ahb_hsize,
    output  logic[2:0]  imem_m_ahb_hburst,
    output  logic[3:0]  imem_m_ahb_hprot,
    output  logic       imem_m_ahb_hmastlock,
    output  logic[31:0] imem_m_ahb_hwdata,
    input   logic[31:0] imem_m_ahb_hrdata,
    // AHB data memory interface
    input   logic       dmem_m_ahb_hready,
    input   logic       dmem_m_ahb_hresp,
    output  logic[31:0] dmem_m_ahb_haddr,
    output  logic       dmem_m_ahb_hwrite,
    output  logic[3:0]  dmem_m_ahb_hwstrb,
    output  logic[1:0]  dmem_m_ahb_htrans,
    output  logic[2:0]  dmem_m_ahb_hsize,
    output  logic[2:0]  dmem_m_ahb_hburst,
    output  logic[3:0]  dmem_m_ahb_hprot,
    output  logic       dmem_m_ahb_hmastlock,
    output  logic[31:0] dmem_m_ahb_hwdata,
    input   logic[31:0] dmem_m_ahb_hrdata,
);

    tinyriscv_cpu_fetch_unit #(
        .RESET_VECTOR(RESET_VECTOR)
    ) inst_tinyriscv_cpu_fetch_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        .imem_m_ahb_hready      ( imem_m_ahb_hready ),
        .imem_m_ahb_hresp       ( imem_m_ahb_hresp ),
        .imem_m_ahb_haddr       ( imem_m_ahb_haddr ),
        .imem_m_ahb_hwrite      ( imem_m_ahb_hwrite ),
        .imem_m_ahb_hwstrb      ( imem_m_ahb_hwstrb ),
        .imem_m_ahb_htrans      ( imem_m_ahb_htrans ),
        .imem_m_ahb_hsize       ( imem_m_ahb_hsize ),
        .imem_m_ahb_hburst      ( imem_m_ahb_hburst ),
        .imem_m_ahb_hprot       ( imem_m_ahb_hprot ),
        .imem_m_ahb_hmastlock   ( imem_m_ahb_hmastlock ),
        .imem_m_ahb_hwdata      ( imem_m_ahb_hwdata ),
        .imem_m_ahb_hrdata      ( imem_m_ahb_hrdata ),
        .fetch_pcaddr_out       ( fetch_pcaddr_out ),
        .fetch_instr_out        ( fetch_instr_out ),
        .fetch_spec_out         ( fetch_spec_out ),
        .branch_jump_in         ( branch_jump_in ),
        .branch_jump_pcaddr     ( branch_jump_pcaddr ),
        .branch_upd             ( branch_upd ),
        .branch_upd_pcaddr      ( branch_upd_pcaddr ),
        .branch_upd_res         ( branch_upd_res )
    );

    tinyriscv_cpu_decode_unit inst_tinyriscv_cpu_decode_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        .pipe_flush_in          ( pipe_flush_in ),
        .fetch_pcaddr_in        ( fetch_pcaddr_in ),
        .fetch_instr_in         ( fetch_instr_in ),
        .fetch_spec_in          ( fetch_spec_in ),
        .dec_pcaddr_out         ( dec_pcaddr_out ),
        .dec_instr_out          ( dec_instr_out ),
        .dec_spec_out           ( dec_spec_out ),
        .dec_op1_out            ( dec_op1_out ),
        .dec_op2_out            ( dec_op2_out ),
        .dec_op3_out            ( dec_op3_out ),
        .exec_instr_in          ( exec_instr_in ),
        .exec_res_in            ( exec_res_in ),
        .exec_byp_in            ( exec_byp_in ),
        .mem_instr_in           ( mem_instr_in ),
        .mem_res_in             ( mem_res_in ),
        .mem_byp_in             ( mem_byp_in ),
        .wb_rd1_sel             ( wb_rd1_sel ),
        .wb_rd1_data            ( wb_rd1_data ),
        .wb_rd1_wren            ( wb_rd1_wren ),
        .wb_rd2_sel             ( wb_rd2_sel ),
        .wb_rd2_data            ( wb_rd2_data ),
        .wb_rd2_wren            ( wb_rd2_wren ),
    );

    tinyriscv_cpu_exec_unit inst_tinyriscv_cpu_exec_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        .pipe_flush_in          ( pipe_flush_in ),
        .dec_pcaddr_in          ( dec_pcaddr_in ),
        .dec_instr_in           ( dec_instr_in ),
        .dec_op1_in             ( dec_op1_in ),
        .dec_op2_in             ( dec_op2_in ),
        .dec_op3_in             ( dec_op3_in ),
        .dec_spec_in            ( dec_spec_in ),
        .exec_pcaddr_out        ( exec_pcaddr_out ),
        .exec_instr_out         ( exec_instr_out ),
        .exec_res_out           ( exec_res_out ),
        .exec_byp_out           ( exec_byp_out ),
        .pipe_flush_out         ( pipe_flush_out ),
        .branch_jump            ( branch_jump ),
        .branch_jump_pcaddr     ( branch_jump_pcaddr ),
        .branch_upd             ( branch_upd ),
        .branch_upd_pcaddr      ( branch_upd_pcaddr ),
        .branch_upd_res         ( branch_upd_res )
    );

    tinyriscv_cpu_memory_unit inst_tinyrisc_cpu_memory_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        .exec_pcaddr_in         ( exec_pcaddr_in ),
        .exec_instr_in          ( exec_instr_in ),
        .exec_res_in            ( exec_res_in ),
        .exec_byp_in            ( exec_byp_in ),
        .dmem_m_ahb_hready      ( dmem_m_ahb_hready ),
        .dmem_m_ahb_hresp       ( dmem_m_ahb_hresp ),
        .dmem_m_ahb_haddr       ( dmem_m_ahb_haddr ),
        .dmem_m_ahb_hwrite      ( dmem_m_ahb_hwrite ),
        .dmem_m_ahb_hwstrb      ( dmem_m_ahb_hwstrb ),
        .dmem_m_ahb_htrans      ( dmem_m_ahb_htrans ),
        .dmem_m_ahb_hsize       ( dmem_m_ahb_hsize ),
        .dmem_m_ahb_hburst      ( dmem_m_ahb_hburst ),
        .dmem_m_ahb_hprot       ( dmem_m_ahb_hprot ),
        .dmem_m_ahb_hmastlock   ( dmem_m_ahb_hmastlock ),
        .dmem_m_ahb_hwdata      ( dmem_m_ahb_hwdata ),
        .dmem_m_ahb_hrdata      ( dmem_m_ahb_hrdata ),
        .mem_pcaddr_out         ( mem_pcaddr_out ),
        .mem_instr_out          ( mem_instr_out ),
        .mem_res_out            ( mem_res_out ),
        .mem_byp_out            ( mem_byp_out )
    );

    tinyriscv_cpu_writeback_unit inst_tinyriscv_cpu_writeback_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        .mem_pcaddr_in          ( mem_pcaddr_in ),
        .mem_instr_in           ( mem_instr_in ),
        .mem_res_in             ( mem_res_in ),
        .mem_byp_in             ( mem_byp_in ),
        .wb_rd1_sel             ( wb_rd1_sel ),
        .wb_rd1_data            ( wb_rd1_data ),
        .wb_rd1_wren            ( wb_rd1_wren ),
        .wb_rd2_sel             ( wb_rd2_sel ),
        .wb_rd2_data            ( wb_rd2_data ),
        .wb_rd2_wren            ( wb_rd2_wren ),
    );
    
endmodule