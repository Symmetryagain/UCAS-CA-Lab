`include "macros.h"

module EX #(
        parameter TLBNUM = 16,
        parameter LEN = 16 - $clog2(TLBNUM)
) (
        input   wire            clk,
        input   wire            rst,
        // EX -> ID
        output  wire            front_valid,
        output  wire [  4:0]    front_addr,
        output  wire [ 31:0]    front_data,
        output  wire            EX_allowin,
        output  wire            EX_is_csr,
        output  wire            EX_is_load,
        // ID -> EX
        input   wire            ID_to_EX,
        input   wire [283:0]    ID_to_EX_zip,
        input   wire [  8:0]    ID_except_zip,
        // EX -> MEM
        output  wire            EX_to_MEM,
        output  wire [262:0]    EX_to_MEM_zip,
        output  wire [ 14:0]    EX_except_zip,
        // MEM -> EX
        input   wire            MEM_allowin,
        // EX -> top
        output  wire            mmu_en,
        output  wire            mem_we,
        /// mmu
        output  wire            invtlb_valid,
        output  wire [  4:0]    invtlb_op,
        output  wire [  9:0]    s1_asid,
        output  wire [ 31:0]    vaddr,
        // top -> EX
        /// mmu
        input   wire [ 31:0]    addr_trans,
        input   wire            except_tlbr,
        input   wire            except_pil,
        input   wire            except_pis,
        input   wire            except_pme,
        input   wire            except_ppi,
        input   wire            s1_found,
        input   wire [$clog2(TLBNUM)-1:0]       s1_index,
        /// flush
        input   wire            flush,
        /// csr
        input   wire [ 31:0]    csr_asid_data,
        input   wire [ 31:0]    csr_tlbehi_data,
        input   wire [ 31:0]    csr_tlbidx_data,
        /// counter
        input   wire [ 63:0]    counter
);

wire            valid;
assign valid = ID_to_EX_valid & at_state & ~flush;

assign EX_to_MEM = readygo & MEM_allowin;

reg  [283:0]    ID_to_EX_reg;
always @(posedge clk) begin
        if (rst) begin
                ID_to_EX_reg <= 284'b0;
        end
        else if (ID_to_EX) begin
                ID_to_EX_reg <= ID_to_EX_zip;
        end
        else begin
                ID_to_EX_reg <= ID_to_EX_reg;
        end
end

reg  [ 8:0]     ID_except_reg;
always @(posedge clk) begin
        if (rst) begin
                ID_except_reg <= 9'b0;
        end
        else if (ID_to_EX) begin
                ID_except_reg <= ID_except_zip;
        end
        else begin
                ID_except_reg <= ID_except_reg;
        end
end

reg             at_state;
always @(posedge clk) begin
        if (rst | flush) begin 
                at_state <= 1'b0;
        end
        else if (ID_to_EX) begin
                at_state <= 1'b1;
        end
        else if (EX_to_MEM) begin
                at_state <= 1'b0;
        end
        else begin
                at_state <= at_state;
        end
end

wire            ID_to_EX_valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire [31:0]     src1;
wire [31:0]     src2;
wire [11:0]     aluop;
wire [31:0]     alu_result;

wire            inst_ld_w;
wire            inst_ld_b;
wire            inst_ld_h;
wire            inst_ld_bu;
wire            inst_ld_hu;
wire            inst_st_b;
wire            inst_st_h;
wire            inst_st_w;

wire            inst_mul;
wire            inst_mulh;
wire            inst_mulhu;
wire            inst_div;
wire            inst_divu;
wire            inst_mod;
wire            inst_modu;

wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [ 4:0]     rf_waddr;
wire            inst_syscall;
wire            inst_ertn;
wire            except_ale;
wire            inst_rdcntvh;
wire            inst_rdcntvl;
wire            is_csr;

wire            inst_tlbsrch;
wire            inst_tlbrd;
wire            inst_tlbwr;
wire            inst_tlbfill;
wire            inst_invtlb;

wire            csr_re;
wire [13:0]     csr_num;
wire            csr_we;
wire [31:0]     csr_wmask;
wire [31:0]     csr_wvalue;

assign except_ale = (|alu_result[1:0]) & (inst_st_w | inst_ld_w) 
                  | alu_result[0] & (inst_st_h | inst_ld_h | inst_ld_hu);

assign front_valid = valid & ~res_from_mem & gr_we;
assign front_addr = rf_waddr;
assign front_data = compute_result;

assign EX_allowin = ~valid | readygo & MEM_allowin;

assign  {
        ID_to_EX_valid, pc, IR, src1, src2, aluop,
        inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, 
        inst_st_b, inst_st_h, inst_st_w,
        mem_we, res_from_mem, gr_we, rkd_value, rf_waddr,
        inst_mul, inst_mulh, inst_mulhu, inst_div, inst_mod, inst_divu, inst_modu, 
        inst_rdcntvh, inst_rdcntvl, is_csr,
        inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb,
        csr_re, csr_we, csr_wmask, csr_wvalue, csr_num
} = ID_to_EX_reg;

assign EX_is_csr = valid & is_csr;
assign EX_is_load = valid & res_from_mem;

wire [31:0]     compute_result;
wire [32:0]     mul_src1;
wire [32:0]     mul_src2;
wire [65:0]     prod;

assign          mul_src1        = {~inst_mulhu & src1[31], src1};
assign          mul_src2        = {~inst_mulhu & src2[31], src2};
assign          prod            = $signed(mul_src1) * $signed(mul_src2);
assign          compute_result  = inst_mul?                     prod[31:0]:
                                  (inst_mulh | inst_mulhu)?     prod[63:32]:
                                  inst_div?                     div_result[63:32]:
                                  inst_mod?                     div_result[31:0]:
                                  inst_divu?                    udiv_result[63:32]:
                                  inst_modu?                    udiv_result[31:0]:
                                  inst_rdcntvh?                 counter[63:32]:
                                  inst_rdcntvl?                 counter[31:0]:
                                  alu_result;

wire            use_div;
wire            use_udiv;
wire            div_or_udiv;
assign use_div     = inst_div  | inst_mod;
assign use_udiv    = inst_divu | inst_modu;
assign div_or_udiv = use_div   | use_udiv;

wire [63:0]     div_result;
wire            div_src_valid;
wire            div_src_1_ready;
wire            div_src_2_ready;
wire            div_src_ready;
wire            div_res_ready;
wire            div_res_valid;
assign div_src_ready = div_src_1_ready & div_src_2_ready;

wire [63:0]     udiv_result;
wire            udiv_src_valid;
wire            udiv_src_1_ready;
wire            udiv_src_2_ready;
wire            udiv_src_ready;       
wire            udiv_res_ready;
wire            udiv_res_valid;
assign udiv_src_ready = udiv_src_1_ready & udiv_src_2_ready;

wire            src_ready;
wire            res_valid;
assign src_ready = use_div & div_src_ready | use_udiv & udiv_src_ready;
assign res_valid = use_div & div_res_valid | use_udiv & udiv_res_valid;

assign div_src_valid = wait_src_ready;
assign udiv_src_valid = wait_src_ready;
assign div_res_ready = wait_res_valid;
assign udiv_res_ready = wait_res_valid;

assign mmu_en = valid & (res_from_mem | mem_we);

assign invtlb_valid = valid & inst_invtlb;
assign invtlb_op = rf_waddr;
assign s1_asid = inst_invtlb?   src1           [`CSR_ASID_ASID  ] : 
                                csr_asid_data  [`CSR_ASID_ASID  ] ;
assign vaddr   = inst_invtlb?  {rkd_value      [`CSR_TLBEHI_VPPN] , 13'b0} : 
                 inst_tlbsrch? {csr_tlbehi_data[`CSR_TLBEHI_VPPN] , 13'b0} :
                                alu_result                                 ;

reg             init;
reg             wait_src_ready;
reg             wait_res_valid;
reg             readygo;

alu u_alu(
    .alu_op     (aluop),
    .alu_src1   (src1),
    .alu_src2   (src2),
    .alu_result (alu_result)
);

signed_div signed_div (
    .aclk(clk),
    .s_axis_divisor_tvalid(div_src_valid),
    .s_axis_divisor_tready(div_src_1_ready),  
    .s_axis_divisor_tdata(src2), 
    .s_axis_dividend_tvalid(div_src_valid),
    .s_axis_dividend_tready(div_src_2_ready),  
    .s_axis_dividend_tdata(src1),  
    .m_axis_dout_tvalid(div_res_valid),
    .m_axis_dout_tdata(div_result)
);

unsigned_div unsigned_div (
    .aclk(clk),
    .s_axis_divisor_tvalid(udiv_src_valid),
    .s_axis_divisor_tready(udiv_src_1_ready),  
    .s_axis_divisor_tdata(src2), 
    .s_axis_dividend_tvalid(udiv_src_valid),
    .s_axis_dividend_tready(udiv_src_2_ready),  
    .s_axis_dividend_tdata(src1),  
    .m_axis_dout_tvalid(udiv_res_valid),
    .m_axis_dout_tdata(udiv_result)
);

always @(posedge clk) begin
        if (rst | flush) begin
                init <= 1'b1;
        end
        else if (readygo & MEM_allowin) begin
                init <= 1'b1;
        end
        else if (init & valid) begin
                init <= 1'b0;
        end
        else begin
                init <= init;
        end
end

always @(posedge clk) begin
        if (rst | flush) begin
                wait_src_ready <= 1'b0;
        end
        else if (init & valid & div_or_udiv) begin
                wait_src_ready <= 1'b1;
        end
        else if (wait_src_ready & src_ready) begin
                wait_src_ready <= 1'b0;
        end
        else begin
                wait_src_ready <= wait_src_ready;
        end
end

always @(posedge clk) begin
        if (rst | flush) begin
                wait_res_valid <= 1'b0;
        end
        else if (wait_src_ready & src_ready) begin
                wait_res_valid <= 1'b1;
        end
        else if (wait_res_valid & res_valid) begin
                wait_res_valid <= 1'b0;
        end
        else begin
                wait_res_valid <= wait_res_valid;
        end
end

always @(posedge clk) begin
        if (rst | flush) begin
                readygo <= 1'b0;
        end
        else if (init & valid & ~div_or_udiv | wait_res_valid & res_valid) begin
                readygo <= 1'b1;
        end
        else if (readygo & MEM_allowin) begin
                readygo <= 1'b0;
        end
        else begin
                readygo <= readygo;
        end
end

assign EX_to_MEM_zip = {
        valid & ~rst, pc, IR, 
        inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, 
        inst_st_b, inst_st_h, inst_st_w,
        mem_we, res_from_mem, gr_we, rkd_value, rf_waddr,
        compute_result, is_csr, addr_trans,
        inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb,
        csr_re, csr_we, 
        csr_wmask | {16'b0, {16{inst_tlbsrch & s1_found}}}, 
        inst_tlbsrch ? {~s1_found, 15'b0, {LEN{1'b0}}, s1_index} : csr_wvalue,
        csr_num
};

assign EX_except_zip = {ID_except_reg, except_ale, except_tlbr, except_pil, except_pis, except_pme, except_ppi};

endmodule
