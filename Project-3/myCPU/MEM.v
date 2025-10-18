module MEM(
        input   wire            clk,
        input   wire            rst,
        input   wire            WB_allowin,
        
        input   wire            data_ready,
        input   wire            data_valid,
        input   wire [ 31:0]    read_data,
        input   wire [137:0]    EX_to_MEM_zip,

        output  wire            front_valid,
        output  wire [  4:0]    front_addr,
        output  wire [ 31:0]    front_data,
        output  wire            MEM_done,
        output  wire [ 31:0]    done_pc,
        output  wire [ 31:0]    loaded_data,

        output  wire            MEM_allowin,
        output  wire            write_en,
        output  wire [  3:0]    write_we,
        output  wire [ 31:0]    write_addr,
        output  wire [ 31:0]    write_data,
        output  reg  [102:0]    MEM_to_WB_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;
wire            inst_ld_w;
wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [31:0]     alu_result;
wire [ 4:0]     rf_waddr;
wire [31:0]     rf_wdata;

assign done_pc = pc;
assign front_valid = ~inst_ld_w & gr_we;
assign front_addr = rf_waddr;
assign front_data = alu_result;
assign MEM_done = readygo;
assign loaded_data = read_data;

reg             readygo;

always @(posedge clk) begin
        if (rst) begin
                readygo <= 1'b0;
        end
        else if (~readygo & (data_ready | data_valid)) begin
                readygo <= 1'b1;
        end
        else if (readygo & WB_allowin) begin
                readygo <= 1'b0;
        end
        else begin
                readygo <= readygo;
        end
end

assign MEM_allowin = ~valid | (readygo & WB_allowin);

assign  {
        valid, pc, IR, inst_ld_w, mem_we, res_from_mem, gr_we, rkd_value, rf_waddr, alu_result
} = EX_to_MEM_zip;


assign rf_wdata = res_from_mem ? read_data : alu_result;

assign write_en = (mem_we | inst_ld_w) & valid;
assign write_we = {4{mem_we & valid}};
assign write_addr = alu_result;
assign write_data = rkd_value;

always @(posedge clk) begin
        if (rst) begin
                MEM_to_WB_reg <= 103'b0;
        end
        else if (readygo & WB_allowin) begin
                MEM_to_WB_reg <= {valid & ~rst, pc, IR, gr_we, rf_waddr, rf_wdata};
        end
        else if (~readygo & WB_allowin) begin
                MEM_to_WB_reg <= 103'b0;
        end 
        else begin
                MEM_to_WB_reg <= MEM_to_WB_reg;
        end
end

endmodule
