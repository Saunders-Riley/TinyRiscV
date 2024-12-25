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
    // Interrupts
    input   logic[31:0] extern_interrupt_in,
    input   logic       nonmask_interrupt_in
);
    logic       pipe_stall;             ///< pipeline stall flag
    pipe_stall = ~imem_m_ahb_hready | ~dmem_m_ahb_hready;
    logic       pipe_flush;             ///< pipeline flush flag - asserts on missed branch or indirect jump
    logic[31:0] mstatus;                ///< machine status register

    logic[31:0] fetch_pcaddr;           ///< fetch stage program counter
    logic[31:0] fetch_instr;            ///< fetch stage instruction
    logic[1:0]  fetch_spec;             ///< fetch stage speculative execution flags - {speculative, prediction}
    logic       branch_jump;            ///< branch/jump flag - asserts on missed branch or indirect jump
    logic[31:0] branch_jump_pcaddr;     ///< branch/jump new program counter value
    logic       branch_upd;             ///< branch predictor update flag
    logic[31:0] branch_upd_pcaddr;      ///< branch predictor update address
    logic       branch_upd_res;         ///< branch predictor update result

    logic[31:0] dec_pcaddr;             ///< decode stage program counter
    logic[31:0] dec_instr;              ///< decode stage instruction
    logic[1:0]  dec_spec;               ///< decode stage speculative exectuion flags
    logic[31:0] dec_op1;                ///< decode stage operand 1
    logic[31:0] dec_op2;                ///< decode stage operand 2
    logic[31:0] dec_op3;                ///< decode stage operand 3

    logic[31:0] exec_pcaddr;            ///< execute stage program counter
    logic[31:0] exec_instr;             ///< execute stage instruction
    logic[31:0] exec_res;               ///< execute stage operation result
    logic[31:0] exec_byp;               ///< execute stage bypass operand

    logic[31:0] mem_pcaddr;             ///< memory stage program counter
    logic[31:0] mem_instr;              ///< memory stage instruction
    logic[31:0] mem_res;                ///< memory stage operation result
    logic[31:0] mem_byp;                ///< memory stage bypass operand

    logic[11:0] wb_rd1_sel;             ///< destination register 1 select
    logic[31:0] wb_rd1_data;            ///< destination register 1 data
    logic       wb_rd1_wren;            ///< destination register 1 write
    logic[4:0]  wb_rd2_sel;             ///< destination register 2 select
    logic[31:0] wb_rd2_data;            ///< destination register 2 data
    logic       wb_rd2_wren;            ///< destination register 2 write

    tinyriscv_cpu_fetch_unit #(
        .RESET_VECTOR(RESET_VECTOR)
    ) inst_tinyriscv_cpu_fetch_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall ),
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
        .fetch_pcaddr_out       ( fetch_pcaddr ),
        .fetch_instr_out        ( fetch_instr ),
        .fetch_spec_out         ( fetch_spec ),
        .branch_jump_in         ( branch_jump ),
        .branch_jump_pcaddr     ( branch_jump_pcaddr ),
        .branch_upd             ( branch_upd ),
        .branch_upd_pcaddr      ( branch_upd_pcaddr ),
        .branch_upd_res         ( branch_upd_res )
    );

    tinyriscv_cpu_decode_unit inst_tinyriscv_cpu_decode_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall ),
        .pipe_flush_in          ( pipe_flush ),
        .fetch_pcaddr_in        ( fetch_pcaddr ),
        .fetch_instr_in         ( fetch_instr ),
        .fetch_spec_in          ( fetch_spec ),
        .dec_pcaddr_out         ( dec_pcaddr ),
        .dec_instr_out          ( dec_instr ),
        .dec_spec_out           ( dec_spec ),
        .dec_op1_out            ( dec_op1 ),
        .dec_op2_out            ( dec_op2 ),
        .dec_op3_out            ( dec_op3 ),
        .exec_instr_in          ( exec_instr ),
        .exec_res_in            ( exec_res ),
        .exec_byp_in            ( exec_byp ),
        .mem_instr_in           ( mem_instr ),
        .mem_res_in             ( mem_res ),
        .mem_byp_in             ( mem_byp ),
        .wb_rd1_sel             ( wb_rd1_sel ),
        .wb_rd1_data            ( wb_rd1_data ),
        .wb_rd1_wren            ( wb_rd1_wren ),
        .wb_rd2_sel             ( wb_rd2_sel ),
        .wb_rd2_data            ( wb_rd2_data ),
        .wb_rd2_wren            ( wb_rd2_wren ),
        .mstatus_out            ( mstatus ),
        .misa_out               ( misa ),
        .medeleg_out            ( medeleg ),
        .mideleg_out            ( mideleg ),
        .mie_out                ( mie ),
        .mtvec_out              ( mtvec ),
        .exc_int_in             ( exc_int ),
        .exc_pcaddr_in          ( exc_pcaddr ),
        .exc_cause_in           ( exc_cause ),
        .exc_val_in             ( exc_val ),
        .exc_ip_in              ( exc_ip ),
        .exc_tinst_in           ( exc_tinst ),
        .exc_val2_in            ( exc_val2 ),
        .nmi_in                 ( nmi ),
        .nmi_pcaddr_in          ( nmi_pcaddr ),
        .nmi_cause_in           ( nmi_cause ),
        .nmi_status_in          ( nmi_status ),
        .mcycle_in              ( mcycle ),
        .minstret_in            ( minstret ),
        .mhpmcounter_in         ( mhpmcounter ),
        .mhpmevent_out          ( mhpmevent ),
        .mcounteren_out         ( mcounteren ),
        .mcountinhibit_out      ( mcountinhibit ),
    );

    tinyriscv_cpu_exec_unit inst_tinyriscv_cpu_exec_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall ),
        .pipe_flush_in          ( pipe_flush ),
        .dec_pcaddr_in          ( dec_pcaddr ),
        .dec_instr_in           ( dec_instr ),
        .dec_op1_in             ( dec_op1 ),
        .dec_op2_in             ( dec_op2 ),
        .dec_op3_in             ( dec_op3 ),
        .dec_spec_in            ( dec_spec ),
        .exec_pcaddr_out        ( exec_pcaddr ),
        .exec_instr_out         ( exec_instr ),
        .exec_res_out           ( exec_res ),
        .exec_byp_out           ( exec_byp ),
        .pipe_flush_out         ( pipe_flush ),
        .branch_jump            ( branch_jump ),
        .branch_jump_pcaddr     ( branch_jump_pcaddr ),
        .branch_upd             ( branch_upd ),
        .branch_upd_pcaddr      ( branch_upd_pcaddr ),
        .branch_upd_res         ( branch_upd_res )
    );

    tinyriscv_cpu_memory_unit inst_tinyrisc_cpu_memory_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall ),
        .exec_pcaddr_in         ( exec_pcaddr ),
        .exec_instr_in          ( exec_instr ),
        .exec_res_in            ( exec_res ),
        .exec_byp_in            ( exec_byp ),
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
        .mem_pcaddr_out         ( mem_pcaddr ),
        .mem_instr_out          ( mem_instr ),
        .mem_res_out            ( mem_res ),
        .mem_byp_out            ( mem_byp )
    );

    tinyriscv_cpu_writeback_unit inst_tinyriscv_cpu_writeback_unit (
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall ),
        .mem_pcaddr_in          ( mem_pcaddr ),
        .mem_instr_in           ( mem_instr ),
        .mem_res_in             ( mem_res ),
        .mem_byp_in             ( mem_byp ),
        .wb_rd1_sel             ( wb_rd1_sel ),
        .wb_rd1_data            ( wb_rd1_data ),
        .wb_rd1_wren            ( wb_rd1_wren ),
        .wb_rd2_sel             ( wb_rd2_sel ),
        .wb_rd2_data            ( wb_rd2_data ),
        .wb_rd2_wren            ( wb_rd2_wren ),
    );
    
endmodule