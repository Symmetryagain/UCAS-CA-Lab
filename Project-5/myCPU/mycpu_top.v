module mycpu_top(
    input  wire        clk,
    input  wire        resetn,

    output wire        inst_sram_req    ,
    output wire        inst_sram_wr     ,
    output wire [ 1:0] inst_sram_size   ,
    output wire [ 3:0] inst_sram_wstrb  ,
    output wire [31:0] inst_sram_addr   ,
    output wire [31:0] inst_sram_wdata  ,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata  ,
    
    output wire        data_sram_req    ,
    output wire        data_sram_wr     ,
    output wire [ 1:0] data_sram_size   ,
    output wire [ 3:0] data_sram_wstrb  ,
    output wire [31:0] data_sram_addr   ,
    output wire [31:0] data_sram_wdata  ,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata  ,
    
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg             reset;
always @(posedge clk) reset <= ~resetn;

// counter 
reg  [63:0]     counter;
always @(posedge clk) begin
    if (reset) begin
        counter <= 64'b0;
    end
    else begin
        counter <= counter + 64'b1;
    end
end

// allowin
wire            ID_allowin;
wire            EX_allowin;
wire            MEM_allowin;
wire            WB_allowin;

// internal pipeline zipes
wire [66:0]     IF_to_ID_reg;
wire [197:0]    ID_to_EX_reg;
wire [144:0]    EX_to_MEM_reg;
wire [102:0]    MEM_to_WB_reg;

// IF <-> ID signals
wire            ID_flush;
wire [31:0]     ID_pc_real;

// regfile <-> ID / WB
wire [4:0]      rf_raddr1;
wire [4:0]      rf_raddr2;
wire [31:0]     rf_rdata1;
wire [31:0]     rf_rdata2;

wire            wb_rf_wen;
wire [4:0]      wb_rf_waddr;
wire [31:0]     wb_rf_wdata;

// WB inst_retire
wire [72:0]     wb_inst_retire_reg;

wire            EX_front_valid;
wire [ 4:0]     EX_front_addr;
wire [31:0]     EX_front_data;
wire            MEM_front_valid;
wire [ 4:0]     MEM_front_addr;
wire [31:0]     MEM_front_data;
wire            MEM_done;
wire [31:0]     loaded_data;

wire [31:0]     done_pc;

// csr signals
wire            csr_re;
wire [13:0]     csr_num;
wire [31:0]     csr_rvalue;
wire            csr_we;
wire [31:0]     csr_wmask;
wire [31:0]     csr_wvalue;
wire            ertn_flush;
wire            wb_ex;  
wire  [31:0]    wb_pc;
wire  [ 5:0]    wb_ecode;
wire  [ 8:0]    wb_esubcode;
wire  [31:0]    csr_eentry_data;
wire  [31:0]    csr_era_pc;
wire            flush;
wire  [31:0]    flush_target;
wire            has_int;
// wire            load_use_valid;
// wire  [ 4:0]    load_use_addr;
// wire  [31:0]    load_use_data;

wire  [85:0]    ID_except_zip;
wire  [86:0]    EX_except_zip;
wire  [118:0]   MEM_except_zip;

wire  [31:0]    wb_vaddr;

wire            IF_to_ID;
wire            ID_to_EX;
wire            EX_to_MEM;
wire            MEM_to_WB;


// IF instance
IF u_IF (
    .clk            (clk),
    .rst            (reset),
    .ID_flush       (ID_flush),
    .inst           (inst_sram_rdata),
    .ID_flush_target(ID_pc_real),
    .pc             (inst_sram_addr),
    .IF_to_ID_reg   (IF_to_ID_reg),
    .ID_allowin     (ID_allowin),
    .inst_sram_addr_ok     (inst_sram_addr_ok),
    .inst_sram_data_ok     (inst_sram_data_ok),
    .inst_sram_en   (inst_sram_req),
    .flush          (flush),
    .flush_target   (flush_target),
    .IF_to_ID       (IF_to_ID)
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
    .mem_done       (MEM_done),
    .last_load_data (loaded_data),
    .rf_rdata1      (rf_rdata1),
    .rf_rdata2      (rf_rdata2),
    .rf_raddr1      (rf_raddr1),
    .rf_raddr2      (rf_raddr2),
    .has_int        (has_int),
    .ID_flush       (ID_flush),
    .ID_flush_target(ID_pc_real),
    .ID_to_EX_reg   (ID_to_EX_reg),
    .ID_allowin     (ID_allowin),
    .EX_allowin     (EX_allowin),
    .done_pc        (done_pc),
    .flush          (flush),
    .ID_except_reg  (ID_except_zip),
    .IF_to_ID       (IF_to_ID),
    .ID_to_EX       (ID_to_EX)
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
    .front_data     (EX_front_data),
    .flush          (flush),
    .ID_except_zip  (ID_except_zip),
    .EX_except_reg  (EX_except_zip),
    .counter        (counter),
    .ID_to_EX       (ID_to_EX),
    .EX_to_MEM      (EX_to_MEM)
);

// MEM instance (connect its memory read_data to data_sram_rdata, and drive data_sram_* outputs)
MEM u_MEM (
    .clk            (clk),
    .rst            (reset),
    .EX_to_MEM_zip  (EX_to_MEM_reg),
    .write_en       (data_sram_req),
    .write_we       (data_sram_wstrb),
    .write_size     (data_sram_size),
    .write_addr     (data_sram_addr),
    .write_data     (data_sram_wdata),
    .MEM_to_WB_reg  (MEM_to_WB_reg),
    .read_data      (data_sram_rdata),
    .MEM_allowin    (MEM_allowin),
    .WB_allowin     (WB_allowin),
    .data_sram_addr_ok     (data_sram_addr_ok),
    .data_sram_data_ok     (data_sram_data_ok),
    .front_valid    (MEM_front_valid),
    .front_addr     (MEM_front_addr),
    .front_data     (MEM_front_data),
    .MEM_done       (MEM_done),
    .loaded_data    (loaded_data),
    .done_pc        (done_pc),
    .flush          (flush),
    .EX_except_zip  (EX_except_zip),
    .MEM_except_reg (MEM_except_zip),
    .EX_to_MEM      (EX_to_MEM),
    .MEM_to_WB      (MEM_to_WB)
);

// WB instance
WB u_WB (
    .clk            (clk),
    .rst            (reset),
    .MEM_to_WB_zip  (MEM_to_WB_reg),
    .rf_wen         (wb_rf_wen),
    .rf_waddr       (wb_rf_waddr),
    .rf_wdata_final (wb_rf_wdata),
    .inst_retire_reg(wb_inst_retire_reg),
    .WB_allowin     (WB_allowin),
    .MEM_except_zip (MEM_except_zip),
    .csr_re         (csr_re),
    .csr_num        (csr_num),
    .csr_rvalue     (csr_rvalue),
    .csr_we         (csr_we),
    .csr_wmask      (csr_wmask),
    .csr_wvalue     (csr_wvalue),
    .ertn_flush     (ertn_flush),
    .wb_pc          (wb_pc),
    .wb_ex          (wb_ex),
    .wb_ecode       (wb_ecode),
    .wb_esubcode    (wb_esubcode),
    .wb_vaddr       (wb_vaddr),
    .MEM_to_WB      (MEM_to_WB)
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

// csr instance
csr u_csr(
    .clk       (clk),
    .reset     (~resetn),

    .csr_re    (csr_re),
    .csr_num   (csr_num),
    .csr_rvalue(csr_rvalue),
    .csr_we    (csr_we),
    .csr_wmask (csr_wmask),
    .csr_wvalue(csr_wvalue),

    .has_int   (has_int),
    .ertn_flush(ertn_flush), 
    .wb_ex     (wb_ex),
    .wb_pc     (wb_pc),
    .wb_vaddr  (wb_vaddr), 
    .wb_ecode  (wb_ecode),
    .wb_esubcode(wb_esubcode),
    .csr_eentry_data(csr_eentry_data),
    .csr_era_pc (csr_era_pc)
);

assign flush = ertn_flush | wb_ex;
assign flush_target = ertn_flush ? csr_era_pc : csr_eentry_data;

// tie-off instruction sram write controls (read-only from CPU)
assign inst_sram_wstrb = 4'b0;
assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = | inst_sram_wstrb;
assign inst_sram_size  = 2'b10;
assign data_sram_wr    = | data_sram_wstrb;

// debug outputs from WB.inst_retire_reg
// inst_retire_reg format: { pc(32), {4{rf_wen}}(4), rf_waddr(5), rf_wdata(32) }
assign debug_wb_pc         = wb_inst_retire_reg[72:41];
assign debug_wb_rf_we      = wb_inst_retire_reg[40:37];
assign debug_wb_rf_wnum    = wb_inst_retire_reg[36:32];
assign debug_wb_rf_wdata   = wb_inst_retire_reg[31:0];

endmodule
