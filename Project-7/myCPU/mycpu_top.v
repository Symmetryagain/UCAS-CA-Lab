module mycpu_top(
        input   wire            aclk,
        input   wire            aresetn,

        // ar    读请求通道
        output  wire [ 3:0]     arid,
        output  wire [31:0]     araddr,
        output  wire [ 7:0]     arlen,
        output  wire [ 2:0]     arsize,    
        output  wire [ 1:0]     arburst,
        output  wire [ 1:0]     arlock,
        output  wire [ 3:0]     arcache,
        output  wire [ 2:0]     arprot,
        output  wire            arvalid, 
        input   wire            arready,
        // r  读响应通道
        input   wire [ 3:0]     rid,
        input   wire [31:0]     rdata,
        input   wire [ 1:0]     rresp,
        input   wire            rlast,
        input   wire            rvalid,
        output  wire            rready,

        // aw  写请求通道
        output  wire [ 3:0]     awid,
        output  wire [31:0]     awaddr,
        output  wire [ 7:0]     awlen,
        output  wire [ 2:0]     awsize,
        output  wire [ 1:0]     awburst,
        output  wire [ 1:0]     awlock,
        output  wire [ 3:0]     awcache,
        output  wire [ 2:0]     awprot,
        output  wire            awvalid,
        input   wire            awready,

        // w  写数据通道
        output  wire [ 3:0]     wid,
        output  wire [31:0]     wdata,
        output  wire [ 3:0]     wstrb,
        output  wire            wlast,
        output  wire            wvalid,
        input   wire            wready,

        // b  写响应通道
        input   wire [ 3:0]     bid,
        input   wire [ 1:0]     bresp,
        input   wire            bvalid,
        output  wire            bready,

        // trace debug interface
        output  wire [31:0]     debug_wb_pc,
        output  wire [ 3:0]     debug_wb_rf_we,
        output  wire [ 4:0]     debug_wb_rf_wnum,
        output  wire [31:0]     debug_wb_rf_wdata
);

wire            clk;
reg             reset;

assign clk = aclk;
always @(posedge clk) begin 
        reset <= ~aresetn;
end

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

// I-Cache <-> CPU
wire            icache_valid;
wire            icache_op;
wire            icache_cacheable;
wire [ 7:0]     icache_index;
wire [19:0]     icache_tag;
wire [ 3:0]     icache_offset;
wire [ 3:0]     icache_wstrb;
wire [31:0]     icache_wdata;
wire            icache_addr_ok;
wire            icache_data_ok;
wire [31:0]     icache_rdata;

// I-Cache read
wire            icache_rd_req;
wire [ 2:0]     icache_rd_type;
wire [31:0]     icache_rd_addr;
wire            icache_rd_rdy;
wire            icache_ret_valid;
wire            icache_ret_last;
wire [31:0]     icache_ret_data;

// D-Cache <-> CPU
wire            dcache_valid;
wire            dcache_op;
wire            dcache_cacheable;
wire [ 7:0]     dcache_index;
wire [19:0]     dcache_tag;
wire [ 3:0]     dcache_offset;
wire [ 3:0]     dcache_wstrb;
wire [31:0]     dcache_wdata;
wire            dcache_addr_ok;
wire            dcache_data_ok;
wire [31:0]     dcache_rdata;

// D-Cache read
wire            dcache_rd_req;
wire [ 2:0]     dcache_rd_type;
wire [31:0]     dcache_rd_addr;
wire            dcache_rd_rdy;
wire            dcache_ret_valid;
wire            dcache_ret_last;
wire [31:0]     dcache_ret_data;

// D-Cache write
wire            dcache_wr_req;
wire [  2:0]    dcache_wr_type;
wire [ 31:0]    dcache_wr_addr;
wire [  3:0]    dcache_wr_wstrb;
wire [127:0]    dcache_wr_data;
wire            dcache_wr_rdy;

wire            inst_req;
wire [ 31:0]    pc_paddr;
wire            pc_cacheable;
wire            addr_cacheable;
wire            data_req;
wire [  3:0]    data_wstrb;
wire [ 31:0]    data_waddr;
wire [ 31:0]    data_wdata;
wire [ 31:0]    data_rdata;

// allowin
wire            ID_allowin;
wire            EX_allowin;
wire            MEM_allowin;
wire            WB_allowin;

// internal pipeline zipes
wire [ 65:0]    IF_to_ID_zip;
wire [284:0]    ID_to_EX_zip;
wire [264:0]    EX_to_MEM_zip;
wire [187:0]    MEM_to_WB_zip;

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
wire            except_tlbr;
wire            wb_ex;  
wire [31:0]     wb_pc;
wire [ 5:0]     wb_ecode;
wire [ 8:0]     wb_esubcode;
wire [31:0]     csr_eentry_data;
wire [31:0]     csr_tlbrentry_data;
wire [31:0]     csr_era_pc;
wire            flush;
wire [31:0]     flush_target;
wire            has_int;

wire            inst_tlbrd;
wire [31:0]     tlbehi_wdata;
wire [31:0]     tlbelo0_wdata;
wire [31:0]     tlbelo1_wdata;
wire [31:0]     tlbidx_wdata;
wire [31:0]     tlbasid_wdata;

wire [31:0]     csr_estat_data;
wire [31:0]     csr_tlbidx_data;
wire [31:0]     csr_tlbehi_data;
wire [31:0]     csr_tlbelo0_data;
wire [31:0]     csr_tlbelo1_data;

wire [ 3:0]     IF_except_zip;
wire [ 8:0]     ID_except_zip;
wire [14:0]     EX_except_zip;
wire [46:0]     MEM_except_zip;

wire [31:0]     wb_vaddr;
wire [31:0]     ex_vaddr;

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
wire [31:0]     addr_trans;

wire [31:0]     csr_dmw0_data;
wire [31:0]     csr_dmw1_data;
wire [31:0]     csr_asid_data;
wire [31:0]     csr_crmd_data;

wire [18:0]     s0_vppn;
wire            s0_va_bit12;
wire [ 9:0]     s0_asid;
wire            s0_found;
wire [ 3:0]     s0_index;
wire [19:0]     s0_ppn;
wire [ 5:0]     s0_ps;     
wire [ 1:0]     s0_plv;
wire [ 1:0]     s0_mat;
wire            s0_d;
wire            s0_v;

wire [18:0]     s1_vppn;
wire            s1_va_bit12;
wire [ 9:0]     s1_asid;
wire            s1_found;
wire [ 3:0]     s1_index;
wire [19:0]     s1_ppn;
wire [ 5:0]     s1_ps;     
wire [ 1:0]     s1_plv;
wire [ 1:0]     s1_mat;
wire            s1_d;
wire            s1_v;

wire [ 3:0]     r_index;
wire            r_e;
wire [18:0]     r_vppn;
wire [ 5:0]     r_ps;
wire [ 9:0]     r_asid;
wire            r_g;
wire [19:0]     r_ppn0;
wire [ 1:0]     r_plv0;
wire [ 1:0]     r_mat0;
wire            r_d0;
wire            r_v0;
wire [19:0]     r_ppn1;
wire [ 1:0]     r_plv1;
wire [ 1:0]     r_mat1;
wire            r_d1;
wire            r_v1;

wire            invtlb_valid;
wire [ 4:0]     invtlb_op;
wire            tlb_we;
wire [ 3:0]     w_index;
wire            w_e;
wire [18:0]     w_vppn;
wire [ 5:0]     w_ps;
wire [ 9:0]     w_asid;
wire            w_g;
wire [19:0]     w_ppn0;
wire [ 1:0]     w_plv0;
wire [ 1:0]     w_mat0;
wire            w_d0;
wire            w_v0;
wire [19:0]     w_ppn1;
wire [ 1:0]     w_plv1;
wire [ 1:0]     w_mat1;
wire            w_d1;
wire            w_v1;
wire            tlb_flush;
wire [31:0]     tlb_flush_target;

wire            cacop_ok_icache;
wire            cacop_ok_dcache;
wire            cacop_done;
wire            cacop_icache;
wire            cacop_dcache;
wire [ 4:0]     cacop_code;
wire [31:0]     cacop_addr;

assign flush    = ertn_flush | wb_ex | tlb_flush;
assign flush_target     = ertn_flush? csr_era_pc : 
                          wb_ex?      {32{except_tlbr}} & csr_tlbrentry_data | {32{~except_tlbr}} & csr_eentry_data : 
                          tlb_flush_target;

assign icache_valid     = inst_req;
assign icache_op        = 1'b0;
assign {
        icache_tag, 
        icache_index, 
        icache_offset
} = pc_paddr;

assign dcache_valid     = data_req;
assign dcache_op        = |data_wstrb;
assign {
        dcache_tag,
        dcache_index,
        dcache_offset
} = data_waddr;
assign dcache_wstrb     = data_wstrb;
assign dcache_wdata     = data_wdata;
assign data_rdata       = dcache_rdata;

assign cacop_done = cacop_icache & cacop_ok_icache | cacop_dcache & cacop_ok_dcache;

// inst_retire_reg format: { pc(32), {4{rf_wen}}(4), rf_waddr(5), rf_wdata(32) }
assign {
        debug_wb_pc,
        debug_wb_rf_we,
        debug_wb_rf_wnum,
        debug_wb_rf_wdata
} = wb_inst_retire;

// AXI bridge instance
bridge u_bridge (
        .aclk(aclk),
        .aresetn(aresetn),

        .icache_rd_req(icache_rd_req),
        .icache_rd_type(icache_rd_type),
        .icache_rd_addr(icache_rd_addr),
        .icache_rd_rdy(icache_rd_rdy),
        .icache_ret_valid(icache_ret_valid),
        .icache_ret_last(icache_ret_last),
        .icache_ret_data(icache_ret_data),

        .dcache_rd_req(dcache_rd_req),
        .dcache_rd_type(dcache_rd_type),
        .dcache_rd_addr(dcache_rd_addr),
        .dcache_rd_rdy(dcache_rd_rdy),
        .dcache_ret_valid(dcache_ret_valid),
        .dcache_ret_last(dcache_ret_last),
        .dcache_ret_data(dcache_ret_data),

        .dcache_wr_req(dcache_wr_req),
        .dcache_wr_type(dcache_wr_type),
        .dcache_wr_addr(dcache_wr_addr),
        .dcache_wr_wstrb(dcache_wr_wstrb),
        .dcache_wr_data(dcache_wr_data),
        .dcache_wr_rdy(dcache_wr_rdy),

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
        .inst           (icache_rdata),
        .ID_flush_target(ID_pc_real),
        .pc_paddr       (pc_paddr),
        .cacheable      (icache_cacheable),
        .IF_to_ID_zip   (IF_to_ID_zip),
        .IF_except_zip  (IF_except_zip),
        .ID_allowin     (ID_allowin),
        .icache_addr_ok (icache_addr_ok),
        .icache_data_ok (icache_data_ok),
        .pc_cacheable   (pc_cacheable),
        .inst_req       (inst_req),
        .flush          (flush),
        .flush_target   (flush_target),
        .IF_to_ID       (IF_to_ID),
        .pc_next        (pc_next),
        .pc_trans       (pc_trans),
        .except_tlbr    (except_tlbr_if),
        .except_pif     (except_pif),
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

        .front_valid    (EX_front_valid),
        .front_addr     (EX_front_addr),
        .front_data     (EX_front_data),
        .EX_allowin     (EX_allowin),
        .EX_is_csr      (EX_is_csr),
        .EX_is_load     (EX_is_load),

        .ID_to_EX       (ID_to_EX),
        .ID_to_EX_zip   (ID_to_EX_zip),
        .ID_except_zip  (ID_except_zip),
        .EX_to_MEM      (EX_to_MEM),
        .EX_to_MEM_zip  (EX_to_MEM_zip),
        .EX_except_zip  (EX_except_zip),

        .MEM_allowin    (MEM_allowin),

        .mmu_en         (mmu_en),
        .mem_we         (mem_we),
        .csr_asid_data  (csr_asid_data),
        .csr_tlbehi_data(csr_tlbehi_data),
        .csr_tlbidx_data(csr_tlbidx_data),
        .invtlb_valid   (invtlb_valid),
        .invtlb_op      (invtlb_op),

        .addr_trans     (ex_paddr),
        .addr_cacheable (addr_cacheable),
        .except_tlbr    (except_tlbr_ex),
        .except_pif_ex  (except_pif & cacop_icache),
        .except_pil     (except_pil),
        .except_pis     (except_pis),
        .except_pme     (except_pme),
        .except_ppi     (except_ppi_mem),

        .vaddr          (ex_vaddr),
        .s1_asid        (s1_asid),
        .s1_found       (s1_found),
        .s1_index       (s1_index),
        
        .flush          (flush),
        .counter        (counter),

        .cacop_icache   (cacop_icache),
        .cacop_dcache   (cacop_dcache),
        .cacop_code     (cacop_code),
        .cacop_addr     (cacop_addr),
        .cacop_done     (cacop_done)
);

// MEM instance
MEM u_MEM (
        .clk            (clk),
        .rst            (reset),
        .EX_to_MEM_zip  (EX_to_MEM_zip),
        .write_en       (data_req),
        .write_we       (data_wstrb),
        .write_addr     (data_waddr),
        .write_data     (data_wdata),
        .cacheable      (dcache_cacheable),
        .MEM_to_WB_zip  (MEM_to_WB_zip),
        .read_data      (data_rdata),
        .MEM_allowin    (MEM_allowin),
        .WB_allowin     (WB_allowin),
        .dcache_addr_ok     (dcache_addr_ok),
        .dcache_data_ok     (dcache_data_ok),
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
        .except_tlbr    (except_tlbr),
        .wb_pc          (wb_pc),
        .wb_ex          (wb_ex),
        .wb_ecode       (wb_ecode),
        .wb_esubcode    (wb_esubcode),
        .wb_vaddr       (wb_vaddr),

        .csr_rvalue     (csr_rvalue),
        .csr_estat_data (csr_estat_data),
        .csr_tlbidx_data    (csr_tlbidx_data),
        .csr_tlbehi_data    (csr_tlbehi_data),
        .csr_tlbelo0_data   (csr_tlbelo0_data),
        .csr_tlbelo1_data   (csr_tlbelo1_data),
        .csr_asid_data  (csr_asid_data),

        .tlb_flush      (tlb_flush),
        .tlb_flush_target   (tlb_flush_target),

        .tlbrd          (inst_tlbrd),
        .tlbehi_wdata   (tlbehi_wdata),
        .tlbelo0_wdata  (tlbelo0_wdata),
        .tlbelo1_wdata  (tlbelo1_wdata),
        .tlbidx_wdata   (tlbidx_wdata),
        .tlbasid_wdata  (tlbasid_wdata),

        .we             (tlb_we),
        .w_index        (w_index),
        .w_e            (w_e),
        .w_vppn         (w_vppn),
        .w_ps           (w_ps),
        .w_asid         (w_asid),
        .w_g            (w_g),
        .w_ppn0         (w_ppn0),
        .w_plv0         (w_plv0),
        .w_mat0         (w_mat0),
        .w_d0           (w_d0),
        .w_v0           (w_v0),
        .w_ppn1         (w_ppn1),
        .w_plv1         (w_plv1),
        .w_mat1         (w_mat1),
        .w_d1           (w_d1), 
        .w_v1           (w_v1),
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
csr u_csr (
        .clk        (clk),
        .reset      (~aresetn),

        .csr_re     (csr_re),
        .csr_num    (csr_num),
        .csr_rvalue (csr_rvalue),
        .csr_we     (csr_we),
        .csr_wmask  (csr_wmask),
        .csr_wvalue (csr_wvalue),

        .has_int    (has_int),
        .ertn_flush (ertn_flush), 
        .wb_ex      (wb_ex),
        .wb_pc      (wb_pc),
        .wb_vaddr   (wb_vaddr), 
        .wb_ecode   (wb_ecode),
        .wb_esubcode(wb_esubcode),
        .csr_eentry_data    (csr_eentry_data),
        .csr_tlbrentry_data (csr_tlbrentry_data),
        .csr_era_pc (csr_era_pc),

        .csr_dmw0_data      (csr_dmw0_data),
        .csr_dmw1_data      (csr_dmw1_data),
        .csr_asid_data      (csr_asid_data),
        .csr_crmd_data      (csr_crmd_data),

        .inst_tlbrd (inst_tlbrd),
        .tlbehi_wdata       (tlbehi_wdata),
        .tlbelo0_wdata      (tlbelo0_wdata),
        .tlbelo1_wdata      (tlbelo1_wdata),
        .tlbidx_wdata       (tlbidx_wdata),
        .tlbasid_wdata      (tlbasid_wdata),

        .csr_estat_data     (csr_estat_data),
        .csr_tlbidx_data    (csr_tlbidx_data),
        .csr_tlbehi_data    (csr_tlbehi_data),
        .csr_tlbelo0_data   (csr_tlbelo0_data),
        .csr_tlbelo1_data   (csr_tlbelo1_data)
);

wire            except_tlbr_ex;
wire [31:0]     inst_vaddr;
wire [31:0]     ex_paddr;
assign except_tlbr_ex = cacop_icache & except_tlbr_if | except_tlbr_mem;
assign inst_vaddr = cacop_icache? ex_vaddr: pc_next;
assign ex_paddr = cacop_icache? pc_trans: addr_trans;

// inst mmu instance
mmu u_inst_mmu (
        .mem_we         (1'b0),
        .mmu_en         (1'b1),
        .is_if          (1'b1),
        .vaddr          (inst_vaddr),
        .paddr          (pc_trans),
        .cacheable      (pc_cacheable),
        .s_vppn         (s0_vppn),
        .s_va_bit12     (s0_va_bit12),
        .s_asid         (s0_asid),
        .s_found        (s0_found),
        .s_index        (s0_index),
        .s_ppn          (s0_ppn),
        .s_ps           (s0_ps),     
        .s_plv          (s0_plv),
        .s_mat          (s0_mat),
        .s_d            (s0_d),
        .s_v            (s0_v),

        .csr_asid_data  (csr_asid_data),
        .csr_crmd_data  (csr_crmd_data),
        .csr_dmw0_data  (csr_dmw0_data),
        .csr_dmw1_data  (csr_dmw1_data),

        .except_tlbr    (except_tlbr_if),
        .except_pif     (except_pif),
        .except_pil     (),
        .except_pis     (),
        .except_pme     (),
        .except_ppi     (except_ppi_if)
);

// data mmu instance
mmu u_data_mmu (
        .mem_we         (mem_we),
        .mmu_en         (mmu_en),
        .is_if          (1'b0),
        .vaddr          (ex_vaddr),
        .paddr          (addr_trans),
        .cacheable      (addr_cacheable),
        .s_vppn         (s1_vppn),
        .s_va_bit12     (s1_va_bit12),
        .s_asid         (),
        .s_found        (s1_found),
        .s_index        (s1_index),
        .s_ppn          (s1_ppn),
        .s_ps           (s1_ps),     
        .s_plv          (s1_plv),
        .s_mat          (s1_mat),
        .s_d            (s1_d),
        .s_v            (s1_v),

        .csr_asid_data  (csr_asid_data),
        .csr_crmd_data  (csr_crmd_data),
        .csr_dmw0_data  (csr_dmw0_data),
        .csr_dmw1_data  (csr_dmw1_data),

        .except_tlbr    (except_tlbr_mem),
        .except_pif     (),
        .except_pil     (except_pil),
        .except_pis     (except_pis),
        .except_pme     (except_pme),
        .except_ppi     (except_ppi_mem)
);

// tlb instance
tlb u_tlb (
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

        .invtlb_valid   (invtlb_valid),    
        .invtlb_op      (invtlb_op),
        .we             (tlb_we),
        .w_index        (w_index),
        .w_e            (w_e),
        .w_vppn         (w_vppn),
        .w_ps           (w_ps),
        .w_asid         (w_asid),
        .w_g            (w_g),
        .w_ppn0         (w_ppn0),
        .w_plv0         (w_plv0),
        .w_mat0         (w_mat0),
        .w_d0           (w_d0),
        .w_v0           (w_v0),
        .w_ppn1         (w_ppn1),
        .w_plv1         (w_plv1),
        .w_mat1         (w_mat1),
        .w_d1           (w_d1), 
        .w_v1           (w_v1),
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

// I-Cache instance
cache u_I_Cache (
        .clk    (clk),
        .resetn (~reset),
        .valid  (icache_valid),
        .op     (icache_op),
        .cacheable      (icache_cacheable),
        .index  (icache_index),
        .tag    (icache_tag),
        .offset (icache_offset),
        .wstrb  (4'b0),
        .wdata  (32'b0),
        .cacop_en       (cacop_icache),
        .cacop_code     (cacop_code),
        .cacop_addr     (cacop_addr),
        .cacop_ok       (cacop_ok_icache),
        .addr_ok        (icache_addr_ok),
        .data_ok        (icache_data_ok),
        .rdata  (icache_rdata),
        .rd_req (icache_rd_req),
        .rd_type        (icache_rd_type),
        .rd_addr        (icache_rd_addr),
        .rd_rdy (icache_rd_rdy),
        .ret_valid      (icache_ret_valid),
        .ret_last       (icache_ret_last),
        .ret_data       (icache_ret_data),
        .wr_req (),
        .wr_type        (),
        .wr_addr        (),
        .wr_wstrb       (),
        .wr_data        (),
        .wr_rdy (1'b0)
);

// D-Cache instance
cache u_D_Cache (
        .clk    (clk),
        .resetn (~reset),
        .valid  (dcache_valid),
        .op     (dcache_op),
        .cacheable      (dcache_cacheable),
        .index  (dcache_index),
        .tag    (dcache_tag),
        .offset (dcache_offset),
        .wstrb  (dcache_wstrb),
        .wdata  (dcache_wdata),
        .cacop_en       (cacop_dcache),
        .cacop_code     (cacop_code),
        .cacop_addr     (cacop_addr),
        .cacop_ok       (cacop_ok_dcache),
        .addr_ok        (dcache_addr_ok),
        .data_ok        (dcache_data_ok),
        .rdata  (dcache_rdata),
        .rd_req (dcache_rd_req),
        .rd_type        (dcache_rd_type),
        .rd_addr        (dcache_rd_addr),
        .rd_rdy (dcache_rd_rdy),
        .ret_valid      (dcache_ret_valid),
        .ret_last       (dcache_ret_last),
        .ret_data       (dcache_ret_data),
        .wr_req (dcache_wr_req),
        .wr_type        (dcache_wr_type),
        .wr_addr        (dcache_wr_addr),
        .wr_wstrb       (dcache_wr_wstrb),
        .wr_data        (dcache_wr_data),
        .wr_rdy (dcache_wr_rdy)
);

endmodule