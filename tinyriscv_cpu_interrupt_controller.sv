`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_interrupt_controller #
(
    parameter INTERRUPT_VECTOR = 32'h0000_8000,
) (
    // Global signals
    input   logic       cpu_clk,
    input   logic       cpu_resetn,
    input   logic[31:0] extern_interrupt_in,
    input   logic[31:0] mie_in,
    input   logic       nonmask_interrupt_in,
    input   logic[3:0]  exception_in,
    // machine/trap interrupt interface
    output  logic       exc_int_out,
    output  logic[31:0] exc_pcaddr_out,
    output  logic[31:0] exc_cause_out,
    output  logic[31:0] exc_val_out,
    output  logic[31:0] exc_ip_out,
    output  logic[31:0] exc_tinst_out,
    output  logic[31:0] exc_val2_out,
    // non-maskable interrupt interface
    output  logic       nmi_out,
    output  logic[31:0] nmi_pcaddr_out,
    output  logic[31:0] nmi_cause_out,
    output  logic[31:0] nmi_status_out,
    // branch/jump interface
    output  logic       branch_jump_out,
    output  logic[31:0] branch_jump_pcaddr_out,
    output  logic       pipe_flush_out,
    // sideband inputs
    input   logic[31:0] fetch_pcaddr_in,
    input   logic[31:0] fetch_instr_in,
    input   logic[31:0] dec_pcaddr_in,
    input   logic[31:0] dec_instr_in,
    input   logic[31:0] exec_pcaddr_in,
    input   logic[31:0] exec_instr_in,
    input   logic[31:0] mem_pcaddr_in,
    input   logic[31:0] mem_instr_in
);

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_interrupt_controller_sync
        if (cpu_resetn) begin
            if (|exception_in) begin
                exc_int_out             <= 1;
                exc_pcaddr_out          <= exec_pcaddr_in; // last instruction that will complete
                exc_cause_out           <=  (exception_in[3]) ? 1:
                                            (exception_in[2]) ? 1:
                                            (exception_in[1]) ? 1:
                                            1;
                exc_val_out             <=  (exception_in[3]) ? fetch_pcaddr_in:
                                            (exception_in[2]) ? dec_pcaddr_in:
                                            (exception_in[1]) ? exec_pcaddr_in:
                                            mem_pcaddr_in;
                exc_ip_out              <= 32'h0000_0000;
                exc_tinst_out           <=  (exception_in[3]) ? fetch_instr_in:
                                            (exception_in[2]) ? dec_instr_in:
                                            (exception_in[1]) ? exec_instr_in:
                                            mem_instr_in;
                exc_val2_out            <= 32'h0000_0000;
                nmi_out                 <= 0;
                nmi_pcaddr_out          <= 32'h0000_0000;
                nmi_cause_out           <= 32'h0000_0000;
                nmi_status_out          <= 32'h0000_0000;
                branch_jump_out         <= 1;
                branch_jump_pcaddr_out  <= INTERRUPT_VECTOR;
                pipe_flush_out          <= 1;
            end else if (nmi_in) begin
                exc_int_out             <= 0;
                exc_pcaddr_out          <= 32'h0000_0000;
                exc_cause_out           <= 32'h0000_0000;
                exc_val_out             <= 32'h0000_0000;
                exc_ip_out              <= 32'h0000_0000;
                exc_tinst_out           <= 32'h0000_0000;
                exc_val2_out            <= 32'h0000_0000;
                nmi_out                 <= 1;
                nmi_pcaddr_out          <= exec_pcaddr_in; // last instruction that will complete
                nmi_cause_out           <= 32'h0000_0000;
                nmi_status_out          <= 32'h0000_0000;
                branch_jump_out         <= 1;
                branch_jump_pcaddr_out  <= INTERRUPT_VECTOR;
                pipe_flush_out          <= 1;
            end else if (|extern_interrupt_in) begin
                
            end else begin
                
            end
        end else begin
            
        end
    end
    
endmodule
