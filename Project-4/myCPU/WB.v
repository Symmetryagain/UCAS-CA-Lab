module WB(
        input   wire            clk,
        input   wire            rst,
        input   wire [102:0]    MEM_to_WB_zip,
        input   wire [ 81:0]    MEM_except_reg,
        
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
        output  wire            ertn_flush
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            gr_we;

assign WB_allowin = 1'b1;

assign {
    valid, pc, IR, gr_we, rf_waddr, rf_wdata
} = MEM_to_WB_zip;

assign {csr_re, csr_we, csr_wmask, csr_wvalue, csr_num, ertn_flush, inst_syscall} = MEM_except_reg;

assign rf_wen   = gr_we & valid;
assign rf_wdata_final = csr_re ? csr_rvalue : rf_wdata;
always @(posedge clk) begin
        inst_retire_reg <= {pc, {4{rf_wen}}, rf_waddr, rf_wdata_final};
end

endmodule
