module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    // output wire        inst_sram_req    ,
    // output wire        inst_sram_wr     ,
    // output wire [ 1:0] inst_sram_size   ,
    // output wire [ 3:0] inst_sram_wstrb  ,
    // output wire [31:0] inst_sram_addr   ,
    // output wire [31:0] inst_sram_wdata  ,
    // input  wire        inst_sram_addr_ok,
    // input  wire        inst_sram_data_ok,
    // input  wire [31:0] inst_sram_rdata  ,
    
    // output wire        data_sram_req    ,
    // output wire        data_sram_wr     ,
    // output wire [ 1:0] data_sram_size   ,
    // output wire [ 3:0] data_sram_wstrb  ,
    // output wire [31:0] data_sram_addr   ,
    // output wire [31:0] data_sram_wdata  ,
    // input  wire        data_sram_addr_ok,
    // input  wire        data_sram_data_ok,
    // input  wire [31:0] data_sram_rdata  ,

     // ar    读请求通道
    output    [3:0]    arid,
    output    [31:0]   araddr,
    output    [7:0]    arlen,
    output    [2:0]    arsize,    
    output    [1:0]    arburst,
    output    [1:0]    arlock,
    output    [3:0]    arcache,
    output    [2:0]    arprot,
    output             arvalid, 
    input              arready,
    // r  读响应通道
    input  [3:0]       rid,
    input  [31:0]      rdata,
    input  [1:0]       rresp,
    input              rlast,
    input              rvalid,
    output             rready,

    // aw  写请求通道
    output    [3:0]    awid,
    output    [31:0]   awaddr,
    output    [7:0]    awlen,
    output    [2:0]    awsize,
    output    [1:0]    awburst,
    output    [1:0]    awlock,
    output    [3:0]    awcache,
    output    [2:0]    awprot,
    output             awvalid,
    input              awready,

    // w  写数据通道
    output    [3:0]    wid,
    output    [31:0]   wdata,
    output    [3:0]    wstrb,
    output             wlast,
    output             wvalid,
    input              wready,

    // b  写响应通道
    input  [3:0]       bid,
    input  [1:0]       bresp,
    input              bvalid,
    output             bready,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire            clk;
reg             reset;

assign clk = aclk;
always @(posedge clk) 
    reset <= ~aresetn;

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

// SRAM
wire            inst_sram_req;
wire            inst_sram_wr;
wire [ 1:0]     inst_sram_size;
wire [31:0]     inst_sram_addr;
wire [ 3:0]     inst_sram_wstrb;
wire [31:0]     inst_sram_wdata;
wire [31:0]     inst_sram_rdata;
wire            inst_sram_addr_ok;
wire            inst_sram_data_ok;

wire            data_sram_req;
wire            data_sram_wr;
wire [ 1:0]     data_sram_size;
wire [31:0]     data_sram_addr;
wire [ 3:0]     data_sram_wstrb;
wire [31:0]     data_sram_wdata;
wire [31:0]     data_sram_rdata;
wire            data_sram_addr_ok;
wire            data_sram_data_ok;

// allowin
wire            ID_allowin;
wire            EX_allowin;
wire            MEM_allowin;
wire            WB_allowin;

// internal pipeline zipes
wire [ 65:0]    IF_to_ID_zip;
wire [198:0]    ID_to_EX_zip;
wire [145:0]    EX_to_MEM_zip;
wire [102:0]    MEM_to_WB_zip;

// IF <-> ID signals
wire            ID_flush;
wire [31:0]     ID_pc_real;

// regfile <-> ID / WB
wire [ 4:0]     rf_raddr1;
wire [ 4:0]     rf_raddr2;
wire [31:0]     rf_rdata1;
wire [31:0]     rf_rdata2;

wire            wb_rf_wen;
wire [ 4:0]     wb_rf_waddr;
wire [31:0]     wb_rf_wdata;

// WB inst_retire
wire [72:0]     wb_inst_retire;

wire            EX_front_valid;
wire [ 4:0]     EX_front_addr;
wire [31:0]     EX_front_data;
wire            MEM_front_valid;
wire [ 4:0]     MEM_front_addr;
wire [31:0]     MEM_front_data;
wire            MEM_done;

// csr signals
wire            csr_re;
wire [13:0]     csr_num;
wire [31:0]     csr_rvalue;
wire            csr_we;
wire [31:0]     csr_wmask;
wire [31:0]     csr_wvalue;
wire            ertn_flush;
wire            wb_ex;  
wire [31:0]     wb_pc;
wire [ 5:0]     wb_ecode;
wire [ 8:0]     wb_esubcode;
wire [31:0]     csr_eentry_data;
wire [31:0]     csr_era_pc;
wire            flush;
wire [31:0]     flush_target;
wire            has_int;

wire            inst_tlbrd;
wire [31:0]     tlbehi_wdata;
wire [31:0]     tlbelo0_wdata;
wire [31:0]     tlbelo1_wdata;
wire [31:0]     tlbidx_wdata;

wire [31:0]     csr_estat_data;
wire [31:0]     csr_tlbidx_data;
wire [31:0]     csr_tlbehi_data;
wire [31:0]     csr_tlbelo0_data;
wire [31:0]     csr_tlbelo1_data;

wire [  4:0]    IF_except_zip;
wire [ 89:0]    ID_except_zip;
wire [ 90:0]    EX_except_zip;
wire [122:0]    MEM_except_zip;

wire [31:0]     wb_vaddr;

wire            IF_to_ID;
wire            ID_to_EX;
wire            EX_to_MEM;
wire            MEM_to_WB;
wire            EX_is_csr;
wire            EX_is_load;
wire            MEM_is_csr;
wire            MEM_is_load;

wire [31:0]     pc_next;
wire [31:0]     pc_trans;
wire            except_tlbr_if;
wire            except_tlbr_mem;
wire            except_pif;
wire            except_pil;
wire            except_pis;
wire            except_pme;
wire            except_ppi_if;
wire            except_ppi_mem;

wire            mem_we;
wire            mmu_en;

// AXI bridge instance
bridge u_bridge (
    .aclk(aclk),
    .aresetn(aresetn),

    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),

    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_addr(data_sram_addr),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),

    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

// IF instance
IF u_IF (
    .clk            (clk),
    .rst            (reset),
    .ID_flush       (ID_flush),
    .inst           (inst_sram_rdata),
    .ID_flush_target(ID_pc_real),
    .pc_paddr       (inst_sram_addr),
    .IF_to_ID_zip   (IF_to_ID_zip),
    .IF_except_zip  (IF_except_zip),
    .ID_allowin     (ID_allowin),
    .inst_sram_addr_ok     (inst_sram_addr_ok),
    .inst_sram_data_ok     (inst_sram_data_ok),
    .inst_sram_en   (inst_sram_req),
    .flush          (flush),
    .flush_target   (flush_target),
    .IF_to_ID       (IF_to_ID),
    .pc_next        (pc_next),
    .pc_trans       (pc_trans),
    .except_tlbr    (except_tlbr_if),
    .except_pif     (except_pif),
    .except_pme     (except_pme),
    .except_ppi     (except_ppi_if)
);

// ID instance
ID u_ID (
    .clk            (clk),
    .rst            (reset),
    .IF_to_ID_zip   (IF_to_ID_zip),
    .IF_except_zip  (IF_except_zip),
    .front_from_EX_valid (EX_front_valid),
    .front_from_EX_addr  (EX_front_addr),
    .front_from_EX_data  (EX_front_data),
    .front_from_MEM_valid(MEM_front_valid),
    .front_from_MEM_addr (MEM_front_addr),
    .front_from_MEM_data (MEM_front_data),
    .mem_done       (MEM_done),
    .rf_rdata1      (rf_rdata1),
    .rf_rdata2      (rf_rdata2),
    .rf_raddr1      (rf_raddr1),
    .rf_raddr2      (rf_raddr2),
    .has_int        (has_int),
    .ID_flush       (ID_flush),
    .ID_flush_target(ID_pc_real),
    .ID_to_EX_zip   (ID_to_EX_zip),
    .ID_allowin     (ID_allowin),
    .EX_allowin     (EX_allowin),
    .flush          (flush),
    .ID_except_zip  (ID_except_zip),
    .IF_to_ID       (IF_to_ID),
    .ID_to_EX       (ID_to_EX),
    .EX_is_csr      (EX_is_csr),
    .EX_is_load     (EX_is_load),
    .MEM_is_csr     (MEM_is_csr),
    .MEM_is_load    (MEM_is_load)
);

// EX instance
EX u_EX (
    .clk            (clk),
    .rst            (reset),
    .ID_to_EX_zip   (ID_to_EX_zip),
    .EX_to_MEM_zip  (EX_to_MEM_zip),
    .EX_allowin     (EX_allowin),
    .MEM_allowin    (MEM_allowin),
    .front_valid    (EX_front_valid),
    .front_addr     (EX_front_addr),
    .front_data     (EX_front_data),
    .flush          (flush),
    .ID_except_zip  (ID_except_zip),
    .EX_except_zip  (EX_except_zip),
    .counter        (counter),
    .ID_to_EX       (ID_to_EX),
    .EX_to_MEM      (EX_to_MEM),
    .EX_is_csr      (EX_is_csr),
    .EX_is_load     (EX_is_load)
);

// MEM instance
MEM u_MEM (
    .clk            (clk),
    .rst            (reset),
    .EX_to_MEM_zip  (EX_to_MEM_zip),
    .write_en       (data_sram_req),
    .write_we       (data_sram_wstrb),
    .write_size     (data_sram_size),
    .write_addr     (data_sram_addr),
    .write_data     (data_sram_wdata),
    .MEM_to_WB_zip  (MEM_to_WB_zip),
    .read_data      (data_sram_rdata),
    .MEM_allowin    (MEM_allowin),
    .WB_allowin     (WB_allowin),
    .data_sram_addr_ok     (data_sram_addr_ok),
    .data_sram_data_ok     (data_sram_data_ok),
    .front_valid    (MEM_front_valid),
    .front_addr     (MEM_front_addr),
    .front_data     (MEM_front_data),
    .MEM_done       (MEM_done),
    .flush          (flush),
    .EX_except_zip  (EX_except_zip),
    .MEM_except_zip (MEM_except_zip),
    .EX_to_MEM      (EX_to_MEM),
    .MEM_to_WB      (MEM_to_WB),
    .MEM_is_csr     (MEM_is_csr),
    .MEM_is_load    (MEM_is_load)
);

// WB instance
WB u_WB (
    .clk            (clk),
    .rst            (reset),

    .MEM_to_WB      (MEM_to_WB),
    .MEM_to_WB_zip  (MEM_to_WB_zip),
    .MEM_except_zip (MEM_except_zip),
    .WB_allowin     (WB_allowin),

    .rf_wen         (wb_rf_wen),
    .rf_waddr       (wb_rf_waddr),
    .rf_wdata_final (wb_rf_wdata),
    .inst_retire    (wb_inst_retire),

    .csr_re         (csr_re),
    .csr_num        (csr_num),
    .csr_we         (csr_we),
    .csr_wmask      (csr_wmask),
    .csr_wvalue     (csr_wvalue),
    .ertn_flush     (ertn_flush),
    .wb_pc          (wb_pc),
    .wb_ex          (wb_ex),
    .wb_ecode       (wb_ecode),
    .wb_esubcode    (wb_esubcode),
    .wb_vaddr       (wb_vaddr),
    .csr_rvalue     (csr_rvalue),

    .inst_tlbrd     (inst_tlbrd),
    .tlbehi_wdata   (tlbehi_wdata),
    .tlbelo0_wdata  (tlbelo0_wdata),
    .tlbelo1_wdata  (tlbelo1_wdata),
    .tlbidx_wdata   (tlbidx_wdata)
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
    .reset     (~aresetn),

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
    .csr_era_pc (csr_era_pc),

    .csr_dmw0_data(csr_dmw0_data),
    .csr_dmw1_data(csr_dmw1_data),
    .csr_asid_data(csr_asid_data),
    .csr_crmd_data(csr_crmd_data),

    .inst_tlbrd(inst_tlbrd),
    .tlbehi_wdata(tlbehi_wdata),
    .tlbelo0_wdata(tlbelo0_wdata),
    .tlbelo1_wdata(tlbelo1_wdata),
    .tlbidx_wdata (tlbidx_wdata),

    .csr_estat_data(csr_estat_data),
    .csr_tlbidx_data(csr_tlbidx_data),
    .csr_tlbehi_data(csr_tlbehi_data),
    .csr_tlbelo0_data(csr_tlbelo0_data),
    .csr_tlbelo1_data(csr_tlbelo1_data)
);

assign flush = ertn_flush | wb_ex;
assign flush_target = ertn_flush ? csr_era_pc : csr_eentry_data;

// tie-off instruction sram write controls (read-only from CPU)
assign inst_sram_wstrb = 4'b0;
assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = | inst_sram_wstrb;
assign inst_sram_size  = 2'b10;
assign data_sram_wr    = | data_sram_wstrb;

wire [31:0] csr_dmw0_data;
wire [31:0] csr_dmw1_data;
wire [31:0] csr_asid_data;
wire [31:0] csr_crmd_data;

wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [9:0]  s0_asid;
wire        s0_found;
wire [3:0]  s0_index;
wire [19:0] s0_ppn;
wire [5:0]  s0_ps;     
wire [1:0]  s0_plv;
wire [1:0]  s0_mat;
wire        s0_d;
wire        s0_v;

wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [9:0]  s1_asid;
wire        s1_found;
wire [3:0]  s1_index;
wire [19:0] s1_ppn;
wire [5:0]  s1_ps;     
wire [1:0]  s1_plv;
wire [1:0]  s1_mat;
wire        s1_d;
wire        s1_v;

wire [3:0]  r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [5:0]  r_ps;
wire [9:0]  r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [1:0]  r_plv0;
wire [1:0]  r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [1:0]  r_plv1;
wire [1:0]  r_mat1;
wire        r_d1;
wire        r_v1;

wire [3:0]  w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [5:0]  w_ps;
wire [9:0]  w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [1:0]  w_plv0;
wire [1:0]  w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [1:0]  w_plv1;
wire [1:0]  w_mat1;
wire        w_d1;
wire        w_v1;

// tlb instance
tlb u_tlb(
    .clk            (clk),
    .s0_vppn        (s0_vppn),
    .s0_va_bit12    (s0_va_bit12),
    .s0_asid        (s0_asid),
    .s0_found       (s0_found),
    .s0_index       (s0_index),
    .s0_ppn         (s0_ppn),
    .s0_ps          (s0_ps),     
    .s0_plv         (s0_plv),
    .s0_mat         (s0_mat),
    .s0_d           (s0_d),
    .s0_v           (s0_v),

    .s1_vppn        (s1_vppn),
    .s1_va_bit12    (s1_va_bit12),
    .s1_asid        (s1_asid),
    .s1_found       (s1_found),
    .s1_index       (s1_index),
    .s1_ppn         (s1_ppn),
    .s1_ps          (s1_ps),     
    .s1_plv         (s1_plv),
    .s1_mat         (s1_mat),
    .s1_d           (s1_d),
    .s1_v           (s1_v),

    .invtlb_valid   (),    
    .invtlb_op      (),
    .we             (),
    .w_index        (),
    .w_e            (),
    .w_vppn         (),
    .w_ps           (),
    .w_asid         (),
    .w_g            (),
    .w_ppn0         (),
    .w_plv0         (),
    .w_mat0         (),
    .w_d0           (),
    .w_v0           (),
    .w_ppn1         (),
    .w_plv1         (),
    .w_mat1         (),
    .w_d1           (), 
    .w_v1           (),
    .r_index        (r_index),
    .r_e            (r_e),
    .r_vppn         (r_vppn),
    .r_ps           (r_ps),
    .r_asid         (r_asid),
    .r_g            (r_g),
    .r_ppn0         (r_ppn0),
    .r_plv0         (r_plv0),
    .r_mat0         (r_mat0),
    .r_d0           (r_d0),
    .r_v0           (r_v0),
    .r_ppn1         (r_ppn1),
    .r_plv1         (r_plv1),
    .r_mat1         (r_mat1),
    .r_d1           (r_d1),
    .r_v1           (r_v1)   
);

// inst_retire_reg format: { pc(32), {4{rf_wen}}(4), rf_waddr(5), rf_wdata(32) }
assign {
        debug_wb_pc,
        debug_wb_rf_we,
        debug_wb_rf_wnum,
        debug_wb_rf_wdata
} = wb_inst_retire;

endmodule