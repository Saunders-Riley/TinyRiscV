`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_memory_unit (
    // Core signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    input   logic       pipe_stall_in,
    // Upstream instruction interfac
    input   logic[31:0] exec_pcaddr_in,
    input   logic[31:0] exec_instr_in,
    input   logic[31:0] exec_res_in,
    input   logic[31:0] exec_byp_in,
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
    // Downstream instruction interface
    output  logic[31:0] mem_pcaddr_out,
    output  logic[31:0] mem_instr_out,
    output  logic[31:0] mem_res_out,
    output  logic[31:0] mem_byp_out
);
    
endmodule