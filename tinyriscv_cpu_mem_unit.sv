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

    logic[31:0]     pl_mem_pcaddr[1:0];
    logic[31:0]     pl_mem_instr[1:0];
    logic[31:0]     pl_mem_res[1:0];
    logic[31:0]     pl_mem_byp[1:0];

    logic[31:0]     pl_mem_read_word;

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_mem_unit_pl
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
                pl_mem_pcaddr[1]    <= pl_mem_pcaddr[0];
                pl_mem_pcaddr[0]    <= exec_pcaddr_in;
                pl_mem_instr[1]     <= pl_mem_instr[0];
                pl_mem_instr[0]     <= exec_instr_in;
                pl_mem_res[1]       <= pl_mem_res[0];
                pl_mem_res[0]       <= exec_res_in;
                pl_mem_byp[1]       <= pl_mem_byp[0];
                pl_mem_byp[0]       <= exec_byp_in;

                mem_pcaddr_out      <= pl_mem_pcaddr[1];
                mem_instr_out       <= pl_mem_instr[1];
                mem_res_out         <= (pl_mem_instr[1][6:0] == `RISCV_RV32I_OPCODE_LOAD) ? pl_mem_read_word : pl_mem_res[1];
                mem_byp_out         <= pl_mem_byp[1];
            end
        end else begin
            pl_mem_pcaddr[1]    <= 32'h0000_0000;
            pl_mem_pcaddr[0]    <= 32'h0000_0000;
            pl_mem_instr[1]     <= `RISCV_RV32I_INSTR_NOP;
            pl_mem_instr[0]     <= `RISCV_RV32I_INSTR_NOP;
            pl_mem_res[1]       <= 32'h0000_0000;
            pl_mem_res[0]       <= 32'h0000_0000;
            pl_mem_byp[1]       <= 32'h0000_0000;
            pl_mem_byp[0]       <= 32'h0000_0000;

            mem_pcaddr_out      <= 32'h0000_0000;
            mem_instr_out       <= `RISCV_RV32I_INSTR_NOP;
            mem_res_out         <= 32'h0000_0000;
            mem_byp_out         <= 32'h0000_0000;
        end
    end

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_mem_unit_ahb_addr
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
               if ( exec_instr_in[6:0] == `RISCV_RV32I_OPCODE_LOAD ||
                    exec_instr_in[6:0] == `RISCV_RV32I_OPCODE_STORE
                ) begin
`ifdef TINYRISCV_ALLOW_UNALIGNED
                    dmem_m_ahb_haddr        <= exec_res_in[31:0];
`else
                    dmem_m_ahb_haddr        <= exec_res_in[31:2];
`endif TINYRISCV_ALLOW_UNALIGNED
                    dmem_m_ahb_hwrite       <= (exec_instr_in[6:0] == `RISCV_RV32I_OPCODE_STORE) ? 1 : 0;
                    dmem_m_ahb_htrans       <= `AHB_HTRANS_NONSEQ;
                    dmem_m_ahb_hsize        <= exec_instr_in[13:12];
                    dmem_m_ahb_hburst       <= `AHB_HBURST_NONBURST;
                    dmem_m_ahb_hprot        <= 4'h0; // TODO - needs to be determined by processor mode
                    dmem_m_ahb_hmastlock    <= 0;
               end else begin
                    dmem_m_ahb_haddr        <= 32'h0000_0000;
                    dmem_m_ahb_hwrite       <= 0;
                    dmem_m_ahb_htrans       <= AHB_HTRANS_IDLE;
                    dmem_m_ahb_hsize        <= 3'b000;
                    dmem_m_ahb_hburst       <= 3'b000;
                    dmem_m_ahb_hprot        <= 4'h0; // TODO - needs to be determined by processor mode
                    dmem_m_ahb_hmastlock    <= 0;
               end
            end
        end else begin
            dmem_m_ahb_haddr        <= 32'h0000_0000;
            dmem_m_ahb_hwrite       <= 0;
            dmem_m_ahb_htrans       <= AHB_HTRANS_IDLE;
            dmem_m_ahb_hsize        <= 3'b000;
            dmem_m_ahb_hburst       <= 3'b000;
            dmem_m_ahb_hprot        <= 4'h0; // TODO - needs to be determined by processor mode
            dmem_m_ahb_hmastlock    <= 0;
        end
    end

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_mem_unit_ahb_data_wr
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
                if (pl_mem_instr[0][6:0] == `RISCV_RV32I_OPCODE_STORE) begin
`ifdef TINYRISCV_ALLOW_UNALIGNED
                    dmem_m_ahb_hwdata       <= pl_mem_byp[0];
                    dmem_m_ahb_hwstrb       <=  (pl_mem_instr[13:12] == `AHB_HSIZE_BYTE) ? 4'h1 :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_HALF) ? 4'h3 :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_WORD) ? 4'hF : 4'h0;
`else
                    dmem_m_ahb_hwdata       <=  (pl_mem_instr[13:12] == `AHB_HSIZE_BYTE) ? pl_mem_byp[0][7:0] << (8 * pl_mem_res[0][1:0]) :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_HALF) ? pl_mem_byp[0][15:0] << (16 * pl_mem_res[0][1]) :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_WORD) ? pl_mem_byp[0];
                    dmem_m_ahb_hwstrb       <=  (pl_mem_instr[13:12] == `AHB_HSIZE_BYTE) ? (4'h1 << (8 * pl_mem_res[0][1:0])) :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_HALF) ? (4'h3 << (16 * pl_mem_res[0][1])) :
                                                (pl_mem_instr[13:12] == `AHB_HSIZE_WORD) ? 4'hF : 4'h0;
`endif TINYRISCV_ALLOW_UNALIGNED
                end else begin
                    dmem_m_ahb_hwdata       <= 32'h0000_0000;
                    dmem_m_ahb_hwstrb       <= 4'h0;
                end
            end
        end else begin
            dmem_m_ahb_hwdata       <= 32'h0000_0000;
            dmem_m_ahb_hwstrb       <= 4'h0;
        end
    end

    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_mem_unit_ahb_data_rd
        if (cpu_resetn) begin
            if(dmem_m_ahb_hready && pl_mem_instr[0] == `RISCV_RV32I_OPCODE_LOAD) begin
                case (pl_mem_inst[0][14:12])
                    `RISCV_RV32I_FUNCT3_LOAD_LB     : begin
                        pl_mem_read_word        <= ((dmem_m_ahb_hrdata >> (8 * pl_mem_res[1:0])) & 32'h000000FF) | ((dmem_m_ahb_hrdata & 8'h80 << (8 * pl_mem_res[1:0])) ? 32'hFFFF_FF00 : 32'h0000_0000);
                    end
                    `RISCV_RV32I_FUNCT3_LOAD_LBU    : begin
                        pl_mem_read_word        <= ((dmem_m_ahb_hrdata >> (8 * pl_mem_res[1:0])) & 32'h000000FF);
                    end
                    `RISCV_RV32I_FUNCT3_LOAD_LH     : begin
                        pl_mem_read_word        <= ((dmem_m_ahb_hrdata >> (16 * pl_mem_res[1])) & 32'h0000_FFFFF) | ((dmem_m_ahb_hrdata & 16'h8000 << (16 * pl_mem_res[1])) ? 32'hFFFF_FF00 : 32'h0000_0000);
                    end
                    `RISCV_RV32I_FUNCT3_LOAD_LHU    : begin
                        pl_mem_read_word        <= ((dmem_m_ahb_hrdata >> (16 * pl_mem_res[1])) & 32'h0000_FFFFF);
                    end
                    `RISCV_RV32I_FUNCT3_LOAD_LW     : begin
                        pl_mem_read_word        <= dmem_m_ahb_hrdata;
                    end
                    default : begin
                        pl_mem_read_word        <= 32'h0000_0000;
                    end
                endcase
            end
        end else begin
            pl_mem_read_word    <= 32'h0000_0000;
        end
    end

endmodule