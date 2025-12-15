`include "macros.h"

module csr(
        input   wire            clk,
        input   wire            reset,
        input   wire            csr_re,
        input   wire [13:0]     csr_num,
        output  wire [31:0]     csr_rvalue,
        input   wire            csr_we,
        input   wire [31:0]     csr_wmask,
        input   wire [31:0]     csr_wvalue,

        output  wire            has_int,
        input   wire            ertn_flush,
        input   wire            wb_ex,  
        input   wire  [31:0]    wb_pc,
        input   wire  [31:0]    wb_vaddr,
        input   wire  [ 5:0]    wb_ecode,  
        input   wire  [ 8:0]    wb_esubcode,
        output  wire  [31:0]    csr_eentry_data,
        output  wire  [31:0]    csr_tlbrentry_data,
        output  reg   [31:0]    csr_era_pc,

        output  wire  [31:0]    csr_dmw0_data,
        output  wire  [31:0]    csr_dmw1_data,
        output  wire  [31:0]    csr_asid_data,
        output  wire  [31:0]    csr_crmd_data,

        input   wire            inst_tlbrd,
        input   wire  [31:0]    tlbehi_wdata,
        input   wire  [31:0]    tlbelo0_wdata,
        input   wire  [31:0]    tlbelo1_wdata,
        input   wire  [31:0]    tlbidx_wdata,
        input   wire  [31:0]    tlbasid_wdata,
        
        output  wire  [31:0]    csr_estat_data,
        output  wire  [31:0]    csr_tlbidx_data,
        output  wire  [31:0]    csr_tlbehi_data,
        output  wire  [31:0]    csr_tlbelo0_data,
        output  wire  [31:0]    csr_tlbelo1_data
);

reg  [ 1: 0] csr_crmd_plv;      
reg          csr_crmd_ie;       
reg          csr_crmd_da;       
reg          csr_crmd_pg;
reg  [ 6: 5] csr_crmd_datf;
reg  [ 8: 7] csr_crmd_datm;

wire [31: 0] csr_prmd_data;
reg  [ 1: 0] csr_prmd_pplv;     
reg          csr_prmd_pie; 

reg  [12: 0] csr_estat_is;      
reg  [ 5: 0] csr_estat_ecode;   
reg  [ 8: 0] csr_estat_esubcode;
reg  [25: 0] csr_eentry_va;  

reg  [31: 0] csr_save0_data;
reg  [31: 0] csr_save1_data;
reg  [31: 0] csr_save2_data;
reg  [31: 0] csr_save3_data;

wire [ 7: 0] hw_int_in;
wire         ipi_int_in;
reg  [31: 0] timer_cnt;

reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [29:0]  csr_tcfg_initval;
wire [31:0]  tcfg_next_value;

wire         wb_ex_addr_err;
reg  [31:0]  csr_badv_vaddr;
wire [31:0]  csr_tval;
reg  [12:0]  csr_ecfg_lie;
wire [31:0]  csr_ecfg_data;

reg  [31:0]  csr_tid_tid;
wire [31:0]  csr_tcfg_data;
wire         csr_ticlr_clr;
wire [31:0]  csr_ticlr_data;

reg  [15:0]  csr_tlbidx_index;
reg          csr_tlbidx_ne;
reg  [5:0]   csr_tlbidx_ps;

reg  [18:0]  csr_tlbehi_vppn;

reg  [19:0]  csr_tlbelo0_ppn;
reg  [ 1:0]  csr_tlbelo0_plv;
reg  [ 1:0]  csr_tlbelo0_mat;
reg          csr_tlbelo0_g;
reg          csr_tlbelo0_d;
reg          csr_tlbelo0_v;

reg  [19:0]  csr_tlbelo1_ppn;
reg  [ 1:0]  csr_tlbelo1_plv;   
reg  [ 1:0]  csr_tlbelo1_mat;
reg          csr_tlbelo1_g;
reg          csr_tlbelo1_d;
reg          csr_tlbelo1_v;

reg  [9:0]   csr_asid_asid;
reg  [7:0]   csr_asid_asidbits;

reg  [25:0]  csr_tlbrentry_pa;

reg    csr_dmw0_plv0;
reg    csr_dmw0_plv3;
reg  [1:0] csr_dmw0_mat;
reg  [2:0] csr_dmw0_pseg;
reg  [2:0] csr_dmw0_vseg;

reg    csr_dmw1_plv0;
reg    csr_dmw1_plv3;
reg  [1:0] csr_dmw1_mat;
reg  [2:0] csr_dmw1_pseg;
reg  [2:0] csr_dmw1_vseg;

// TLBIDX
always @(posedge clk) begin
    if (reset) begin
        csr_tlbidx_ne <= 1'b0;
        csr_tlbidx_index <= 16'b0;
        csr_tlbidx_ps <= 6'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX]&csr_wvalue[`CSR_TLBIDX_INDEX]
                         | ~csr_wmask[`CSR_TLBIDX_INDEX]&csr_tlbidx_index;
        csr_tlbidx_ne    <= csr_wmask[`CSR_TLBIDX_NE]&csr_wvalue[`CSR_TLBIDX_NE]
                         | ~csr_wmask[`CSR_TLBIDX_NE]&csr_tlbidx_ne;
        csr_tlbidx_ps    <= csr_wmask[`CSR_TLBIDX_PS]&csr_wvalue[`CSR_TLBIDX_PS]
                         | ~csr_wmask[`CSR_TLBIDX_PS]&csr_tlbidx_ps;
    end
    else if (inst_tlbrd) begin
        csr_tlbidx_index <= csr_tlbidx_index;
        csr_tlbidx_ne    <= tlbidx_wdata[`CSR_TLBIDX_NE];
        csr_tlbidx_ps    <= tlbidx_wdata[`CSR_TLBIDX_PS];
    end
 end
assign csr_tlbidx_data = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 8'b0, csr_tlbidx_index};


// TLBEHI
assign csr_tlbehi_data = {csr_tlbehi_vppn, 13'b0};

wire page_err;
assign page_err = wb_ecode == `ECODE_PIL
               || wb_ecode == `ECODE_PIS
               || wb_ecode == `ECODE_PIF
               || wb_ecode == `ECODE_PME
               || wb_ecode == `ECODE_PPI
               || wb_ecode == `ECODE_TLBR;

always @(posedge clk) begin
    if (reset) begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBEHI) begin
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN]&csr_wvalue[`CSR_TLBEHI_VPPN]
                        | ~csr_wmask[`CSR_TLBEHI_VPPN]&csr_tlbehi_vppn;
    end
    else if (inst_tlbrd) begin
        csr_tlbehi_vppn <= tlbehi_wdata[`CSR_TLBEHI_VPPN];
    end
    else if (page_err) begin
        csr_tlbehi_vppn <= wb_vaddr[`CSR_TLBEHI_VPPN];
    end
 end

// TLBELO0
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_ppn <= 20'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_v   <= 1'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBELO0) begin
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN]&csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN]&csr_tlbelo0_ppn;
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV]&csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV]&csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT]&csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT]&csr_tlbelo0_mat;
        csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]  &csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G]  &csr_tlbelo0_g;
        csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]  &csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D]  &csr_tlbelo0_d;
        csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]  &csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V]  &csr_tlbelo0_v; 
    end
    else if (inst_tlbrd) begin
        csr_tlbelo0_ppn <= tlbelo0_wdata[`CSR_TLBELO_PPN];
        csr_tlbelo0_plv <= tlbelo0_wdata[`CSR_TLBELO_PLV];
        csr_tlbelo0_mat <= tlbelo0_wdata[`CSR_TLBELO_MAT];
        csr_tlbelo0_g   <= tlbelo0_wdata[`CSR_TLBELO_G];
        csr_tlbelo0_d   <= tlbelo0_wdata[`CSR_TLBELO_D];
        csr_tlbelo0_v   <= tlbelo0_wdata[`CSR_TLBELO_V];
    end
 end 
assign csr_tlbelo0_data = {4'b0, csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};


// TLBELO1
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_ppn <= 20'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_v   <= 1'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBELO1) begin
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN]&csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN]&csr_tlbelo1_ppn;
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV]&csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV]&csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT]&csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT]&csr_tlbelo1_mat;
        csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]  &csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G]  &csr_tlbelo1_g;
        csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]  &csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D]  &csr_tlbelo1_d;
        csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]  &csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V]  &csr_tlbelo1_v;
    end
    else if (inst_tlbrd) begin
        csr_tlbelo1_ppn <= tlbelo1_wdata[`CSR_TLBELO_PPN];
        csr_tlbelo1_plv <= tlbelo1_wdata[`CSR_TLBELO_PLV];
        csr_tlbelo1_mat <= tlbelo1_wdata[`CSR_TLBELO_MAT];
        csr_tlbelo1_g   <= tlbelo1_wdata[`CSR_TLBELO_G];
        csr_tlbelo1_d   <= tlbelo1_wdata[`CSR_TLBELO_D];
        csr_tlbelo1_v   <= tlbelo1_wdata[`CSR_TLBELO_V];
    end
 end
assign csr_tlbelo1_data = {4'b0, csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};


// ASID
always @(posedge clk) begin
    if (reset) begin
        csr_asid_asid <= 10'b0;
        csr_asid_asidbits <= 8'h0a;
    end
    else if (csr_we && csr_num==`CSR_ASID) begin
        csr_asid_asid <= csr_wmask[`CSR_ASID_ASID]&csr_wvalue[`CSR_ASID_ASID]
                      | ~csr_wmask[`CSR_ASID_ASID]&csr_asid_asid;
    end
    else if (inst_tlbrd) begin
        csr_asid_asid <= tlbasid_wdata[`CSR_ASID_ASID];
    end
 end
assign csr_asid_data = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};

// TLBRENTRY
always @(posedge clk) begin
    if (reset) begin
        csr_tlbrentry_pa <= 26'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBRENTRY) begin
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA]&csr_wvalue[`CSR_TLBRENTRY_PA]
                         | ~csr_wmask[`CSR_TLBRENTRY_PA]&csr_tlbrentry_pa;
    end
 end
assign csr_tlbrentry_data = {csr_tlbrentry_pa, 6'b0};

// DMW0
always @(posedge clk) begin
    if (reset) begin
        csr_dmw0_plv0 <= 1'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_vseg <= 3'b0;
    end
    else if (csr_we && csr_num==`CSR_DMW0) begin
        csr_dmw0_plv0 <= csr_wmask[`CSR_DMW_PLV0]&csr_wvalue[`CSR_DMW_PLV0]
                      | ~csr_wmask[`CSR_DMW_PLV0]&csr_dmw0_plv0;
        csr_dmw0_plv3 <= csr_wmask[`CSR_DMW_PLV3]&csr_wvalue[`CSR_DMW_PLV3]
                      | ~csr_wmask[`CSR_DMW_PLV3]&csr_dmw0_plv3;
        csr_dmw0_mat  <= csr_wmask[`CSR_DMW_MAT]&csr_wvalue[`CSR_DMW_MAT]
                      | ~csr_wmask[`CSR_DMW_MAT]&csr_dmw0_mat;
        csr_dmw0_pseg <= csr_wmask[`CSR_DMW_PSEG]&csr_wvalue[`CSR_DMW_PSEG]
                      | ~csr_wmask[`CSR_DMW_PSEG]&csr_dmw0_pseg;
        csr_dmw0_vseg <= csr_wmask[`CSR_DMW_VSEG]&csr_wvalue[`CSR_DMW_VSEG]
                      | ~csr_wmask[`CSR_DMW_VSEG]&csr_dmw0_vseg;
    end
 end
assign csr_dmw0_data = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};


 // DMW1
always @(posedge clk) begin
    if (reset) begin
        csr_dmw1_plv0 <= 1'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_vseg <= 3'b0;
    end
    else if (csr_we && csr_num==`CSR_DMW1) begin
        csr_dmw1_plv0 <= csr_wmask[`CSR_DMW_PLV0]&csr_wvalue[`CSR_DMW_PLV0]
                      | ~csr_wmask[`CSR_DMW_PLV0]&csr_dmw1_plv0;
        csr_dmw1_plv3 <= csr_wmask[`CSR_DMW_PLV3]&csr_wvalue[`CSR_DMW_PLV3]
                      | ~csr_wmask[`CSR_DMW_PLV3]&csr_dmw1_plv3;
        csr_dmw1_mat  <= csr_wmask[`CSR_DMW_MAT]&csr_wvalue[`CSR_DMW_MAT]
                      | ~csr_wmask[`CSR_DMW_MAT]&csr_dmw1_mat;
        csr_dmw1_pseg <= csr_wmask[`CSR_DMW_PSEG]&csr_wvalue[`CSR_DMW_PSEG]
                      | ~csr_wmask[`CSR_DMW_PSEG]&csr_dmw1_pseg;
        csr_dmw1_vseg <= csr_wmask[`CSR_DMW_VSEG]&csr_wvalue[`CSR_DMW_VSEG]
                      | ~csr_wmask[`CSR_DMW_VSEG]&csr_dmw1_vseg;
    end
 end
assign csr_dmw1_data = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};


assign hw_int_in = 8'b0;
assign ipi_int_in= 1'b0;

assign has_int  = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

// CRMD
always @(posedge clk) begin
    if (reset)
        csr_crmd_plv <= 2'b0;
    else if (wb_ex)
        csr_crmd_plv <= 2'b0;
    else if (ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
 end

always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_ex)
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]
                | ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
 end

always @(posedge clk) begin
    if (reset) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if (csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA]&csr_wvalue[`CSR_CRMD_DA]
                | ~csr_wmask[`CSR_CRMD_DA]&csr_crmd_da;
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG]&csr_wvalue[`CSR_CRMD_PG]
                | ~csr_wmask[`CSR_CRMD_PG]&csr_crmd_pg;
    end    
    else if (wb_ex && wb_ecode == `ECODE_TLBR) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if (ertn_flush && csr_estat_ecode == `ECODE_TLBR) begin
        csr_crmd_da <= 1'b0;
        csr_crmd_pg <= 1'b1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        csr_crmd_datf <= 2'b00;
        csr_crmd_datm <= 2'b00;
    end
    else if (csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF]&csr_wvalue[`CSR_CRMD_DATF]
                    | ~csr_wmask[`CSR_CRMD_DATF]&csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM]&csr_wvalue[`CSR_CRMD_DATM]
                    | ~csr_wmask[`CSR_CRMD_DATM]&csr_crmd_datm;
    end
end

assign csr_crmd_data = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

// PRMD
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
 end
assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};

// ESTAT
always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <=  csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[10] <= 1'b0;
    if (csr_tcfg_en && timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
             && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= ipi_int_in;
 end

always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
 end
assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};

// ERA
always @(posedge clk) begin
    if (wb_ex)
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                    | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
end

// EENTRY
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                       | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
 end
assign csr_eentry_data= {csr_eentry_va, 6'b0};

// SAVE0～3
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
 end

// ECFG
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]
                    | ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
 end
assign csr_ecfg_data  = {19'b0, csr_ecfg_lie};

// BADV
assign wb_ex_addr_err = wb_ecode == `ECODE_ADE 
                     || wb_ecode == `ECODE_ALE 
                     || page_err;
always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err)
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
                           wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
 end

// TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= 32'b0;
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid  <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                     | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
 end

// TCFG
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                    | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                            | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
                            | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
 end
assign csr_tcfg_data = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

// TVAL
assign tcfg_next_value =  csr_wmask[31:0]&csr_wvalue[31:0]
                       | ~csr_wmask[31:0]&{csr_tcfg_initval,
                                           csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

// TICLR
assign csr_ticlr_clr = 1'b0;
assign csr_ticlr_data = {31'b0, csr_ticlr_clr};

assign csr_rvalue =     {32{csr_num == `CSR_CRMD  }} & csr_crmd_data
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_data
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_data
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_data
                      | {32{csr_num == `CSR_ERA   }} & csr_era_pc
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_data
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data
                      | {32{csr_num == `CSR_BADV  }} & csr_badv_vaddr
                      | {32{csr_num == `CSR_TID   }} & csr_tid_tid
                      | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_data
                      | {32{csr_num == `CSR_TVAL  }} & csr_tval
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_data
                      | {32{csr_num == `CSR_TLBIDX}} & csr_tlbidx_data
                      | {32{csr_num == `CSR_TLBEHI}} & csr_tlbehi_data
                      | {32{csr_num == `CSR_TLBELO0}} & csr_tlbelo0_data
                      | {32{csr_num == `CSR_TLBELO1}} & csr_tlbelo1_data
                      | {32{csr_num == `CSR_ASID  }}  & csr_asid_data
                      | {32{csr_num == `CSR_TLBRENTRY}} & csr_tlbrentry_data;

endmodule

