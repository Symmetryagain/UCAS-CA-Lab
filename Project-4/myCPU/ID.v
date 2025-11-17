//`define ECODE_INT       6'h00
//`define ECODE_ADE       6'h08   
//`define ECODE_ALE       6'h09   
//`define ECODE_SYS       6'h0B
//`define ECODE_BRK       6'h0C   
//`define ECODE_INE       6'h0D
//`define ECODE_TLBR      6'h3F
//`define ESUBCODE_NONE   9'd0
`include "macro.h"

module ID(
        input   wire            clk,
        input   wire            rst,
        input   wire            EX_allowin,
        input   wire [ 66:0]    IF_to_ID_zip,
        input   wire            flush,

        input   wire            last_MEM_done,
        input   wire [ 31:0]    done_pc,
        input   wire [ 31:0]    last_load_data,

        input   wire            front_from_EX_valid,
        input   wire [  4:0]    front_from_EX_addr,
        input   wire [ 31:0]    front_from_EX_data,
        input   wire            front_from_MEM_valid,
        input   wire [  4:0]    front_from_MEM_addr,
        input   wire [ 31:0]    front_from_MEM_data,
        // input   wire            load_from_MEM_valid,
        // input   wire [  4:0]    load_from_MEM_addr,
        // input   wire [ 31:0]    load_from_MEM_data,

        input   wire [ 31:0]    rf_rdata1,
        input   wire [ 31:0]    rf_rdata2,

        output  wire            ID_allowin,
        output  wire [  4:0]    rf_raddr1,
        output  wire [  4:0]    rf_raddr2,
        input   wire            has_int,
        output  wire            ID_flush,
        output  wire [ 31:0]    ID_flush_target,
        output  reg  [197:0]    ID_to_EX_reg,
        output  reg  [ 85:0]    ID_except_reg
);

reg [4:0] timer_cnt;
reg       last_is_csr;
wire      is_csr;
assign is_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_syscall | inst_ertn | inst_rdcntid;
always @(posedge clk) begin
    if (rst) begin
        last_is_csr <= 0;
    end
    else if (EX_allowin & readygo)  begin
        last_is_csr <= is_csr;
    end
    else begin
        last_is_csr <= last_is_csr;
    end
end
always @(posedge clk) begin
    if (rst) begin
        timer_cnt <= 5'b11111;
    end
    else if (EX_allowin & readygo & is_csr) begin
        timer_cnt <= 5'b11111;
    end
    else if (last_is_csr)  begin
        timer_cnt <= {1'b0, timer_cnt[4:1]};
    end
    else begin
        timer_cnt <= 5'b11111;
    end
end
reg  [31:0]     last_pc;
always @(posedge clk) begin
        if (rst) begin
                last_pc <= 32'b0;
        end
        else if (EX_allowin & readygo) begin
                last_pc <= pc;
        end
        else begin
                last_pc <= last_pc;
        end
end

reg             last_is_load;
reg  [ 4:0]     last_dest;

// reg             valid_self;
// always @(posedge clk) begin
//         if (rst) begin
//                 valid_self <= 1'b0;
//         end
//         else if(flush)begin
//                 valid_self <= 1'b0;
//         end
//         else if (ID_allowin) begin
//                 valid_self <= ~ID_flush & IF_to_ID_valid;
//         end
//         else begin
//                 valid_self <= valid_self;
//         end
// end
wire            valid;
assign valid = IF_to_ID_valid & ~flush;

assign ID_allowin = ~valid | readygo & EX_allowin;

wire            readygo;
wire            need_pause;
assign need_pause = (last_dest == rf_raddr1 || last_dest == rf_raddr2) & last_is_load & (last_dest != 0);
assign readygo = (~need_pause | need_pause & last_MEM_done & (done_pc == last_pc) ) &
                ~(last_is_csr & timer_cnt[0]);

wire            IF_to_ID_valid;
wire            predict;
wire [31:0]     pc;
wire [31:0]     inst;
wire            except_adef;
assign {
        IF_to_ID_valid, predict, inst, pc, except_adef
} = IF_to_ID_zip;

wire [11:0]     alu_op;
wire            load_op;
wire            src1_is_pc;
wire            src2_is_imm;
wire            res_from_mem;
wire            dst_is_r1;
wire            gr_we;
wire            mem_we;
wire            src_reg_is_rd;
wire [ 4:0]     dest;
wire [31:0]     rj_value;
wire [31:0]     rkd_value;
wire            rj_eq_rd;
wire            rj_lt_rd;
wire            rj_lt_rd_u;
wire [31:0]     imm;
wire [31:0]     br_offs;
wire [31:0]     jirl_offs;
wire            br_taken;
wire [31:0]     br_target;

wire [ 5:0]     op_31_26;
wire [ 3:0]     op_25_22;
wire [ 1:0]     op_21_20;
wire [ 4:0]     op_19_15;
wire [ 4:0]     rd;
wire [ 4:0]     rj;
wire [ 4:0]     rk;
wire [11:0]     i12;
wire [19:0]     i20;
wire [15:0]     i16;
wire [25:0]     i26;

wire [63:0]     op_31_26_d;
wire [15:0]     op_25_22_d;
wire [ 3:0]     op_21_20_d;
wire [31:0]     op_19_15_d;

wire            inst_add_w;
wire            inst_sub_w;
wire            inst_slt;
wire            inst_sltu;
wire            inst_nor;
wire            inst_and;
wire            inst_or;
wire            inst_xor;
wire            inst_slli_w;
wire            inst_srli_w;
wire            inst_srai_w;
wire            inst_addi_w;
wire            inst_ld_w;
wire            inst_st_w;
wire            inst_jirl;
wire            inst_b;
wire            inst_bl;
wire            inst_beq;
wire            inst_bne;
wire            inst_lu12i_w;
wire            inst_slti;
wire            inst_sltui;
wire            inst_andi;
wire            inst_ori;
wire            inst_xori;
wire            inst_sll;
wire            inst_srl;
wire            inst_sra;
wire            inst_pcaddu12i;

wire            inst_mul;
wire            inst_mulh;
wire            inst_mulhu;
wire            inst_div;
wire            inst_mod;
wire            inst_divu;
wire            inst_modu;

wire            inst_blt;
wire            inst_bge;
wire            inst_bltu;
wire            inst_bgeu;

wire            inst_ld_b;
wire            inst_ld_h;
wire            inst_ld_bu;
wire            inst_ld_hu;
wire            inst_st_b;
wire            inst_st_h;

wire            inst_csrrd;
wire            inst_csrwr;
wire            inst_csrxchg;
wire            inst_ertn;
wire            inst_syscall;
wire            inst_break;
wire            inst_rdcntid;
wire            inst_rdcntvl;
wire            inst_rdcntvh;

wire            need_ui5;
wire            need_ui12;
wire            need_si12;
wire            need_si16;
wire            need_si20;
wire            need_si26;
wire            src2_is_4;

wire            csr_re;
wire [13:0]     csr_num;
wire            csr_we;
wire [31:0]     csr_wmask;
wire [31:0]     csr_wvalue;
wire  [5:0]     csr_ecode;
wire  [8:0]     csr_esubcode;


assign op_31_26 = inst[31:26];
assign op_25_22 = inst[25:22];
assign op_21_20 = inst[21:20];
assign op_19_15 = inst[19:15];

assign rd       = inst[ 4: 0];
assign rj       = inst[ 9: 5];
assign rk       = inst[14:10];

assign i12      = inst[21:10];
assign i20      = inst[24: 5];
assign i16      = inst[25:10];
assign i26      = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign  inst_add_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign  inst_sub_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign  inst_slt        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign  inst_sltu       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign  inst_nor        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign  inst_and        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign  inst_or         = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign  inst_xor        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign  inst_slli_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign  inst_srli_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign  inst_srai_w     = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign  inst_addi_w     = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign  inst_jirl       = op_31_26_d[6'h13];
assign  inst_b          = op_31_26_d[6'h14];
assign  inst_bl         = op_31_26_d[6'h15];
assign  inst_beq        = op_31_26_d[6'h16];
assign  inst_bne        = op_31_26_d[6'h17];
assign  inst_lu12i_w    = op_31_26_d[6'h05] & ~inst[25];
assign  inst_slti       = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign  inst_sltui      = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign  inst_andi       = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign  inst_ori        = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign  inst_xori       = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign  inst_sll        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign  inst_srl        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign  inst_sra        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign  inst_pcaddu12i  = op_31_26_d[6'h07] & ~inst[25];
assign  inst_mul        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign  inst_mulh       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign  inst_mulhu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign  inst_div        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign  inst_mod        = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign  inst_divu       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign  inst_modu       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign  inst_blt        = op_31_26_d[6'h18];
assign  inst_bge        = op_31_26_d[6'h19];
assign  inst_bltu       = op_31_26_d[6'h1a];
assign  inst_bgeu       = op_31_26_d[6'h1b];
assign  inst_ld_b       = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign  inst_ld_h       = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign  inst_ld_w       = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign  inst_st_b       = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign  inst_st_h       = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign  inst_st_w       = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign  inst_ld_bu      = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign  inst_ld_hu      = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign  inst_csrrd      = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h00);
assign  inst_csrwr      = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h01);
assign  inst_csrxchg    = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj != 5'h00) & (rj != 5'h01);
assign  inst_ertn       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);
assign  inst_syscall    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign  inst_break      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign  inst_rdcntid    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);
assign  inst_rdcntvl    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
assign  inst_rdcntvh    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);

assign  alu_op[ 0]      = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                         | inst_ld_b | inst_ld_bu |inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h
                         | inst_jirl | inst_bl | inst_pcaddu12i;
assign  alu_op[ 1]      = inst_sub_w;
assign  alu_op[ 2]      = inst_slt | inst_slti;
assign  alu_op[ 3]      = inst_sltu | inst_sltui;
assign  alu_op[ 4]      = inst_and | inst_andi;
assign  alu_op[ 5]      = inst_nor;
assign  alu_op[ 6]      = inst_or | inst_ori;
assign  alu_op[ 7]      = inst_xor | inst_xori;
assign  alu_op[ 8]      = inst_slli_w | inst_sll;
assign  alu_op[ 9]      = inst_srli_w | inst_srl;
assign  alu_op[10]      = inst_srai_w | inst_sra;
assign  alu_op[11]      = inst_lu12i_w;

assign  need_ui5        =  inst_slli_w | inst_srli_w | inst_srai_w;
assign  need_ui12       =  inst_andi | inst_ori | inst_xori;//
assign  need_si12       =  inst_addi_w | inst_ld_w | inst_st_w 
                         | inst_ld_b | inst_ld_bu |inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h
                         | inst_slti | inst_sltui;
assign  need_si16       =  inst_jirl | inst_beq | inst_bne;
assign  need_si20       =  inst_lu12i_w | inst_pcaddu12i;
assign  need_si26       =  inst_b | inst_bl;
assign  src2_is_4       =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4 :
             need_si20 ? {i20[19:0], 12'b0} :
             need_ui12 ? {{20'b0}, i12} :
             /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;


assign  br_offs         = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign  jirl_offs       = {{14{i16[15]}}, i16[15:0], 2'b0};

assign  src_reg_is_rd   = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h |
                          inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrwr | inst_csrxchg;

assign  src1_is_pc      = inst_jirl | inst_bl | inst_pcaddu12i;

assign  src2_is_imm     = inst_slli_w |
                          inst_srli_w |
                          inst_srai_w |
                          inst_addi_w |
                          inst_ld_w   |
                          inst_st_w   |
                          inst_ld_b   |
                          inst_ld_bu  |
                          inst_ld_h   |
                          inst_ld_hu  |
                          inst_st_b   |
                          inst_st_h   |
                          inst_lu12i_w|
                          inst_jirl   |
                          inst_bl     |
                          inst_slti   |
                          inst_sltui  |
                          inst_andi   |
                          inst_ori    |
                          inst_xori   |
                          inst_pcaddu12i ;

assign  res_from_mem    = inst_ld_w | inst_ld_b | inst_ld_bu |inst_ld_h | inst_ld_hu;
assign  dst_is_r1       = inst_bl;
assign  gr_we           = ~inst_st_w & ~inst_st_b & ~inst_st_h &
                          ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu;
assign  mem_we          = inst_st_w | inst_st_b | inst_st_h;
assign  dest            = dst_is_r1 ? 5'd1 : inst_rdcntid ? rj : rd;

assign  rf_raddr1       = rj;
assign  rf_raddr2       = src_reg_is_rd ? rd : rk;

assign  rj_value        = need_pause & (last_dest == rf_raddr1) ? last_load_data : 
                          front_from_EX_valid & (front_from_EX_addr == rf_raddr1) ? front_from_EX_data :
                          front_from_MEM_valid & (front_from_MEM_addr == rf_raddr1) ? front_from_MEM_data :
                          rf_rdata1;
assign  rkd_value       = need_pause & (last_dest == rf_raddr2) ? last_load_data : 
                          front_from_EX_valid & (front_from_EX_addr == rf_raddr2) ? front_from_EX_data :
                          front_from_MEM_valid & (front_from_MEM_addr == rf_raddr2) ? front_from_MEM_data :  
                          rf_rdata2;

assign  rj_eq_rd        = (rj_value == rkd_value);
assign  rj_lt_rd        = (rj_value[31] != rkd_value[31]) ? rj_value[31] : (rj_value < rkd_value);
assign  rj_lt_rd_u      = rj_value < rkd_value;
assign  br_taken        = (   inst_beq  &&  rj_eq_rd
                           || inst_bne  && !rj_eq_rd
                           || inst_blt  &&  rj_lt_rd
                           || inst_bge  && !rj_lt_rd
                           || inst_bltu &&  rj_lt_rd_u
                           || inst_bgeu && !rj_lt_rd_u
                           || inst_jirl
                           || inst_bl
                           || inst_b
                          ) && valid;
assign  br_target       = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign  ID_flush           = ((br_taken ^ predict) | inst_jirl) & ~rst & valid;

assign csr_re       = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
assign csr_we       = inst_csrwr | inst_csrxchg;
assign csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{inst_csrwr}};
assign csr_wvalue   = rkd_value;
assign csr_num      = inst_rdcntid ? `CSR_TID : inst[23:10];
wire   except_sys;
wire   except_brk;
wire   except_ine;
wire   except_int;

/*assign csr_ecode    =  except_sys?  `ECODE_SYS:
                       except_adef? `ECODE_ADE:
                       except_ale?  `ECODE_ALE: 
                       except_brk?  `ECODE_BRK:
                       except_ine?  `ECODE_INE:
                       except_int?  `ECODE_INT:
                       6'b0;
assign csr_esubcode = inst_syscall ? `ESUBCODE_NONE : 9'd0;*/

assign except_sys  = inst_syscall;
assign except_brk  = inst_break;
assign except_ine  = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor |
                inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl |
                inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w | inst_slti | inst_sltui | inst_andi |
                inst_ori | inst_xori | inst_sll | inst_srl | inst_sra | inst_pcaddu12i | inst_mul | inst_mulh |
                inst_mulhu | inst_div | inst_mod | inst_divu | inst_modu | inst_blt | inst_bge | inst_bltu |
                inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h |
                inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_syscall | inst_break | inst_rdcntid | inst_rdcntvl | inst_rdcntvh) & valid;
assign except_int  = has_int;

always @(posedge clk) begin
        if (rst) begin
                ID_to_EX_reg <= 198'b0;
        end
        else if (EX_allowin & readygo) begin
                ID_to_EX_reg <= {
                        valid, 
                        pc, inst,
                        src1_is_pc ? pc : rj_value,
                        src2_is_imm ? imm : rkd_value,
                        alu_op, 
                        inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, 
                        inst_st_b, inst_st_h, inst_st_w, 
                        mem_we, res_from_mem, gr_we, rkd_value, dest,
                        inst_mul, inst_mulh, inst_mulhu, inst_div, inst_mod, inst_divu, inst_modu, 
                        inst_rdcntvh, inst_rdcntvl
                };
        end
        else if (EX_allowin & ~readygo) begin
                ID_to_EX_reg <= 198'b0;
        end
        else begin
                ID_to_EX_reg <= ID_to_EX_reg;
        end
end

always @(posedge clk) begin
        if (rst) begin
                ID_except_reg <= 86'b0;
        end
        else if (EX_allowin & readygo) begin
                ID_except_reg  <= {
                        csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, 
                        inst_ertn, except_sys, except_adef, except_brk, except_ine, except_int
                        //csr_ecode, csr_esubcode
                };
        end
        else if (EX_allowin & ~readygo) begin
                ID_except_reg <= 86'b0;
        end
        else begin
                ID_except_reg <= ID_except_reg;
        end
end

always @(posedge clk) begin
        if (rst) begin
                last_is_load <= 1'b0;
        end
        else if (EX_allowin & readygo) begin
                last_is_load <= res_from_mem & valid;
        end
        else begin
                last_is_load <= last_is_load;
        end
end

always @(posedge clk) begin
        if (rst) begin
                last_dest <= 5'b0;
        end
        else if (EX_allowin & readygo) begin
                last_dest <= dest;
        end
        else begin
                last_dest <= last_dest;
        end
end

assign ID_flush_target = br_target;

endmodule