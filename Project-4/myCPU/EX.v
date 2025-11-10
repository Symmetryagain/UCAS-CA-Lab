module EX(
        input   wire            clk,
        input   wire            rst,
        input   wire            MEM_allowin,
        input   wire [197:0]    ID_to_EX_zip,
        input   wire [ 85:0]    ID_except_zip,

        input   wire            flush,

        output  wire            front_valid,
        output  wire [  4:0]    front_addr,
        output  wire [ 31:0]    front_data,

        input   wire [ 63:0]    counter,

        output  wire            EX_allowin,
        output  reg  [144:0]    EX_to_MEM_reg,
        output  reg  [ 86:0]    EX_except_reg
);

wire            valid;
assign valid = valid_self & ~flush;

wire            valid_self;
wire [31:0]     pc;
wire [31:0]     IR;
wire [31:0]     src1;
wire [31:0]     src2;
wire [11:0]     aluop;
wire [47:0]     EX_to_MEM_zip;

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
wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [ 4:0]     rf_waddr;
wire            csr_re;
wire [13:0]     csr_num;
wire            csr_we;
wire [31:0]     csr_wmask;
wire [31:0]     csr_wvalue;
wire            inst_syscall;
wire            inst_ertn;
wire            except_ale;
wire            inst_rdcntvh;
wire            inst_rdcntvl;

assign except_ale = (|alu_result[1:0]) & (inst_st_w | inst_ld_w) |
     alu_result[0] & (inst_st_h | inst_ld_h | inst_ld_hu);

assign front_valid = ~res_from_mem & gr_we;
assign front_addr = rf_waddr;
assign front_data = alu_result;

assign EX_allowin = ~valid | readygo & MEM_allowin;

assign  {
        valid_self, pc, IR, src1, src2, aluop, EX_to_MEM_zip, 
        inst_mul, inst_mulh, inst_mulhu, inst_div, inst_mod, inst_divu, inst_modu, 
        inst_rdcntvh, inst_rdcntvl
} = ID_to_EX_zip;

assign {
        inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, 
        inst_st_b, inst_st_h, inst_st_w,
        mem_we, res_from_mem, gr_we, rkd_value, rf_waddr
} = EX_to_MEM_zip;


wire [31:0]     alu_result;
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
assign use_div = inst_div | inst_mod;
assign use_udiv = inst_divu | inst_modu;
assign div_or_udiv = use_div | use_udiv;

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
        if (rst) begin
                init <= 1'b1;
        end
        else if (readygo & MEM_allowin) begin
                init <= 1'b1;
        end
        else begin
                init <= 1'b0;
        end
end

always @(posedge clk) begin
        if (rst) begin
                wait_src_ready <= 1'b0;
        end
        else if (init & div_or_udiv) begin
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
        if (rst) begin
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
        if (rst) begin
                readygo <= 1'b0;
        end
        else if (init & ~div_or_udiv | wait_res_valid & res_valid) begin
                readygo <= 1'b1;
        end
        else if (readygo & MEM_allowin) begin
                readygo <= 1'b0;
        end
        else begin
                readygo <= readygo;
        end
end

always @(posedge clk) begin
        if (rst) begin
                EX_to_MEM_reg <= 145'b0;
        end
        else if (readygo & MEM_allowin) begin
                EX_to_MEM_reg <= {valid & ~rst, pc, IR, EX_to_MEM_zip, compute_result};
        end
        else if (~readygo & MEM_allowin) begin
                EX_to_MEM_reg <= 145'b0;
        end
        else begin
                EX_to_MEM_reg <= EX_to_MEM_reg;
        end
end

always @(posedge clk) begin
        if (rst) begin
                EX_except_reg <= 87'b0;
        end
        else if (readygo & MEM_allowin) begin
                EX_except_reg <= {ID_except_zip, except_ale};
        end
        else if (~readygo & MEM_allowin) begin
                EX_except_reg <= 87'b0;
        end
        else begin
                EX_except_reg <= EX_except_reg;
        end
end

endmodule
