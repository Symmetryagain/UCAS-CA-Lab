module bridge(
    input           aclk,
    input           aresetn,

    input           inst_sram_req,
    input           inst_sram_wr,
    input  [1:0]    inst_sram_size,
    input  [31:0]   inst_sram_addr,
    input  [3:0]    inst_sram_wstrb,
    input  [31:0]   inst_sram_wdata,
    output [31:0]   inst_sram_rdata,
    output          inst_sram_addr_ok,
    output          inst_sram_data_ok,

    input           data_sram_req,
    input           data_sram_wr,
    input  [1:0]    data_sram_size,
    input  [31:0]   data_sram_addr,
    input  [3:0]    data_sram_wstrb,
    input  [31:0]   data_sram_wdata,
    output [31:0]   data_sram_rdata,
    output          data_sram_addr_ok,
    output          data_sram_data_ok,


    //ar    读请求通道
    output reg[3:0]    arid,
    output reg[31:0]   araddr,
    output    [7:0]    arlen,
    output reg[2:0]    arsize,    
    output    [1:0]    arburst,
    output    [1:0]    arlock,
    output    [3:0]    arcache,
    output    [2:0]    arprot,
    output             arvalid, 
    input              arready,
    //r  读响应通道
    input  [3:0]       rid,
    input  [31:0]      rdata,
    input  [1:0]       rresp,
    input              rlast,
    input              rvalid,
    output             rready,

    //aw  写请求通道
    output    [3:0]    awid,
    output reg[31:0]   awaddr,
    output    [7:0]    awlen,
    output reg[2:0]    awsize,
    output    [1:0]    awburst,
    output    [1:0]    awlock,
    output    [1:0]    awcache,
    output    [2:0]    awprot,
    output             awvalid,
    input              awready,

    //w  写数据通道
    output    [3:0]    wid,
    output reg[31:0]   wdata,
    output reg[3:0]    wstrb,
    output             wlast,
    output             wvalid,
    input              wready,

    //b  写响应通道
    input  [3:0]       bid,
    input  [1:0]       bresp,
    input              bvalid,
    output             bready
);

wire rinst_req;
wire winst_req;
wire rdata_req;
wire wdata_req;
//读/写  inst/data
assign rinst_req = inst_sram_req && ~inst_sram_wr;      
assign winst_req = inst_sram_req && inst_sram_wr;
assign rdata_req = data_sram_req && ~data_sram_wr;
assign wdata_req = data_sram_req && data_sram_wr;


            //读请求状态机
localparam  ar_wait         = 2'b01,
            ar_req          = 2'b10,

            //读响应状态机
            r_wait          = 3'b001,
            r_read          = 3'b010,
            r_done          = 3'b100,

            //写请求、数据状态机
            w_wait          = 5'b00001,
            w_wait_aw_w     = 5'b00010,
            w_wait_w        = 5'b00100,
            w_wait_aw       = 5'b01000,
            w_done          = 5'b10000,

            //写响应状态机
            b_wait          = 2'b01,
            b_done          = 2'b10;

reg [1:0] ar_cur_state;
reg [1:0] ar_next_state;

reg [2:0] r_cur_state;
reg [2:0] r_next_state;

reg [4:0] w_cur_state;
reg [4:0] w_next_state;

reg [1:0] b_cur_state;
reg [1:0] b_next_state;

wire reset;
assign reset = ~aresetn;

wire need_wait;  
assign need_wait = (araddr == awaddr) & (|w_cur_state[4:1]);

//读请求状态机
always @(posedge aclk)
    begin
        if(reset)
            ar_cur_state <= ar_wait;
        else
            ar_cur_state <= ar_next_state;
    end

always @(*)
    begin
        case(ar_cur_state)
            ar_wait:
                begin
                    if(reset| need_wait)
			ar_next_state = ar_wait;
                    else if(rinst_req | rdata_req)
                        ar_next_state = ar_req;
                    else
                        ar_next_state = ar_wait;
                end
            ar_req:
                begin
                    if(arvalid && arready)
                        ar_next_state = ar_wait;
                    else
                        ar_next_state = ar_req;
                end
        endcase
    end

///读响应状态机/

always @(posedge aclk)
    begin
        if(reset)
            r_cur_state <= r_wait;
        else
            r_cur_state <= r_next_state;
    end

always @(*)
    begin
        case(r_cur_state)
            r_wait:
                begin
                    if(arvalid & arready)
                        r_next_state = r_read;
                    else
                        r_next_state = r_wait;
                end
            r_read:
                begin
                    if(rvalid && rready)
                        r_next_state = r_done;
                    else
                        r_next_state = r_read;
                end
            r_done:
                        r_next_state = r_wait;

        endcase
    end

always @(posedge aclk) begin
        if(reset)
                w_cur_state <= w_wait;
        else 
                w_cur_state <= w_next_state;
end

always @(*) begin
        case(w_cur_state)
                w_wait:begin
                        if(data_sram_wr)
                                w_next_state = w_wait_aw_w;
                        else
                                w_next_state = w_wait;
                end
                w_wait_aw_w:
                        if(awvalid & awready & wvalid & wready)
                                w_next_state = w_done;
                        else if(awvalid & awready)
                                w_next_state = w_wait_w;
                        else if(wvalid & wready)
                                w_next_state = w_wait_aw;
                        else
                                w_next_state = w_wait_aw_w;
                w_wait_aw:begin
                        if(wvalid & wready) 
                                w_next_state = w_done;
                        else 
                                w_next_state = w_wait_aw;
                end
                w_wait_w:begin
                        if(awvalid & awready)
                                w_next_state = w_done;
                        else
                                w_next_state = w_done;
                end
                w_done:
                        if(bvalid & bready)
                                w_next_state = w_wait;
                        else
                                w_next_state = w_done;
        endcase
end

//写响应状态机

always @(posedge aclk)
    begin
        if(reset)
            b_cur_state <= b_wait;
        else
            b_cur_state <= b_next_state;
    end

always @(*)
    begin
        case(b_cur_state)
            b_wait:
                begin
                    if(wvalid && wready)
                        b_next_state = b_done;
                    else
                        b_next_state = b_wait;
                end
            b_done:
                begin
                    if(bvalid && bready)
                        b_next_state = b_wait;
                    else
                        b_next_state = b_done;
                end
        endcase
    end


assign arvalid = ar_cur_state[1];
assign rready = r_cur_state[1];

assign awvalid = w_cur_state[1] | w_cur_state[3];
assign wvalid = w_cur_state[1] | w_cur_state[2];
assign bready = w_cur_state[4];




always @(posedge aclk) begin
    if(reset) begin
        arid <= 4'b0;
    end
    else if(ar_cur_state[0]) begin 
        // 数据RAM请求优先于指令RAM
        arid <= {3'b0, rdata_req}; 
    end
end



always @(posedge aclk) begin
    if(reset) begin
        araddr <= 32'b0;
    end
    else if(ar_cur_state[0]) begin
        if (rdata_req)
            araddr <= data_sram_addr;
        else
            araddr <= inst_sram_addr;
    end
end


always @(posedge aclk) begin
    if(reset) begin
        arsize <= 3'b0;
    end
    else if(ar_cur_state[0]) begin
        if (rdata_req)
            arsize <= {1'b0, data_sram_size};
        else
            arsize <= {1'b0, inst_sram_size};
    end
end

always  @(posedge aclk) begin
        if(reset) begin
                awaddr <= 32'b0;
                awsize <= 3'b0;
        end
        else if(w_cur_state[0]) begin	
                awaddr <= data_sram_wr? data_sram_addr : inst_sram_addr;
                awsize <= data_sram_wr? {1'b0, data_sram_size} : {1'b0, inst_sram_size};
        end
end

always  @(posedge aclk) begin
        if(reset) begin
                wstrb <= 4'b0;
                wdata <= 32'b0;
        end
        else if(w_cur_state[0]) begin
                wstrb <= data_sram_wstrb;
                wdata <= data_sram_wdata;
        end
end
assign arlen   = 8'b0;
assign arburst = 2'b1;
assign arlock  = 1'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

assign awid     = 4'b1;
assign awlen    = 8'b0;
assign awburst  = 2'b01;
assign awlock   = 1'b0;
assign awcache  = 4'b0;
assign awprot   = 3'b0;


assign wid      = 4'b1;
assign wlast    = 1'b1;




reg [31:0] inst_rdata_reg;
reg [31:0] data_rdata_reg;

always @(posedge aclk)
    begin
        if(reset)
            inst_rdata_reg <= 32'b0;
        else if(r_cur_state[1] && rvalid && rready && ~rid[0])
            inst_rdata_reg <= rdata;
    end

always @(posedge aclk)
    begin
        if(reset)
            data_rdata_reg <= 32'b0;
        else if(r_cur_state[1] && rvalid && rready && rid[0])
            data_rdata_reg <= rdata;
    end

assign inst_sram_rdata = inst_rdata_reg;
assign data_sram_rdata = data_rdata_reg;

assign inst_sram_addr_ok =;

assign data_sram_addr_ok =;

assign inst_sram_data_ok =;

assign data_sram_data_ok =;
endmodule