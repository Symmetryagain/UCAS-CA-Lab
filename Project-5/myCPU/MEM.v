module MEM(
        input   wire            clk,
        input   wire            rst,
        input   wire            WB_allowin,
        
        input   wire            data_sram_addr_ok,
        input   wire            data_sram_data_ok,
        input   wire [ 31:0]    read_data,
        input   wire [144:0]    EX_to_MEM_zip,
        input   wire [ 86:0]    EX_except_zip,

        input   wire            flush,

        output  wire            front_valid,
        output  wire [  4:0]    front_addr,
        output  wire [ 31:0]    front_data,
        
        output  wire            MEM_done,
        output  wire [ 31:0]    done_pc,
        output  wire [ 31:0]    loaded_data,

        output  wire            MEM_allowin,
        output  wire            write_en,
        output  wire [  3:0]    write_we,
        output  wire [  1:0]    write_size,
        output  wire [ 31:0]    write_addr,
        output  wire [ 31:0]    write_data,
        output  reg  [102:0]    MEM_to_WB_reg,
        output  reg  [118:0]    MEM_except_reg,
        input   wire            EX_to_MEM,
        output  wire            MEM_to_WB
);

assign MEM_to_WB = readygo & WB_allowin;
reg             at_state;
always @(posedge clk) begin
        if (rst) begin 
                at_state <= 1'b0;
        end
        else if (EX_to_MEM) begin
                at_state <= 1'b1;
        end
        else if (MEM_to_WB) begin
                at_state <= 1'b0;
        end
        else begin
                at_state <= at_state;
        end
end

wire            valid;
assign valid =  EX_to_MEM_valid & at_state & ~flush;

wire            EX_to_MEM_valid;
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

wire            except_ale;
assign except_ale = EX_except_zip[0];

assign done_pc = pc;
assign front_valid = ~res_from_mem & gr_we | res_from_mem;
assign front_addr = rf_waddr;
assign front_data = res_from_mem ? rf_wdata_LOAD : alu_result;

assign MEM_done = readygo;
assign loaded_data = rf_wdata_LOAD;

reg             init;
reg             wait_addr_ok;
reg             wait_data_ok;
reg             readygo;

always @(posedge clk) begin
        if (rst | flush) begin
                init <= 1'b1;
        end
        else if (readygo & WB_allowin) begin
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
                wait_addr_ok <= 1'b0;
        end
        else if (init & valid & (res_from_mem | mem_we) & ~except_ale) begin
                wait_addr_ok <= 1'b1;
        end
        else if (wait_addr_ok & data_sram_addr_ok) begin
                wait_addr_ok <= 1'b0;
        end
        else begin
                wait_addr_ok <= wait_addr_ok;
        end
end

always @(posedge clk) begin
        if (rst | flush) begin
                wait_data_ok <= 1'b0;
        end
        else if (wait_addr_ok & data_sram_addr_ok) begin
                wait_data_ok <= 1'b1;
        end
        else if (wait_data_ok & data_sram_data_ok) begin
                wait_data_ok <= 1'b0;
        end
        else begin
                wait_data_ok <= wait_data_ok;
        end
end

always @(posedge clk) begin
        if (rst | flush) begin
                readygo <= 1'b0;
        end
        else if (init & valid & (~res_from_mem & ~mem_we | except_ale) | wait_data_ok & data_sram_data_ok) begin
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
        EX_to_MEM_valid, pc, IR, 
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

assign write_en         = wait_addr_ok;

assign write_we_st_b    = (write_addr[1:0]==2'b00)? 4'b0001:
                          (write_addr[1:0]==2'b01)? 4'b0010:
                          (write_addr[1:0]==2'b10)? 4'b0100:
                          4'b1000;
assign write_we_st_h    = (write_addr[1:0]==2'b00)? 4'b0011:
                          4'b1100;                          
assign write_we         = {4{wait_addr_ok}} & 
                          (inst_st_b? write_we_st_b:
                          inst_st_h? write_we_st_h:
                          inst_st_w? 4'b1111:
                          4'b0000);

assign write_size       = {(inst_ld_w | inst_st_w), (inst_ld_h | inst_ld_hu | inst_st_h)};
                        
assign write_addr       = alu_result;
assign write_data       = inst_st_b? {4{rkd_value[7:0]}}:
                          inst_st_h? {2{rkd_value[15:0]}}:
                          rkd_value;

always @(posedge clk) begin
        if (rst) begin
                MEM_to_WB_reg <= 103'b0;
        end
        else if (readygo & WB_allowin) begin
                MEM_to_WB_reg <= {valid, pc, IR, gr_we, rf_waddr, rf_wdata};
        end
        else if (~readygo & WB_allowin) begin
                MEM_to_WB_reg <= 103'b0;
        end 
        else begin
                MEM_to_WB_reg <= MEM_to_WB_reg;
        end
end

always @(posedge clk) begin
        if (rst) begin
                MEM_except_reg <= 119'b0;
        end
        else if (readygo & WB_allowin) begin
                MEM_except_reg <= {EX_except_zip, write_addr};
        end
        else if (~readygo & WB_allowin) begin
                MEM_except_reg <= 119'b0;
        end 
        else begin
                MEM_except_reg <= MEM_except_reg;
        end
end

endmodule
