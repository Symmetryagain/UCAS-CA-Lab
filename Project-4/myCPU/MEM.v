module MEM(
        input   wire            clk,
        input   wire            rst,
        input   wire            WB_allowin,
        
        input   wire            data_ready,
        input   wire            data_valid,
        input   wire [ 31:0]    read_data,
        input   wire [144:0]    EX_to_MEM_zip,
        input   wire [ 81:0]    EX_except_reg,

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
        output  reg  [102:0]    MEM_to_WB_reg,
        output  reg  [ 81:0]    MEM_except_reg
);

wire            valid;
wire [31:0]     pc;
wire [31:0]     IR;

wire            inst_ld_w;
wire            inst_ld_b;
wire            inst_ld_h;
wire            inst_ld_bu;
wire            inst_ld_hu;
wire            inst_st_b;
wire            inst_st_h;
wire            inst_st_w;

wire            mem_we;
wire            res_from_mem;
wire            gr_we;
wire [31:0]     rkd_value;
wire [31:0]     alu_result;
wire [ 4:0]     rf_waddr;
wire [31:0]     rf_wdata;
wire [31:0]     rf_wdata_LOAD;
wire [31:0]     rf_wdata_ld_b;
wire [31:0]     rf_wdata_ld_bu;
wire [31:0]     rf_wdata_ld_h;
wire [31:0]     rf_wdata_ld_hu;

wire [3:0]      write_we_st_b;
wire [3:0]      write_we_st_h;

assign done_pc = pc;
assign front_valid = ~res_from_mem & gr_we;
assign front_addr = rf_waddr;
assign front_data = alu_result;
assign MEM_done = readygo;
assign loaded_data = rf_wdata_LOAD;

reg             readygo;

always @(posedge clk) begin
        if (rst) begin
                readygo <= 1'b0;
        end
        else if (~readygo & (data_ready | data_valid) & valid) begin
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
        valid, pc, IR, 
        inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, 
        inst_st_b, inst_st_h, inst_st_w, 
        mem_we, res_from_mem, gr_we, rkd_value, rf_waddr, alu_result
} = EX_to_MEM_zip;


assign rf_wdata_ld_b    = (write_addr[1:0]==2'b00)? {{24{read_data[7]}}, read_data[7:0]}:
                          (write_addr[1:0]==2'b01)? {{24{read_data[15]}},read_data[15:8]}:
			  (write_addr[1:0]==2'b10)? {{24{read_data[23]}},read_data[23:16]}:
  			                            {{24{read_data[31]}},read_data[31:24]};

assign rf_wdata_ld_bu   = (write_addr[1:0]==2'b00)? {24'b0, read_data[7:0]}:
                          (write_addr[1:0]==2'b01)? {24'b0,read_data[15:8]}:
			  (write_addr[1:0]==2'b10)? {24'b0,read_data[23:16]}:
  			                            {24'b0,read_data[31:24]};

assign rf_wdata_ld_h    = (write_addr[1])? {{16{read_data[31]}},read_data[31:16]}:
				  	   {{16{read_data[15]}},read_data[15:0]};
assign rf_wdata_ld_hu   = (write_addr[1])? {16'b0,read_data[31:16]}:
				  	   {16'b0,read_data[15:0]};

assign rf_wdata_LOAD    = inst_ld_b?  rf_wdata_ld_b : 
                          inst_ld_bu? rf_wdata_ld_bu:
                          inst_ld_h?  rf_wdata_ld_h :
                          inst_ld_hu? rf_wdata_ld_hu:
                          read_data;

assign rf_wdata         = res_from_mem ? rf_wdata_LOAD : alu_result;

assign write_en         = (mem_we | res_from_mem) & valid;

assign write_we_st_b    = (write_addr[1:0]==2'b00)? 4'b0001:
                          (write_addr[1:0]==2'b01)? 4'b0010:
                          (write_addr[1:0]==2'b10)? 4'b0100:
                          4'b1000;
assign write_we_st_h    = (write_addr[1:0]==2'b00)? 4'b0011:
                          4'b1100;                          
assign write_we         = {4{valid}} & 
                          (inst_st_b? {write_we_st_b}:
                          inst_st_h? write_we_st_h:
                          inst_st_w? 4'b1111:
                          4'b0000);
                  
assign write_addr       = alu_result;
assign write_data       = inst_st_b? {4{rkd_value[7:0]}}:
                          inst_st_h? {2{rkd_value[15:0]}}:
                          rkd_value;

always @(posedge clk) begin
        if (rst) begin
                MEM_to_WB_reg <= 103'b0;
                MEM_except_reg <= 82'b0;
        end
        else if (readygo & WB_allowin) begin
                MEM_to_WB_reg <= {valid & ~rst, pc, IR, gr_we, rf_waddr, rf_wdata};
                MEM_except_reg <= EX_except_reg;
        end
        else if (~readygo & WB_allowin) begin
                MEM_to_WB_reg <= 103'b0;
                MEM_except_reg <= 82'b0;
        end 
        else begin
                MEM_to_WB_reg <= MEM_to_WB_reg;
                MEM_except_reg <= MEM_except_reg;
        end
end

endmodule
