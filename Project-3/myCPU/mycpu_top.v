module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg             reset;
always @(posedge clk) reset <= ~resetn;

// allowin
wire         ID_allowin;
wire         EX_allowin;
wire         MEM_allowin;
wire         WB_allowin;

// memory signal
wire         inst_ready;
wire         inst_valid;
wire         data_ready;
wire         data_valid;

assign inst_ready = 1'b1;
assign inst_valid = 1'b1;
assign data_ready = 1'b1;
assign data_valid = 1'b1;

// internal pipeline zipes
wire [64:0]  IF_to_ID_reg;
wire [184:0] ID_to_EX_reg;
wire [137:0] EX_to_MEM_reg;
wire [102:0] MEM_to_WB_reg;

// IF <-> ID signals
wire         ID_flush;
wire [31:0]  ID_pc_real;

// regfile <-> ID / WB
wire [4:0]   rf_raddr1;
wire [4:0]   rf_raddr2;
wire [31:0]  rf_rdata1;
wire [31:0]  rf_rdata2;

wire         wb_rf_wen;
wire [4:0]   wb_rf_waddr;
wire [31:0]  wb_rf_wdata;

// WB inst_retire
wire [72:0]  wb_inst_retire_reg;

wire           EX_front_valid;
wire [ 4:0]    EX_front_addr;
wire [31:0]    EX_front_data;
wire           MEM_front_valid;
wire [ 4:0]    MEM_front_addr;
wire [31:0]    MEM_front_data;
wire           MEM_done;
wire [31:0]    loaded_data;

wire [31:0]    done_pc;

// IF instance
IF u_IF (
    .clk            (clk),
    .rst            (reset),
    .flush          (ID_flush),
    .inst           (inst_sram_rdata),
    .pc_real        (ID_pc_real),
    .pc_next        (inst_sram_addr),
    .IF_to_ID_reg   (IF_to_ID_reg),
    .ID_allowin     (ID_allowin),
    .inst_ready     (inst_ready),
    .inst_valid     (inst_valid),
    .inst_sram_en   (inst_sram_en)
);

// ID instance
ID u_ID (
    .clk            (clk),
    .rst            (reset),
    .IF_to_ID_zip   (IF_to_ID_reg),
    .front_from_EX_valid (EX_front_valid),
    .front_from_EX_addr  (EX_front_addr),
    .front_from_EX_data  (EX_front_data),
    .front_from_MEM_valid(MEM_front_valid),
    .front_from_MEM_addr (MEM_front_addr),
    .front_from_MEM_data (MEM_front_data),
    .last_MEM_done  (MEM_done),
    .last_load_data (loaded_data),
    .rf_rdata1      (rf_rdata1),
    .rf_rdata2      (rf_rdata2),
    .rf_raddr1      (rf_raddr1),
    .rf_raddr2      (rf_raddr2),
    .flush          (ID_flush),
    .pc_real        (ID_pc_real),
    .ID_to_EX_reg   (ID_to_EX_reg),
    .ID_allowin     (ID_allowin),
    .EX_allowin     (EX_allowin),
    .done_pc        (done_pc)
);

// EX instance
EX u_EX (
    .clk            (clk),
    .rst            (reset),
    .ID_to_EX_zip   (ID_to_EX_reg),
    .EX_to_MEM_reg  (EX_to_MEM_reg),
    .EX_allowin     (EX_allowin),
    .MEM_allowin    (MEM_allowin),
    .front_valid    (EX_front_valid),
    .front_addr     (EX_front_addr),
    .front_data     (EX_front_data)
);

// MEM instance (connect its memory read_data to data_sram_rdata, and drive data_sram_* outputs)
MEM u_MEM (
    .clk            (clk),
    .rst            (reset),
    .EX_to_MEM_zip  (EX_to_MEM_reg),
    .write_en       (data_sram_en),
    .write_we       (data_sram_we),
    .write_addr     (data_sram_addr),
    .write_data     (data_sram_wdata),
    .MEM_to_WB_reg  (MEM_to_WB_reg),
    .read_data      (data_sram_rdata),
    .MEM_allowin    (MEM_allowin),
    .WB_allowin     (WB_allowin),
    .data_ready     (data_ready),
    .data_valid     (data_valid),
    .front_valid    (MEM_front_valid),
    .front_addr     (MEM_front_addr),
    .front_data     (MEM_front_data),
    .MEM_done       (MEM_done),
    .loaded_data    (loaded_data),
    .done_pc        (done_pc)
);

// WB instance
WB u_WB (
    .clk            (clk),
    .rst            (reset),
    .MEM_to_WB_zip  (MEM_to_WB_reg),
    .rf_wen         (wb_rf_wen),
    .rf_waddr       (wb_rf_waddr),
    .rf_wdata       (wb_rf_wdata),
    .inst_retire_reg(wb_inst_retire_reg),
    .WB_allowin     (WB_allowin)
);

// regfile instance
regfile u_regfile (
    .clk    (clk),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (wb_rf_wen),
    .waddr  (wb_rf_waddr),
    .wdata  (wb_rf_wdata)
);

// tie-off instruction sram write controls (read-only from CPU)
assign inst_sram_we    = 4'b0;
assign inst_sram_wdata = 32'b0;

// debug outputs from WB.inst_retire_reg
// inst_retire_reg format: { pc(32), {4{rf_wen}}(4), rf_waddr(5), rf_wdata(32) }
assign debug_wb_pc         = wb_inst_retire_reg[72:41];
assign debug_wb_rf_we      = wb_inst_retire_reg[40:37];
assign debug_wb_rf_wnum    = wb_inst_retire_reg[36:32];
assign debug_wb_rf_wdata   = wb_inst_retire_reg[31:0];

endmodule
