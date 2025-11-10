`include "macro.h"

module WB(
        input   wire            clk,
        input   wire            rst,
        input   wire [102:0]    MEM_to_WB_zip,
        input   wire [ 86:0]    MEM_except_zip,
        
        output  wire            WB_allowin,
        output  wire            rf_wen,
        output  wire [  4:0]    rf_waddr,
        output  wire [ 31:0]    rf_wdata_final,
        output  reg  [ 72:0]    inst_retire_reg,


        output  wire            csr_re,
        output  wire [13:0]     csr_num,
        input   wire [31:0]     csr_rvalue,
        output  wire            csr_we,
        output  wire [31:0]     csr_wmask,
        output  wire [31:0]     csr_wvalue,
        output  wire            wb_ex,
        output  wire            ertn_flush,
        output  wire [31:0]     wb_pc,
        output  wire [ 5:0]     wb_ecode,
        output  wire [ 8:0]     wb_esubcode
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            gr_we;
wire            except_sys;
wire            except_ale;
wire            except_brk;
wire            except_ine;
wire            except_int;
wire            except_adef;
wire [ 5:0]     csr_ecode;
wire [ 8:0]     csr_esubcode;
wire [31:0]     rf_wdata;

assign WB_allowin = 1'b1;

assign {
    valid, pc, IR, gr_we, rf_waddr, rf_wdata
} = MEM_to_WB_zip;

assign {csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, ertn_flush, except_sys, except_adef, except_brk, except_ine, except_int, except_ale} = MEM_except_zip;

assign rf_wen   = gr_we & valid & ~wb_ex;
assign rf_wdata_final = csr_re ? csr_rvalue : rf_wdata;
always @(posedge clk) begin
        inst_retire_reg <= {pc, {4{rf_wen}}, rf_waddr, rf_wdata_final};
end

assign wb_ex = except_sys | except_adef | except_brk | except_ine | except_int | except_ale;
assign wb_pc = pc;

assign csr_ecode    =  except_sys?  `ECODE_SYS:
                       except_adef? `ECODE_ADE:
                       except_ale?  `ECODE_ALE: 
                       except_brk?  `ECODE_BRK:
                       except_ine?  `ECODE_INE:
                       except_int?  `ECODE_INT:
                       6'b0;
assign csr_esubcode = //inst_syscall ? `ESUBCODE_NONE : 
                        9'd0;

endmodule
