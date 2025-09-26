module WB(
        input   wire            clk,
        input   wire            rst,
        input   wire [103:0]    MEM_to_WB_bus,
        input   wire [ 31:0]    read_data,
        output  wire            rf_wen,
        output  wire [  4:0]    rf_waddr,
        output  wire [ 31:0]    rf_wdata,
        output  reg  [ 72:0]    inst_retire_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            gr_we;
wire            res_from_mem;
wire [31:0]     alu_result;

assign rf_wdata = res_from_mem ? read_data : alu_result;

assign {
    valid, pc, IR, res_from_mem, gr_we, rf_waddr, alu_result
} = MEM_to_WB_bus;

assign rf_wen   = gr_we & valid;

always @(posedge clk) begin
        inst_retire_reg <= {pc, {4{rf_wen}}, rf_waddr, rf_wdata};
end

endmodule