module MEM(
        input   wire            clk,
        input   wire            rst,
        input   wire [137:0]    EX_to_MEM_bus,

        output  wire            write_en,
        output  wire [  3:0]    write_we,
        output  wire [ 31:0]    write_addr,
        output  wire [ 31:0]    write_data,
        output  reg  [103:0]    MEM_to_WB_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            inst_ld_w;
wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [ 4:0]     rf_waddr;
wire [31:0]     alu_result;
wire [31:0]     final_result;

assign  {
        valid, pc, IR, inst_ld_w, mem_we, res_from_mem, gr_we, rkd_value, rf_waddr, alu_result
} = EX_to_MEM_bus;

assign write_en = (mem_we | inst_ld_w) & valid;
assign write_we = {4{mem_we & valid}};
assign write_addr = alu_result;
assign write_data = rkd_value;

always @(posedge clk) begin
        MEM_to_WB_reg <= {valid & ~rst, pc, IR, res_from_mem, gr_we, rf_waddr, alu_result};
end

endmodule
