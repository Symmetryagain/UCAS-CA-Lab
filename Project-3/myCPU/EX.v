module EX(
        input   wire            clk,
        input   wire            rst,
        input   wire            MEM_allowin,
        input   wire [184:0]    ID_to_EX_zip,
        output  wire            front_valid,
        output  wire [  4:0]    front_addr,
        output  wire [ 31:0]    front_data,
        output  wire            EX_allowin,
        output  reg  [137:0]    EX_to_MEM_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire [31:0]     src1;
wire [31:0]     src2;
wire [11:0]     aluop;
wire [40:0]     EX_to_MEM_zip;

wire            inst_ld_w;
wire            inst_mul;
wire            inst_mulh;
wire            inst_mulhu;
wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [ 4:0]     rf_waddr;

reg             EX_readygo;

assign front_valid = ~inst_ld_w & gr_we;
assign front_addr = rf_waddr;
assign front_data = alu_result;

assign EX_allowin = ~valid | EX_readygo & MEM_allowin;

assign  {
        valid, pc, IR, src1, src2, aluop, EX_to_MEM_zip, inst_mul, inst_mulh, inst_mulhu
} = ID_to_EX_zip;

assign {
        inst_ld_w, mem_we, res_from_mem, gr_we, rkd_value, rf_waddr
} = EX_to_MEM_zip;

wire [31:0]     alu_result, compute_result;
wire [63:0]     product, u_product;

assign          product         = signed(src1)   * signed(src2);
assign          u_product       = unsigned(src1) * unsigned(src2);
assign          compute_result  = inst_mul?     product[31:0]:
                                  inst_mulh?    product[63:32]:
                                  inst_mulhu?   u_product[63:32]:
                                  alu_result;

alu u_alu(
    .alu_op     (aluop),
    .alu_src1   (src1),
    .alu_src2   (src2),
    .alu_result (alu_result)
);

always @(posedge clk) begin
    if (rst) begin
        EX_readygo <= 1'b0;
    end
    else if()begin
        EX_readygo <= 1'b1;
    end
    else
        EX_readygo <= 1'b0;
end

always @(posedge clk) begin
        if (rst) begin
                EX_to_MEM_reg <= 138'b0;
        end
        else if (EX_readygo & MEM_allowin) begin
                EX_to_MEM_reg <= {valid & ~rst, pc, IR, EX_to_MEM_zip, compute_result};
        end
        else begin
                EX_to_MEM_reg <= EX_to_MEM_reg;
        end
end

endmodule
