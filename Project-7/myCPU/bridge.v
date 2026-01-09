module bridge(
        input   wire            aclk,
        input   wire            aresetn,

        // ICache 读接口
        input   wire            icache_rd_req,
        input   wire [  2:0]    icache_rd_type,
        input   wire [ 31:0]    icache_rd_addr,
        output  wire            icache_rd_rdy,
        output  wire            icache_ret_valid,
        output  wire            icache_ret_last,
        output  wire [ 31:0]    icache_ret_data,
        
        // DCache 读接口
        input   wire            dcache_rd_req,
        input   wire [  2:0]    dcache_rd_type,
        input   wire [ 31:0]    dcache_rd_addr,
        output  wire            dcache_rd_rdy,
        output  wire            dcache_ret_valid,
        output  wire            dcache_ret_last,
        output  wire [ 31:0]    dcache_ret_data,
        
        // DCache 写接口
        input   wire            dcache_wr_req,
        input   wire [  2:0]    dcache_wr_type,
        input   wire [ 31:0]    dcache_wr_addr,
        input   wire [  3:0]    dcache_wr_wstrb,
        input   wire [127:0]    dcache_wr_data,
        output  wire            dcache_wr_rdy,

        // ar 读请求通道
        output  reg  [  3:0]    arid,
        output  reg  [ 31:0]    araddr,
        output  reg  [  7:0]    arlen,
        output  wire [  2:0]    arsize,    
        output  wire [  1:0]    arburst,
        output  wire [  1:0]    arlock,
        output  wire [  3:0]    arcache,
        output  wire [  2:0]    arprot,
        output  wire            arvalid, 
        input   wire            arready,
        
        // r 读响应通道
        input   wire [  3:0]    rid,
        input   wire [ 31:0]    rdata,
        input   wire [  1:0]    rresp,
        input   wire            rlast,
        input   wire            rvalid,
        output  wire            rready,

        // aw 写请求通道
        output  wire [  3:0]    awid,
        output  reg  [ 31:0]    awaddr,
        output  reg  [  7:0]    awlen,
        output  reg  [  2:0]    awsize,
        output  wire [  1:0]    awburst,
        output  wire [  1:0]    awlock,
        output  wire [  3:0]    awcache,
        output  wire [  2:0]    awprot,
        output  wire            awvalid,
        input   wire            awready,

        // w 写数据通道
        output  wire [  3:0]    wid,
        output  reg  [ 31:0]    wdata,
        output  reg  [  3:0]    wstrb,
        output  wire            wlast,
        output  wire            wvalid,
        input   wire            wready,

        // b 写响应通道
        input   wire [  3:0]    bid,
        input   wire [  1:0]    bresp,
        input   wire            bvalid,
        output  wire            bready
);

// Cache 请求信号
wire rinst_req;
wire rdata_req;
wire wdata_req;

assign rinst_req = icache_rd_req;
assign rdata_req = dcache_rd_req;
assign wdata_req = dcache_wr_req;

// 状态机常量定义
localparam  ar_init         = 3'b001,
            ar_wait         = 3'b010,
            ar_req          = 3'b100,

            r_wait          = 4'b0001,
            r_start         = 4'b0010,  
            r_reading       = 4'b0100, 
            r_done          = 4'b1000,

            w_wait          = 5'b00001,
            w_wait_aw_w     = 5'b00010,
            w_wait_w        = 5'b00100,
            w_wait_aw       = 5'b01000,
            w_done          = 5'b10000,

            b_wait          = 2'b01,
            b_done          = 2'b10;

reg [2:0] ar_cur_state;
reg [2:0] ar_next_state;

reg [3:0] r_cur_state;
reg [3:0] r_next_state;

reg [4:0] w_cur_state;
reg [4:0] w_next_state;

reg [1:0] b_cur_state;
reg [1:0] b_next_state;

reg [1:0]  r_cnt;
reg [3:0]  rid_reg;
reg [31:0] rdata_buffer [1:0];

// 写 Burst 相关寄存器
reg [1:0]   wdata_index;
reg [127:0] dcache_wr_data_r;
reg [3:0]   dcache_wr_wstrb_r;

wire reset;
assign reset = ~aresetn;

wire need_wait;  
assign need_wait = (araddr == awaddr) & (|w_cur_state[4:1]);

reg rvalid_reg;
always @(posedge aclk) begin
        if (reset) begin
                rvalid_reg <= 1'b0;
        end
        else begin
                rvalid_reg <= rvalid;
        end
end

// read_buffer
always @(posedge aclk) begin
    if(reset) begin
        rdata_buffer[0] <= 32'b0;
        rdata_buffer[1] <= 32'b0;
    end
    else if(rready & rvalid) begin
        rdata_buffer[rid[0]] <= rdata;
    end
end

// r_cnt
always @(posedge aclk) begin
    if(reset)
        r_cnt <= 2'b0;
    else if(arvalid & arready & rvalid & rready & rlast)
        r_cnt <= r_cnt;
    else if(arvalid & arready)
        r_cnt <= r_cnt + 2'b1;
    else if(rvalid & rready & rlast)
        r_cnt <= r_cnt - 2'b1;
end

// 读请求状态机 
always @(posedge aclk) begin
    if(reset)
        ar_cur_state <= ar_init;
    else
        ar_cur_state <= ar_next_state;
end

always @(*) begin
    case(ar_cur_state)
        ar_init: begin
            if(reset)
                ar_next_state = ar_init;
            else if(rdata_req)
                ar_next_state = ar_wait;   
            else if(rinst_req)
                ar_next_state = ar_req;
            else
                ar_next_state = ar_init;
        end
        ar_wait: begin 
            if(need_wait)
                ar_next_state = ar_wait;
            else
                ar_next_state = ar_req;
        end
        ar_req: begin
            if(arvalid & arready)
                ar_next_state = ar_init;
            else
                ar_next_state = ar_req;
        end
        default:
            ar_next_state = ar_init;
    endcase
end


// 读响应状态机 (R Channel) - 新增reading状态以支持 Burst
always @(posedge aclk) begin
    if(reset)
        r_cur_state <= r_wait;
    else
        r_cur_state <= r_next_state;
end

always @(*) begin
    case(r_cur_state)
        r_wait: begin
            if(arvalid & arready | (|r_cnt))
                r_next_state = r_start;
            else
                r_next_state = r_wait;
        end
        r_start: begin
            if(rvalid & rready) begin
                if(rlast)
                    r_next_state = r_done;
                else
                    r_next_state = r_reading;
            end
            else
                r_next_state = r_start;
        end
        r_reading: begin
            if(rvalid & rready) begin
                if(rlast)
                    r_next_state = r_done;
                else
                    r_next_state = r_reading;
            end
            else
                r_next_state = r_reading;
        end
        r_done:
            r_next_state = r_wait;
        default:
            r_next_state = r_wait;
    endcase
end


// 写请求状态机 (AW & W Channel)
always @(posedge aclk) begin
    if(reset)
        w_cur_state <= w_wait;
    else 
        w_cur_state <= w_next_state;
end

always @(*) begin
    case(w_cur_state)
        w_wait: begin
            if(dcache_wr_rdy & wdata_req)
                w_next_state = w_wait_aw_w;
            else
                w_next_state = w_wait;
        end
        w_wait_aw_w: begin
            // 检查 wlast，支持多拍传输
            if(awvalid & awready & wvalid & wready) begin
                if(wlast)  // 地址和最后一拍数据同时握手
                    w_next_state = w_done;
                else       // 地址握手了，但数据还没发完
                    w_next_state = w_wait_w;
            end
            else if(awvalid & awready)
                w_next_state = w_wait_w;
            else if(wvalid & wready) begin
                if(wlast)  // 最后一拍数据握手了，但地址还没握手
                    w_next_state = w_wait_aw;
                else       // 数据握手了，但还有后续数据
                    w_next_state = w_wait_aw_w;  // 继续等待
            end
            else
                w_next_state = w_wait_aw_w;
        end
        w_wait_aw: begin
            if(awvalid & awready) 
                w_next_state = w_done;
            else 
                w_next_state = w_wait_aw;
        end
        w_wait_w: begin
            // 检查 wlast，支持多拍传输
            if(wvalid & wready) begin
                if(wlast)  // 最后一拍数据发送完成
                    w_next_state = w_done;
                else       // 还有后续数据，继续发送
                    w_next_state = w_wait_w;
            end
            else
                w_next_state = w_wait_w;
        end
        w_done: begin
            if(bvalid & bready)
                w_next_state = w_wait;
            else
                w_next_state = w_done;
        end
        default:
            w_next_state = w_wait;
    endcase
end


always @(posedge aclk) begin
    if(reset)
        b_cur_state <= b_wait;
    else
        b_cur_state <= b_next_state;
end

always @(*) begin
    case(b_cur_state)
        b_wait: begin
            if(wvalid && wready && wlast)
                b_next_state = b_done;
            else
                b_next_state = b_wait;
        end
        b_done: begin
            if(bvalid && bready)
                b_next_state = b_wait;
            else
                b_next_state = b_done;
        end
        default:
            b_next_state = b_wait;
    endcase
end


// AXI 控制信号
assign arvalid = ar_cur_state[2];
assign rready  = r_cur_state[1] | r_cur_state[2];  // r_start 或 r_reading

assign awvalid = w_cur_state[1] | w_cur_state[3];
assign wvalid  = w_cur_state[1] | w_cur_state[2];
assign bready  = w_cur_state[4];

always @(posedge aclk) begin
    if(reset) begin
        arid <= 4'b0;
    end
    else if(ar_cur_state[0]) begin
        arid <= {3'b0, rdata_req};
    end
end

always @(posedge aclk) begin
    if(reset) begin
        araddr <= 32'b0;
    end
    else if(ar_cur_state[0]) begin
        araddr <= rdata_req ? dcache_rd_addr : icache_rd_addr;
    end
end

assign arsize = 3'b010;

// always @(posedge aclk) begin
//     if(reset) begin
//         arsize <= 3'b010;
//     end
//     else if(ar_cur_state[0]) begin
//         arsize <= rdata_req ? {1'b0, dcache_rd_type[1:0]} : {1'b0, icache_rd_type[1:0]};
//     end
// end

always @(posedge aclk) begin
    if(reset) begin
        arlen <= 8'b0;
    end
    else if(ar_cur_state[0]) begin
        arlen[1:0] <= rdata_req ? {2{dcache_rd_type[2]}} : {2{icache_rd_type[2]}};
    end
end

assign arburst = 2'b01;
assign arlock  = 2'b0;
assign arcache = 4'b0;
assign arprot  = 3'b0;

always @(posedge aclk) begin
    if(reset) begin
        awaddr <= 32'b0;
        awsize <= 3'b0;
    end
    else if(w_cur_state[0]) begin
        awaddr <= dcache_wr_addr;
        awsize <= {1'b0, dcache_wr_type[1:0]};
    end
end

always @(posedge aclk) begin
    if(reset) begin
        awlen <= 8'b0;
    end
    else if(w_cur_state[0]) begin
        awlen[1:0] <= {2{dcache_wr_type[2]}};
    end
end

assign awid    = 4'b0001;
assign awburst = 2'b01;
assign awlock  = 2'b0;
assign awcache = 4'b0;
assign awprot  = 3'b0;



// 写数据缓存
always @(posedge aclk) begin
    if(reset) begin
        dcache_wr_data_r <= 128'b0;
        dcache_wr_wstrb_r <= 4'b0;
    end
    else if(w_cur_state[0]) begin
        dcache_wr_data_r <= dcache_wr_data;
        dcache_wr_wstrb_r <= dcache_wr_wstrb;
    end
end

// 索引计数器
always @(posedge aclk) begin
    if(reset)
        wdata_index <= 2'b0;
    else if(w_cur_state[0] & ~wdata_req | w_cur_state[4] & bvalid & bready)
        wdata_index <= 2'b0;
    else if(wvalid & wready)
        wdata_index <= wdata_index + 2'b1;
end

// 根据索引选择数据
always @(posedge aclk) begin
    if(reset) begin
        wstrb <= 4'b0;
        wdata <= 32'b0;
    end
    else if(w_cur_state[0] | (wvalid & wready)) begin
        wstrb <= dcache_wr_wstrb;
        case(wdata_index)
            2'b00: wdata <= dcache_wr_data[31:0];
            2'b01: wdata <= dcache_wr_data[63:32];
            2'b10: wdata <= dcache_wr_data[95:64];
            2'b11: wdata <= dcache_wr_data[127:96];
        endcase
    end
end

assign wid   = 4'b0001;
assign wlast = dcache_rd_type[2]? &wdata_index : ~|wdata_index;


always @(posedge aclk) begin
    if(reset)
        rid_reg <= 4'b0;
    else if(rvalid & rready)
        rid_reg <= rid;
end


// ICache 读接口
assign icache_rd_rdy     = ar_cur_state[0] & ~need_wait & ~rdata_req;
assign icache_ret_data   = rdata_buffer[0];
assign icache_ret_valid  = ~rid_reg[0] & (|r_cur_state[3:2]) & rvalid_reg;
assign icache_ret_last   = ~rid_reg[0] & r_cur_state[3];

// DCache 读接口
assign dcache_rd_rdy     = ar_cur_state[0] & ~need_wait & rdata_req;
assign dcache_ret_data   = rdata_buffer[1];
assign dcache_ret_valid  = rid_reg[0] & (|r_cur_state[3:2]) & rvalid_reg;
assign dcache_ret_last   = rid_reg[0] & r_cur_state[3];

// DCache 写接口
assign dcache_wr_rdy     = w_cur_state[0] & b_cur_state[0];

endmodule
