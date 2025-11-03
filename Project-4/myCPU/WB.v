module WB(
        input   wire            clk,
        input   wire            rst,
        input   wire [102:0]    MEM_to_WB_zip,
        
        output  wire            WB_allowin,
        output  wire            rf_wen,
        output  wire [  4:0]    rf_waddr,
        output  wire [ 31:0]    rf_wdata,
        output  reg  [ 72:0]    inst_retire_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            gr_we;

assign WB_allowin = 1'b1;

assign {
    valid, pc, IR, gr_we, rf_waddr, rf_wdata
} = MEM_to_WB_zip;

assign rf_wen   = gr_we & valid;

always @(posedge clk) begin
        inst_retire_reg <= {pc, {4{rf_wen}}, rf_waddr, rf_wdata};
end

endmodule