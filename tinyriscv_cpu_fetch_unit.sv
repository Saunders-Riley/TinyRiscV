`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_fetch_unit #(
    parameter RESET_VECTOR = `TINYRISCV_RESET_VECTOR,
) (
    // Core signals
    input   logic       cpu_clk,                ///< CPU clock
    input   logic       cpu_resetn,             ///< CPU reset, async, active LOW
    input   logic       pipe_stall_in,          ///< Pipeline stall input - connect to dmem and imem hreadyin
    // AHB instruction memory interface
    input   logic       imem_m_ahb_hready,
    input   logic       imem_m_ahb_hresp,
    output  logic[31:0] imem_m_ahb_haddr,
    output  wire       imem_m_ahb_hwrite,
    output  wire[3:0]  imem_m_ahb_hwstrb,
    output  logic[1:0]  imem_m_ahb_htrans,
    output  logic[2:0]  imem_m_ahb_hsize,
    output  logic[2:0]  imem_m_ahb_hburst,
    output  wire[3:0]  imem_m_ahb_hprot,
    output  wire       imem_m_ahb_hmastlock,
    output  logic[31:0] imem_m_ahb_hwdata,
    input   logic[31:0] imem_m_ahb_hrdata,
    // Downstream instruction interface
    output  logic[31:0] fetch_pcaddr_out,       ///< Fetch instruction program counter
    output  logic[31:0] fetch_instr_out,        ///< Fetch instruction word
    output  logic[1:0]  fetch_spec_out,         ///< Speculative execution flag and branch prediction
    // Branch resolution interface
    input   logic       branch_jump_in,
    input   logic[31:0] branch_jump_pcaddr,
    input   logic       branch_upd,
    input   logic[31:0] branch_upd_pcaddr,
    input   logic       branch_upd_res
);
    // Static assignments
    assign  imem_m_ahb_hwrite = 1'b0;
    assign  imem_m_ahb_hwstrb = 4'h0;
    assign  imem_m_ahb_hmastlock = 1'b0;
    //TODO - HPROT should be assigned by processor mode
    assign  imem_m_ahb_hprot = 4'h1;

    // Internal signals
    logic[31:0]   prog_counter;
    logic[31:0]   prog_counter_pl[1:0];
    logic[31:0]   fetch_instr_pl;
    wire[19:0]  fetch_instr_pl_imm_U = fetch_instr_pl[31:12];
    wire[31:0]  fetch_instr_pl_imm_J = {fetch_instr_pl_imm_U[19] ? 11'h7FF : 11'h000, fetch_instr_pl_imm_U[19], fetch_instr_pl_imm_U[7:0], fetch_instr_pl_imm_U[8], fetch_instr_pl_imm_U[18:9], 1'b0};
    wire[12:0]  fetch_instr_pl_imm_B = {fetch_instr_pl[31], fetch_instr_pl[7], fet_instr_pl[30:25], fetch_instr_pl[11:8], 1'b0};
    logic[31:0]   fetch_pcaddr_pl;
    logic[2:0]    fetch_instr_invalidate;
    wire        predict_res;
    
    // AHB address phase controls
    always_ff @( posdege cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_fetch_unit_ahb_addr
        if (cpu_resetn) begin
            // Drive the program counter address out onto the instruction memory bus
            // Transactions are always 32-bit, non-sequential, non-bursting operations
            imem_m_ahb_haddr    <= prog_counter;
            imem_m_ahb_htrans   <= `AHB_HTRANS_NONSEQ;
            imem_m_ahb_hsize    <= `AHB_HSIZE_WORD;
            imem_m_ahb_hburst   <= `AHB_NONBURST;
        end else begin
            imem_m_ahb_haddr    <= RESET_VECTOR;
            imem_m_ahb_htrans   <= `AHB_HTRANS_IDLE;
            imem_m_ahb_hsize    <= `AHB_HSIZE_BYTE;
            imem_m_ahb_hburst   <= `AHB_NONBURST;
        end
    end

    // Program counter pipeline
    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_fetch_unit_prog_counter_pl
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
                // Pipeline registers are inserted to synchronize the program counter
                // value to the instruction read from the instruction memory. The instruction
                // lags prog_counter by 2 cycles due to the AHB interface
                prog_counter_pl[0]  <= prog_counter;
                prog_counter_pl[1]  <= prog_counter_pl[0];
                fetch_pcaddr_pl     <= (fetch_instr_invalidate[0]) ? 32'h0000_0000 : prog_counter_pl[1];
            end
        end else begin
            prog_counter_pl[0]  <= RESET_VECTOR;
            prog_counter_pl[1]  <= RESET_VECTOR;
            fetch_pcaddr_pl[0]  <= RESET_VECTOR;
        end
    end

    // Instruction fetch pipeline
    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_fetch_unit_instr_fetch
        if (cpu_resetn) begin
            if (~pipe_stall_in) begin
                // A Pipeline register was added here to allow for branch prediction
                // and unconditional jumps to be handled in the fetch unit rather than
                // downstream in the pipeline. The goal is to reduce the bubble size
                // when a branch or PC-relative jump occurs
                fetch_instr_pl      <= (fetch_instr_invalidate[0]) ? `RISCV_RV32I_INSTR_NOP : imem_m_ahb_hrdata;
                fetch_instr_out     <= (fetch_instr_invalidate[0]) ? 32'h0000_0000 : fetch_instr_pl[0];
            end
        end else begin
            fetch_instr_pl      <= `RISCV_RV32I_INSTR_NOP;
            fetch_instr_out     <= `RISCV_RV32I_INSTR_NOP;
        end
    end

    // Program counter logic
    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_fetch_unit_prog_counter
        if (cpu_resetn) begin
            if(~pipe_stall_in) begin
                if (branch_jump_in) begin
                    prog_counter            <= branch_jump_pcaddr;
                    fetch_spec_out          <= 2'b00;
                    fetch_instr_invalidate  <= 3'h7;
                end else if (fetch_instr_pl[6:0] == `RISCV_RV32I_OPCODE_JAL) begin
                    // For unconditional jump, the offset is already known, so the new program
                    // counter address can be calculated and set here. fetch_instr_invalidate
                    // is set to invalidate the next 3 instructions to let the upstream catch up.
                    prog_counter            <= fetch_pcaddr_pl + fetch_instr_pl_imm_J;
                    fetch_spec_out          <= 2'b00;
                    // fetch_instr_invalidate is set to 6 here to let the JAL into the pipeline.
                    // This is so the link address makes it to rd properly.
                    fetch_instr_invalidate  <= 3'h6;
                end
                else if(fetch_instr_pl[6:0] == `RISCV_RV32I_OPCODE_BRANCH) begin
                    // For branches, we raise the speculative execution state. Further downstream,
                    // if the execution unit detects a mismatch between bit[0] of fetch_spec_out
                    // and the actual branch result, the pipeline gets flushed and the branch will
                    // be re-done in the other direction.
                    if (predict_res) begin
                        prog_counter            <= fetch_pcaddr_pl + fetch_instr_pl_imm_B;
                        fetch_spec_out          <= 2'b11;
                        fetch_instr_invalidate  <= 3'h7;
                    end else begin
                        prog_counter            <= prog_counter + 4;
                        fetch_spec_out          <= 2'b10;
                        fetch_instr_invalidate  <= fetch_instr_invalidate >> 1;
                    end
                    
                end else begin
                    // In the normal case, the program counter increments to the next word, the
                    // invalidate bits shift right, and the speculative flag is set low.
                    prog_counter            <= prog_counter + 4;
                    fetch_spec_out          <= 2'b00;
                    fetch_instr_invalidate  <= fetch_instr_invalidate >> 1;
                end
            end
        end else begin
            prog_counter            <= RESET_VECTOR;
            fetch_spec_out          <= 2'b00;
            fetch_instr_invalidate  <= 3'h7;
        end
    end
    
    tinyriscv_cpu_fetch_branch_predictor #(
        .BRANCH_DEPTH(8)
    ) inst_tinyriscv_cpu_fetch_branch_predictor (
        .cpu_clk            ( cpu_clk ),
        .cpu_resetn         ( cpu_resetn ),
        .predict_addr       ( fetch_pcaddr_pl ),
        .predict_res        ( predict_res ),
        .branch_upd         ( branch_upd ),
        .branch_upd_addr    ( branch_upd_addr ),
        .branch_upd_res     ( branch_upd_res )
    );

endmodule

module tinyriscv_cpu_fetch_branch_predictor #(
    parameter BRANCH_DEPTH = 8;
) (
    // Global signals
    input   logic        cpu_clk,
    input   logic        cpu_resetn,
    // Prediction (read) interface
    input   logic[31:0]  predict_addr,
    output  logic        predict_res,
    // Update (write) interface
    input   logic        branch_upd,
    input   logic[31:0]  branch_upd_addr,
    input   logic        branch_upd_res
);
    // Internal Signals
    logic[31:0]   predict_addr_table[BRANCH_DEPTH-1:0];
    logic[1:0]    predict_res_table[BRANCH_DEPTH-1:0];
    logic         predict_res_int;
    wire[BRANCH_DEPTH-1:0]  predict_addr_match;
    wire[BRANCH_DEPTH-1:0]  update_addr_match;

    // Static Assignments
    integer i;
    for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
        assign predict_addr_match[i] = (predict_addr == predict_addr_table[i]) ? 1 : 0;
        assign update_addr_match[i] = (branch_upd_addr == predict_addr_table[i]) ? 1 : 0;
    end
    assign predict_res = (|predict_addr_match) predict_res_int : 0;

    // Predictor Read logic
    always_comb begin : proc_tinyriscv_cpu_fetch_branch_predictor_read
        for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
            if(predict_addr_match[i]) predict_res_int = (predict_res_table[i] > 2'b01) ? 1 : 0;
        end
    end

    // Predictor Update logic
    always_ff @( posedge cpu_clk, negedge cpu_resetn ) begin : proc_tinyriscv_cpu_fetch_branch_predictor_write
        if(cpu_resetn) begin
            if(branch_upd && |update_addr_match) begin
                for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
                    if(update_addr_match[i])
                        predict_res_table[i] <= (branch_upd_res == 1) ?
                                                ((predict_res_table[i] < 2'b11) ? predict_res_table[i] + 1 : predict_res_table[i]) :
                                                ((predict_res_table[i] > 2'b00) ? predict_res_table[i] - 1 : predict_res_table[i]);
                end
            end else if(branch_upd) begin
                for(i = 0; i < BRANCH_DEPTH-1; i = i + 1) begin
                    predict_addr_table[i + 1] <= predict_addr_table[i];
                    predict_res_table[i + 1] <= predict_res_table[i];
                end
                predict_addr_table[0] <= branch_upd_addr;
                predict_res_table[0] <= (branch_upd_res == 1) ? 2'b10 : 2'b01;
            end
        end else begin
            for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
                predict_addr_table[i] <= 32'h0000_0000;
                predict_res_table[i] <= 2'b01;
            end
        end
    end
    
endmodule

module __tb_tinyriscv_cpu_fetch_unit();

    logic       cpu_clk;
    logic       cpu_resetn;
    logic       pipe_stall_in;
    logic       imem_m_ahb_hready;
    logic       imem_m_ahb_hresp;
    logic       imem_m_ahb_haddr;
    logic       imem_m_ahb_hwrite;
    logic       imem_m_ahb_hwstrb;
    logic       imem_m_ahb_htrans;
    logic       imem_m_ahb_hsize;
    logic       imem_m_ahb_hburst;
    logic       imem_m_ahb_hprot;
    logic       imem_m_ahb_hmastlock;
    logic       imem_m_ahb_hwdata;
    logic       imem_m_ahb_hrdata;
    logic       fetch_pcaddr_out;
    logic       fetch_instr_out;
    logic       fetch_spec_out;
    logic       branch_jump_in;
    logic       branch_jump_pcaddr;
    logic       branch_upd;
    logic       branch_upd_pcaddr;
    logic       branch_upd_res;

    ahb_sync_sram #(
        .W_DATA(32),
        .W_ADDR(32),
        .DEPTH(1 << 11),
        .HAS_WRITE_BUFFER(1),
        .USE_1R1W(0),
        .PRELOAD_FILE("")
    ) inst_ahb_sync_sram (
        // Globals
        .clk                ( cpu_clk ),
        .rst_n              ( cpu_resetn ),

        // AHB lite slave interface
        .ahbls_hready_resp  ( imem_m_ahb_hready ),
        .ahbls_hready       ( 1'b1 ),
        .ahbls_hresp        (  ),
        .ahbls_haddr        ( imem_m_ahb_haddr ),
        .ahbls_hwrite       ( imem_m_ahb_hwrite ),
        .ahbls_htrans       ( imem_m_ahb_htrans ),
        .ahbls_hsize        ( imem_m_ahb_hsize ),
        .ahbls_hburst       ( imem_m_ahb_hburst ),
        .ahbls_hprot        ( imem_m_ahb_hprot ),
        .ahbls_hmastlock    ( imem_m_ahb_hmastlock ),
        .ahbls_hwdata       ( imem_m_ahb_hwdata ),
        .ahbls_hrdata       ( imem_m_ahb_hrdata )
    );

    tinyriscv_cpu_fetch_unit #(
        .RESET_VECTOR(`TINYRISCV_RESET_VECTOR)
    ) inst_tinyriscv_cpu_fetch_unit (
        // Core signals
        .cpu_clk                ( cpu_clk ),
        .cpu_resetn             ( cpu_resetn ),
        .pipe_stall_in          ( pipe_stall_in ),
        // AHB instruction memory interface
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
        // Downstream instruction interface
        .fetch_pcaddr_out       ( fetch_pcaddr_out ),
        .fetch_instr_out        ( fetch_instr_out ),
        .fetch_spec_out         ( fetch_spec_out ),
        // Branch resolution interface
        .branch_jump_in         ( branch_jump_in ),
        .branch_jump_pcaddr     ( branch_jump_pcaddr ),
        .branch_upd             ( branch_upd ),
        .branch_upd_pcaddr      ( branch_upd_pcaddr ),
        .branch_upd_res         ( branch_upd_res )
);
endmodule
