`include "macros.h"

module WB #(
        parameter TLBNUM = 16,
        parameter LEN = 16 - $clog2(TLBNUM)
)(
        input   wire            clk,
        input   wire            rst,
        // MEM -> WB
        input   wire            MEM_to_WB,
        input   wire [186:0]    MEM_to_WB_zip,
        input   wire [ 46:0]    MEM_except_zip,
        // WB -> MEM
        output  wire            WB_allowin,
        // WB -> top
        output  wire            rf_wen,
        output  wire [  4:0]    rf_waddr,
        output  wire [ 31:0]    rf_wdata_final,
        output  wire [ 72:0]    inst_retire,
        output  wire            csr_re,
        output  wire [13:0]     csr_num,
        output  wire            csr_we,
        output  wire [31:0]     csr_wmask,
        output  wire [31:0]     csr_wvalue,
        output  wire            wb_ex,
        output  wire            ertn_flush,
        output  wire            except_tlbr,
        output  wire [31:0]     wb_pc,
        output  wire [ 5:0]     wb_ecode,
        output  wire [ 8:0]     wb_esubcode,
        output  wire [31:0]     wb_vaddr,
        output  wire            tlb_flush,
        output  wire [31:0]     tlb_flush_target,
        /// tlb
        output  wire            we, //w(rite) e(nable)
        output  wire [$clog2(TLBNUM)-1:0]       w_index,
        output  wire            w_e,
        output  wire [ 18:0]    w_vppn,
        output  wire [ 5:0]     w_ps,
        output  wire [ 9:0]     w_asid,
        output  wire            w_g,
        output  wire [ 19:0]    w_ppn0,
        output  wire [ 1:0]     w_plv0,
        output  wire [ 1:0]     w_mat0,
        output  wire            w_d0,
        output  wire            w_v0,
        output  wire [ 19:0]    w_ppn1,
        output  wire [ 1:0]     w_plv1,
        output  wire [ 1:0]     w_mat1,
        output  wire            w_d1,
        output  wire            w_v1,
        output  wire [$clog2(TLBNUM)-1:0]       r_index,
        /// csr
        output  wire            tlbrd,
        output  wire [31:0]     tlbehi_wdata,
        output  wire [31:0]     tlbelo0_wdata,
        output  wire [31:0]     tlbelo1_wdata,
        output  wire [31:0]     tlbidx_wdata,
        output  wire [31:0]     tlbasid_wdata,
        // top -> WB
        /// csr
        input   wire [31:0]     csr_rvalue,
        input   wire [31:0]     csr_estat_data,
        input   wire [31:0]     csr_tlbidx_data,
        input   wire [31:0]     csr_tlbehi_data,
        input   wire [31:0]     csr_tlbelo0_data,
        input   wire [31:0]     csr_tlbelo1_data,
        input   wire [31:0]     csr_asid_data,
        /// tlb
        input   wire            r_e,
        input   wire [ 18:0]    r_vppn,
        input   wire [ 5:0]     r_ps,
        input   wire [ 9:0]     r_asid,
        input   wire            r_g,
        input   wire [ 19:0]    r_ppn0,
        input   wire [ 1:0]     r_plv0,
        input   wire [ 1:0]     r_mat0,
        input   wire            r_d0,
        input   wire            r_v0,
        input   wire [ 19:0]    r_ppn1,
        input   wire [ 1:0]     r_plv1,
        input   wire [ 1:0]     r_mat1,
        input   wire            r_d1,
        input   wire            r_v1
);

wire            valid;
assign valid = MEM_to_WB_valid & at_state;

wire            inst_tlbrd;
wire            inst_tlbwr;
wire            inst_tlbfill;
wire            inst_invtlb;

assign tlbrd = valid & inst_tlbrd;

reg  [186:0]    MEM_to_WB_reg;
always @(posedge clk) begin
        if (rst) begin
                MEM_to_WB_reg <= 187'b0;
        end
        else if (MEM_to_WB) begin
                MEM_to_WB_reg <= MEM_to_WB_zip;
        end
        else begin
                MEM_to_WB_reg <= MEM_to_WB_reg;
        end
end

reg  [ 46:0]    MEM_except_reg;
always @(posedge clk) begin
        if (rst) begin
                MEM_except_reg <= 47'b0;
        end
        else if (MEM_to_WB) begin
                MEM_except_reg <= MEM_except_zip;
        end
        else begin
                MEM_except_reg <= MEM_except_reg;
        end
end

wire            MEM_to_WB_valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            gr_we;
wire            except_tlbr_if;
wire            except_tlbr_mem;
wire            except_pif;
wire            except_pil;
wire            except_pis;
wire            except_pme;
wire            except_ppi_if;
wire            except_ppi_mem;
wire            except_adef;
wire            except_sys;
wire            except_ale;
wire            except_brk;
wire            except_ine;
wire            except_int;
wire [31:0]     rf_wdata;
wire            inst_ertn;
reg             at_state;
always @(posedge clk) begin
        if (rst) begin
                at_state <= 1'b0;
        end 
        else if (MEM_to_WB) begin
                at_state <= 1'b1;
        end
        else begin
                at_state <= 1'b0; 
        end
end

assign WB_allowin       = 1'b1;
assign tlb_flush        = valid & (inst_tlbwr | inst_tlbfill | inst_invtlb);
assign tlb_flush_target = pc + 32'h4;

assign {
    MEM_to_WB_valid, pc, IR, gr_we, rf_waddr, rf_wdata, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb,
    csr_re, csr_we, csr_wmask, csr_wvalue, csr_num
} = MEM_to_WB_reg;

assign {
        inst_ertn, 
        except_adef, except_tlbr_if, except_pif, except_ppi_if,
        except_sys, except_brk, except_ine, except_int, 
        except_ale, except_tlbr_mem, except_pil, except_pis, except_pme, except_ppi_mem,
        wb_vaddr
} = MEM_except_reg;

assign rf_wen           = valid & gr_we & ~wb_ex;
assign rf_wdata_final   = csr_re ? csr_rvalue : rf_wdata;
assign inst_retire      = {pc, {4{rf_wen}}, rf_waddr, rf_wdata_final};

assign wb_ex            = valid & (
                                except_adef | except_tlbr_if  | except_pif | except_pme | except_ppi_if |
                                except_sys  | except_brk      | except_ine | except_int | 
                                except_ale  | except_tlbr_mem | except_pil | except_pis | except_ppi_mem    
                        );
assign ertn_flush       = valid & inst_ertn;
assign except_tlbr      = except_tlbr_if | except_tlbr_mem;
assign wb_pc            = pc;

assign wb_ecode         = except_int?     `ECODE_INT:
                          except_adef?    `ECODE_ADE:
                          except_tlbr_if? `ECODE_TLBR:
                          except_pif?     `ECODE_PIF:
                          except_pme?     `ECODE_PME:
                          except_ppi_if?  `ECODE_PPI:
                          except_sys?     `ECODE_SYS:
                          except_ine?     `ECODE_INE:
                          except_brk?     `ECODE_BRK:
                          except_ale?     `ECODE_ALE:
                          except_tlbr_mem?`ECODE_TLBR: 
                          except_pil?     `ECODE_PIL:
                          except_pis?     `ECODE_PIS:
                          except_ppi_mem? `ECODE_PPI:
                          6'b0;
assign wb_esubcode      = //inst_syscall ? `ESUBCODE_NONE : 
                                9'd0;

reg  [$clog2(TLBNUM)-1:0]       tlb_fill_idx;
always @(posedge clk) begin
        if (rst) begin
                tlb_fill_idx <= 0;
        end
        else begin
                tlb_fill_idx <= tlb_fill_idx + 1;
        end
end

assign we = valid & (inst_tlbwr | inst_tlbfill);
assign w_index = inst_tlbfill ? tlb_fill_idx : csr_tlbidx_data[$clog2(TLBNUM)-1:0];
assign w_e = csr_estat_data[`CSR_ESTAT_ECODE] == `ECODE_TLBR ? 1'b1 : ~csr_tlbidx_data[`CSR_TLBIDX_NE];
assign w_vppn = csr_tlbehi_data[`CSR_TLBEHI_VPPN];
assign w_ps = csr_tlbidx_data[`CSR_TLBIDX_PS];
assign w_asid = csr_asid_data[`CSR_ASID_ASID];
assign w_g = csr_tlbelo0_data[`CSR_TLBELO_G] & csr_tlbelo1_data[`CSR_TLBELO_G];
assign w_ppn0 = csr_tlbelo0_data[`CSR_TLBELO_PPN];
assign w_plv0 = csr_tlbelo0_data[`CSR_TLBELO_PLV];
assign w_mat0 = csr_tlbelo0_data[`CSR_TLBELO_MAT];
assign w_d0 = csr_tlbelo0_data[`CSR_TLBELO_D];
assign w_v0 = csr_tlbelo0_data[`CSR_TLBELO_V];
assign w_ppn1 = csr_tlbelo1_data[`CSR_TLBELO_PPN];
assign w_plv1 = csr_tlbelo1_data[`CSR_TLBELO_PLV];
assign w_mat1 = csr_tlbelo1_data[`CSR_TLBELO_MAT];
assign w_d1 = csr_tlbelo1_data[`CSR_TLBELO_D];
assign w_v1 = csr_tlbelo1_data[`CSR_TLBELO_V];

assign r_index = csr_tlbidx_data[$clog2(TLBNUM)-1:0];
assign tlbehi_wdata = r_e ? {r_vppn, 13'b0} : 32'b0;
assign tlbelo0_wdata = r_e ? {4'b0, r_ppn0, 1'b0, r_g, r_mat0, r_plv0, r_d0, r_v0} : 32'b0;
assign tlbelo1_wdata = r_e ? {4'b0, r_ppn1, 1'b0, r_g, r_mat1, r_plv1, r_d1, r_v1} : 32'b0;
assign tlbidx_wdata = r_e ? {1'b0, 1'b0, r_ps, 8'b0, {LEN{1'b0}}, r_index} : {1'b1, 31'b0};
assign tlbasid_wdata = r_e ? {22'b0, r_asid} : 32'b0;

endmodule
