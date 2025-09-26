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

// internal pipeline buses
wire [64:0]  IF_to_ID_reg;
wire [181:0] ID_to_EX_reg;
wire [137:0] EX_to_MEM_reg;
wire [103:0] MEM_to_WB_reg;

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

// IF instance
IF u_IF (
    .clk        (clk),
    .rst        (reset),
    .flush      (ID_flush),
    .inst       (inst_sram_rdata),
    .pc_real    (ID_pc_real),
    .pc         (inst_sram_addr),    // IF's pc -> top inst_sram_addr
    .IF_to_ID_reg(IF_to_ID_reg)
);

// ID instance
ID u_ID (
    .clk            (clk),
    .rst            (reset),
    .IF_to_ID_bus   (IF_to_ID_reg),
    .rf_rdata1      (rf_rdata1),
    .rf_rdata2      (rf_rdata2),
    .rf_raddr1      (rf_raddr1),
    .rf_raddr2      (rf_raddr2),
    .flush          (ID_flush),
    .pc_real        (ID_pc_real),
    .ID_to_EX_reg   (ID_to_EX_reg)
);

// EX instance
EX u_EX (
    .clk            (clk),
    .rst            (reset),
    .ID_to_EX_bus   (ID_to_EX_reg),
    .EX_to_MEM_reg  (EX_to_MEM_reg)
);

// MEM instance (connect its memory read_data to data_sram_rdata, and drive data_sram_* outputs)
MEM u_MEM (
    .clk            (clk),
    .rst            (reset),
    .EX_to_MEM_bus  (EX_to_MEM_reg),
    .write_en       (data_sram_en),
    .write_we       (data_sram_we),
    .write_addr     (data_sram_addr),
    .write_data     (data_sram_wdata),
    .MEM_to_WB_reg  (MEM_to_WB_reg)
);

// WB instance
WB u_WB (
    .clk            (clk),
    .rst            (reset),
    .MEM_to_WB_bus  (MEM_to_WB_reg),
    .rf_wen         (wb_rf_wen),
    .rf_waddr       (wb_rf_waddr),
    .rf_wdata       (wb_rf_wdata),
    .inst_retire_reg(wb_inst_retire_reg),
    .read_data      (data_sram_rdata)
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
assign inst_sram_en    = 1'b1;
assign inst_sram_we    = 4'b0;
assign inst_sram_wdata = 32'b0;

// debug outputs from WB.inst_retire_reg
// inst_retire_reg format: { pc(32), {4{rf_wen}}(4), rf_waddr(5), rf_wdata(32) }
assign debug_wb_pc         = wb_inst_retire_reg[72:41];
assign debug_wb_rf_we      = wb_inst_retire_reg[40:37];
assign debug_wb_rf_wnum    = wb_inst_retire_reg[36:32];
assign debug_wb_rf_wdata   = wb_inst_retire_reg[31:0];

endmodule