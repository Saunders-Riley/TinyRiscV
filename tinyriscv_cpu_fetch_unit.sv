`include "tinyriscv_config.vh"
`include "riscv_instruction_set.vh"

module tinyriscv_cpu_fetch_unit #(
    parameter RESET_VECTOR = `TINYRISCV_RESET_VECTOR;
) (
    // Core signals
    input   wire        cpu_clk,                ///< CPU clock
    input   wire        cpu_resetn,             ///< CPU reset, async, active LOW
    // AHB instruction memory interface
    input   wire        imem_m_ahb_hready,
    input   wire        imem_m_ahb_hresp,
    output  reg[31:0]   imem_m_ahb_haddr,
    output  wire        imem_m_ahb_hwrite,
    output  wire[3:0]   imem_m_ahb_hwstrb,
    output  reg[1:0]    imem_m_ahb_htrans,
    output  reg[2:0]    imem_m_ahb_hsize,
    output  reg[2:0]    imem_m_ahb_hburst,
    output  wire[3:0]   imem_m_ahb_hprot,
    output  wire        imem_m_ahb_hmastlock,
    output  wire[31:0]  imem_m_ahb_hwdata,
    input   wire[31:0]  imem_m_ahb_hrdata,
    // Downstream instruction interface
    output  reg[31:0]   fetch_pcaddr_out,       ///< Fetch instruction program counter
    output  reg[31:0]   fetch_instr_out,        ///< Fetch instruction word
    output  reg         fetch_spec_out,         ///< Speculative execution flag
    output  wire        fetch_stall,            ///< Pipeline stall output
    output  wire        fetch_flush,            ///< Pipeline flush output
    // Branch resolution interface
    input   wire        branch_jump,            ///< Unconditional Jump flag, asserts for JALR downstream, forces fetch_flush
    input   wire[1:0]   branch_res,             ///< Branch result flags, if branch_res[1] != branch_res[0], mispredicted, forces fetch_flush
    input   wire        branch_upd,             ///< Branch update flag, asserts for BRANCH downstream, updates predictor table
    input   wire[31:0]  branch_addr,            ///< Branch pcaddr - address of the branch/jump instruction
    input   wire[31:0]  branch_jump_pcaddr      ///< Branch/Jump pcaddr - address to set prog_counter to
);
    // Static assignments
    assign  imem_m_ahb_hwrite = 1'b0;
    assign  imem_m_ahb_hwstrb = 4'h0;
    assign  imem_m_ahb_hmastlock = 1'b0;
    //TODO - HPROT should be assigned by processor mode
    assign  imem_m_ahb_hprot = 4'h1;
    assign  fetch_flush = branch_jump | ((branch_res[0] != branch_res[1]) & branch_upd);
    assign  fetch_stall = ~imem_m_ahb_hready; // cache wait states will force a pipeline stall, might want to rework this later on

    // Internal signals
    reg[31:0]   prog_counter;
    reg[31:0]   prog_counter_pl[1:0];
    reg[31:0]   fetch_instr_pl;
    wire[19:0]  fetch_instr_pl_imm_U = fetch_instr_pl[31:12];
    wire[31:0]  fetch_instr_pl_imm_J = {fetch_instr_pl_imm_U[19] ? 11'h7FF : 11'h000, fetch_instr_pl_imm_U[19], fetch_instr_pl_imm_U[7:0], fetch_instr_pl_imm_U[8], fetch_instr_pl_imm_U[18:9], 1'b0};
    wire[12:0]  fetch_instr_pl_imm_B = {fetch_instr_pl[31], fetch_instr_pl[7], fet_instr_pl[30:25], fetch_instr_pl[11:8], 1'b0};
    reg[31:0]   fetch_pcaddr_pl;
    reg[2:0]    fetch_instr_invalidate;
    
    // AHB address phase controls
    always @(posedge cpu_clk, negedge cpu_resetn) begin
        if (cpu_resetn) begin
            // Drive the program counter address out onto the instruction memory bus
            // Transactions are always 32-bit, non-sequential, non-bursting operations
            imem_m_ahb_haddr <= prog_counter;
            imem_m_ahb_htrans <= `AHB_HTRANS_NONSEQ;
            imem_m_ahb_hsize <= `AHB_HSIZE_WORD;
            imem_m_ahb_hburst <= `AHB_NONBURST;
        end else begin
            imem_m_ahb_haddr <= RESET_VECTOR;
            imem_m_ahb_htrans <= `AHB_HTRANS_IDLE;
            imem_m_ahb_hsize <= `AHB_HSIZE_BYTE;
            imem_m_ahb_hburst <= `AHB_NONBURST;
        end
    end

    // Program counter pipeline
    always @(posedge cpu_clk, negedge cpu_resetn) begin
        if (cpu_resetn) begin
            if (imem_m_ahb_hready) begin
                // Pipeline registers are inserted to synchronize the program counter
                // value to the instruction read from the instruction memory. The instruction
                // lags prog_counter by 2 cycles due to the AHB interface
                prog_counter_pl[0] <= prog_counter;
                prog_counter_pl[1] <= prog_counter_pl[0];
                fetch_pcaddr_pl <= (fetch_instr_invalidate[0]) ? 32'h0000_0000 : prog_counter_pl[1];
            end
        end else begin
            prog_counter_pl[0] <= RESET_VECTOR;
            prog_counter_pl[1] <= RESET_VECTOR;
            fetch_pcaddr_pl[0] <= RESET_VECTOR;
        end
    end

    // Instruction fetch pipeline
    always @(posedge cpu_clk, negedge cpu_resetn) begin
        if (cpu_resetn) begin
            if (imem_m_ahb_hready) begin
                // A Pipeline register was added here to allow for branch prediction
                // and unconditional jumps to be handled in the fetch unit rather than
                // downstream in the pipeline. The goal is to reduce the bubble size
                // when a branch or PC-relative jump occurs
                fetch_instr_pl <= (fetch_instr_invalidate[0]) ? `RISCV_RV32I_INSTR_NOP : imem_m_ahb_hrdata;
                fetch_instr_out <= (fetch_instr_invalidate[0]) ? 32'h0000_0000 : fetch_instr_pl[0];
            end
        end else begin
            fetch_instr_pl <= `RISCV_RV32I_INSTR_NOP;
            fetch_instr_out <= `RISCV_RV32I_INSTR_NOP;
        end
    end

    // Program counter logic
    always @(posedge cpu_clk, negedge resetn) begin
        if (cpu_resetn) begin
            if(imem_m_ahb_hready) begin
                if (fetch_instr_pl[6:0] == `RISCV_RV32I_OPCODE_JAL) begin
                    // For unconditional jump, the offset is already known, so the new program
                    // counter address can be calculated and set here. fetch_instr_invalidate
                    // is set to invalidate the next 3 instructions to let the upstream catch up.
                    prog_counter <= fetch_pcaddr_pl + fetch_instr_pl_imm_J;
                    fetch_spec_out <= 0;
                    // fetch_instr_invalidate is set to 6 here to let the JAL into the pipeline.
                    // This is so the link address makes it to rd properly.
                    fetch_instr_invalidate <= 3'h6;
                end
                else if(fetch_instr_pl[6:0] == `RISCV_RV32I_OPCODE_BRANCH && predict_res == 1) begin
                    // For branches, if the branch is predicted to be taken, the same thing as
                    // an unconditional jump occurs, except the speculative flag is also set
                    // to mark that this was a branch instruction and all following instructions
                    // are being speculatively executed until it is resolved.
                    prog_counter <= fetch_pcaddr_pl + fetch_instr_pl_imm_B;
                    fetch_spec_out <= 1;
                    fetch_instr_invalidate <= 3'h7;
                end else begin
                    // In the normal case, the program counter increments to the next word, the
                    // invalidate bits shift right, and the speculative flag is set low.
                    prog_counter <= prog_counter + 4;
                    fetch_spec_out <= 0;
                    fetch_instr_invalidate <= fetch_instr_invalidate >> 1;
                end
            end
        end else begin
            
        end
    end
    
endmodule

module tinyriscv_cpu_fetch_branch_predictor #(
    parameter BRANCH_DEPTH = 8;
) (
    // Global signals
    input   wire        cpu_clk,
    input   wire        cpu_resetn,
    // Prediction (read) interface
    input   wire[31:0]  predict_addr,
    output  wire        predict_res,
    // Update (write) interface
    input   wire        branch_upd,
    input   wire[31:0]  branch_upd_addr,
    input   wire        branch_upd_res
);
    // Internal Signals
    reg[31:0]   predict_addr_table[BRANCH_DEPTH-1:0];
    reg[1:0]    predict_res_table[BRANCH_DEPTH-1:0];
    reg         predict_res_int;
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
    always @(*) begin
        for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
            if(predict_addr_match[i]) predict_res_int = (predict_res_table[i] > 2'b01) ? 1 : 0;
        end
    end

    // Predictor Update logic
    always @(posedge clk) begin
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
                predict_res_table[0] <= 2'b01;
            end
        end else begin
            for(i = 0; i < BRANCH_DEPTH; i = i + 1) begin
                predict_addr_table[i] <= 32'h0000_0000;
                predict_res_table[i] <= 2'b01;
            end
        end
    end
    
endmodule
