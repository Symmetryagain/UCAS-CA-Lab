`include "macros.h"

module WB(
        input   wire            clk,
        input   wire            rst,
        // MEM -> WB
        input   wire            MEM_to_WB,
        input   wire [106:0]    MEM_to_WB_zip,
        input   wire [126:0]    MEM_except_zip,
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
        output  wire [31:0]     wb_pc,
        output  wire [ 5:0]     wb_ecode,
        output  wire [ 8:0]     wb_esubcode,
        output  wire [31:0]     wb_vaddr,
        output  wire            tlb_flush,
        output  wire [31:0]     tlb_flush_target,
        // top -> WB
        input   wire [31:0]     csr_rvalue,

        output  wire            inst_tlbrd,
        output  wire [31:0]     tlbehi_wdata,
        output  wire [31:0]     tlbelo0_wdata,
        output  wire [31:0]     tlbelo1_wdata,
        output  wire [31:0]     tlbidx_wdata
);

wire            valid;
assign valid = MEM_to_WB_valid & at_state;

wire            inst_tlbwr;
wire            inst_tlbfill;
wire            inst_invtlb;

reg  [106:0]    MEM_to_WB_reg;
always @(posedge clk) begin
        if (rst) begin
                MEM_to_WB_reg <= 107'b0;
        end
        else if (MEM_to_WB) begin
                MEM_to_WB_reg <= MEM_to_WB_zip;
        end
        else begin
                MEM_to_WB_reg <= MEM_to_WB_reg;
        end
end

reg  [126:0]    MEM_except_reg;
always @(posedge clk) begin
        if (rst) begin
                MEM_except_reg <= 127'b0;
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
assign tlb_flush        = inst_tlbwr | inst_tlbfill | inst_invtlb;

assign {
    MEM_to_WB_valid, pc, IR, gr_we, rf_waddr, rf_wdata, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb
} = MEM_to_WB_reg;

assign {
        csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, 
        inst_ertn, 
        except_adef, except_tlbr_if, except_pif, except_pme, except_ppi_if,
        except_sys, except_brk, except_ine, except_int, 
        except_ale, except_tlbr_mem, except_pil, except_pis, except_ppi_mem,
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
assign wb_pc            = pc;

assign wb_ecode         = except_int?  `ECODE_INT:
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

// assign tlbehi_wdata = {};
endmodule
