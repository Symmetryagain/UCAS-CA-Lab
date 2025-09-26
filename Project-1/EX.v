module EX(
        input   wire            clk,
        input   wire            rst,
        input   wire [181:0]    ID_to_EX_bus,
        output  reg  [137:0]    EX_to_MEM_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire [31:0]     src1;
wire [31:0]     src2;
wire [11:0]     aluop;
wire [40:0]     EX_to_MEM_bus;
/*
wire            inst_ld_w;
wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [ 4:0]     rf_waddr;
*/

assign  {
        valid, pc, IR, src1, src2, aluop, EX_to_MEM_bus
} = ID_to_EX_bus;

wire [31:0]     alu_result;

alu u_alu(
    .alu_op     (aluop),
    .alu_src1   (src1),
    .alu_src2   (src2),
    .alu_result (alu_result)
);

always @(posedge clk) begin
        EX_to_MEM_reg <= {valid & ~rst, pc, IR, EX_to_MEM_bus, alu_result};
end

endmodule
