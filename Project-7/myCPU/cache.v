module cache (
        input   wire            clk,
        input   wire            resetn,
        // interface to CPU
        input   wire            valid,
        input   wire            op, // 0: read, 1: write
        input   wire            cacheable,
        input   wire [  7:0]    index,
        input   wire [ 19:0]    tag,
        input   wire [  3:0]    offset,
        input   wire [  3:0]    wstrb,
        input   wire [ 31:0]    wdata,
        input   wire            cacop_en,
        input   wire [  4:0]    cacop_code,
        input   wire  [31:0]    cacop_addr,
        output  wire            cacop_ok,
        output  wire            addr_ok,
        output  wire            data_ok,
        output  wire [ 31:0]    rdata,
        // interface to bridge
        output  wire            rd_req,
        output  wire [  2:0]    rd_type,
        output  wire [ 31:0]    rd_addr,
        input   wire            rd_rdy,
        input   wire            ret_valid,
        input   wire            ret_last,
        input   wire [ 31:0]    ret_data,
        output  wire            wr_req,
        output  wire [  2:0]    wr_type,
        output  wire [ 31:0]    wr_addr,
        output  wire [  3:0]    wr_wstrb,
        output  wire [127:0]    wr_data,
        input   wire            wr_rdy
);
// 主状态机状态
localparam IDLE    = 5'b00001;
localparam LOOKUP  = 5'b00010;
localparam MISS    = 5'b00100;
localparam REPLACE = 5'b01000;
localparam REFILL  = 5'b10000;

// Write Buffer 状态机状态
localparam WRITEBUF_IDLE  = 2'b01;
localparam WRITEBUF_WRITE = 2'b10;

wire    check;  
wire    keep_check;
wire    hitwrite;
wire    replace_write;

// 状态机寄存器
reg [4:0] current_state, next_state;
reg [1:0] writebuf_cstate, writebuf_nstate;

reg        reg_op;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;
reg        reg_cacheable;
reg        reg_cacop_en;
reg [4:0]  reg_cacop_code;
reg [31:0] reg_cacop_addr;

reg  [255:0] dirty [1:0];
wire   replace_dirty;
wire   cache_hit;
wire   way0_hit;
wire   way1_hit;

// 冲突/阻塞检测信号
wire need_pause;

wire [ 7:0] data_addr;
wire [31:0] data_wdata;
wire [31:0] data_w0_b0_rdata, data_w0_b1_rdata, 
        data_w0_b2_rdata, data_w0_b3_rdata, 
        data_w1_b0_rdata, data_w1_b1_rdata, 
        data_w1_b2_rdata, data_w1_b3_rdata;
wire        data_w0_b0_en, data_w0_b1_en, 
        data_w0_b2_en, data_w0_b3_en, 
        data_w1_b0_en, data_w1_b1_en, 
        data_w1_b2_en, data_w1_b3_en;
wire [ 3:0] data_w0_b0_we, data_w0_b1_we, 
        data_w0_b2_we, data_w0_b3_we, 
        data_w1_b0_we, data_w1_b1_we, 
        data_w1_b2_we, data_w1_b3_we;



// 主状态机
always @(posedge clk) begin
if (~resetn) 
        current_state <= IDLE;
else       
        current_state <= next_state;
end

always @(*) begin
        case (current_state)
                IDLE: begin
                // 如果没有检测到冲突，且请求有效，进入 LOOKUP
                if (valid && ~need_pause || cacop_en) 
                        next_state = LOOKUP;
                else                            
                        next_state = IDLE;
                end
                LOOKUP: begin
                if (~cache_hit || ~reg_cacheable || cacop_index_invalidate || cacop_hit_invalidate && cache_hit) 
                        next_state = MISS;
                // 流水线处理：如果命中，且新请求有效并无冲突，继续保持 LOOKUP 处理新请求
                else if (valid && ~need_pause) 
                        next_state = LOOKUP;
                else // cacop_store_tag || cacop_hit_invalidate && ~cache_hit
                        next_state = IDLE;
                end
                MISS: begin
                if (~reg_cacheable && reg_op && wr_rdy) 
                        next_state = IDLE;
                else if (wr_rdy || (~reg_cacheable && ~reg_op) || (reg_cacheable && ~replace_dirty) || reg_cacop_en) 
                        next_state = REPLACE;
                else                                
                        next_state = MISS;
                end
                REPLACE: begin
                if (rd_rdy) 
                        next_state = REFILL;
                else        
                        next_state = REPLACE;
                end
                REFILL: begin
                if (ret_valid && ret_last) 
                        next_state = IDLE;
                else                       
                        next_state = REFILL;
                end
                default: next_state = IDLE;
        endcase
end

// Write Buffer 状态机
always @(posedge clk) begin
        if (~resetn) 
                writebuf_cstate <= WRITEBUF_IDLE;
        else       
                writebuf_cstate <= writebuf_nstate;
end

always @(*) begin
        case (writebuf_cstate)
                WRITEBUF_IDLE: begin
                if ((current_state == LOOKUP) && reg_op && cache_hit)
                        writebuf_nstate = WRITEBUF_WRITE;
                else
                        writebuf_nstate = WRITEBUF_IDLE;
                end
                WRITEBUF_WRITE: begin
                if ((current_state == LOOKUP) && reg_op && cache_hit)
                        writebuf_nstate = WRITEBUF_WRITE;
                else
                        writebuf_nstate = WRITEBUF_IDLE;
                end
                default: writebuf_nstate = WRITEBUF_IDLE;
        endcase
end


// 任何情况都要check，如果连续lookup即为keep_check，写命中为hitwrite，读写未命中，则需要replace_write
// check读tagv和data，hitwrite，replace_write都是写入tagv，data
assign check = (current_state == IDLE) && valid && (~need_pause);
assign keep_check = (current_state == LOOKUP) && valid && cache_hit && (~need_pause);
assign hitwrite = (writebuf_cstate == WRITEBUF_WRITE);
assign replace_write = (current_state == REFILL) && ret_valid;

// need_pause 包含两种情况：
// (1) 端口冲突：WriteBuffer 正在向一Bank 写，而新来的读请求也要读该Bank。
// (2) 数据相关：Lookup 阶段是 Store，而新来的读请求访问同一地址 (RAW)。
assign need_pause = valid && !op && 
                                (current_state == LOOKUP && cache_hit && reg_op && index == reg_index && offset[3:2] == reg_offset[3:2] 
                                || writebuf_cstate == WRITEBUF_WRITE && offset[3:2] == reg_offset[3:2]);

always @(posedge clk) begin
        if (~resetn) begin
                reg_op <= 1'b0; 
                reg_index <= 8'b0; 
                reg_tag <= 20'b0;
                reg_offset <= 4'b0; 
                reg_wstrb <= 4'b0; 
                reg_wdata <= 32'b0;
                reg_cacheable <= 1'b0;
                reg_cacop_en <= 1'b0;
                reg_cacop_code <= 5'b0;
                reg_cacop_addr <= 32'b0;
        end
        else if (check || keep_check || cacop_en) begin
                reg_op <= op; 
                reg_index <= index; 
                reg_tag <= tag;
                reg_offset <= offset; 
                reg_wstrb <= wstrb; 
                reg_wdata <= wdata;
                reg_cacheable <= cacheable;
                reg_cacop_en <= cacop_en;
                reg_cacop_code <= cacop_code;
                reg_cacop_addr <= cacop_addr;
        end
        else if(current_state==IDLE && ~cacop_en)begin
                reg_cacop_en <= 1'b0;
        end
end

reg [ 1:0] refill_counter;
always @(posedge clk) begin
        if (~resetn) begin
                refill_counter <= 2'b0;
        end
        else if (ret_valid) begin
                if (ret_last) 
                        refill_counter <= 2'b0; // 看到最后一条，归零
                else 
                        refill_counter <= refill_counter + 2'b1; // 否则累加
        end
end

reg        hitwrite_way; 
reg [ 1:0] hitwrite_bank;
reg [ 7:0] hitwrite_index; 
reg [ 3:0] hitwrite_strb; 
reg [31:0] hitwrite_data;

always @(posedge clk) begin
        if (~resetn) begin
                hitwrite_way <= 1'b0; hitwrite_bank <= 2'b0; hitwrite_index <= 8'b0;
                hitwrite_strb <= 4'b0; hitwrite_data <= 32'b0;
        end
        else if ((current_state == LOOKUP) && reg_op && cache_hit) begin
                hitwrite_way  <= way1_hit;
                hitwrite_bank <= reg_offset[3:2];
                hitwrite_index<= reg_index;
                hitwrite_strb <= reg_wstrb;
                hitwrite_data <= reg_wdata;
        end
end

wire [19:0] way0_tag;
wire [19:0] way1_tag;
wire        way0_v;
wire        way1_v;
wire [20:0] tagv_w0_rdata;
wire [20:0] tagv_w1_rdata;

assign {way0_tag, way0_v} = tagv_w0_rdata;
assign {way1_tag, way1_v} = tagv_w1_rdata;
assign way0_hit = way0_v && (way0_tag == reg_tag) && reg_cacheable;
assign way1_hit = way1_v && (way1_tag == reg_tag) && reg_cacheable;
assign cache_hit = way0_hit || way1_hit;
wire [20:0] tagv_wdata;
wire [ 7:0] tagv_addr;
wire        tagv_w0_en;
wire        tagv_w1_en;
wire        tagv_w0_we;
wire        tagv_w1_we;

tagv_ram tagv_way0(
        .addra(tagv_addr),
        .clka(clk),
        .dina(tagv_wdata),
        .douta(tagv_w0_rdata),
        .ena(tagv_w0_en),
        .wea(tagv_w0_we)
);
tagv_ram tagv_way1(
        .addra(tagv_addr),
        .clka(clk),
        .dina(tagv_wdata),
        .douta(tagv_w1_rdata),
        .ena(tagv_w1_en),
        .wea(tagv_w1_we)
);

data_bank_ram data_way0_bank0(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w0_b0_rdata),
        .ena(data_w0_b0_en),
        .wea(data_w0_b0_we)
);
data_bank_ram data_way0_bank1(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w0_b1_rdata),
        .ena(data_w0_b1_en),
        .wea(data_w0_b1_we)
);
data_bank_ram data_way0_bank2(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w0_b2_rdata),
        .ena(data_w0_b2_en),
        .wea(data_w0_b2_we)
);
data_bank_ram data_way0_bank3(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w0_b3_rdata),
        .ena(data_w0_b3_en),
        .wea(data_w0_b3_we)
);
data_bank_ram data_way1_bank0(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w1_b0_rdata),
        .ena(data_w1_b0_en),
        .wea(data_w1_b0_we)
);
data_bank_ram data_way1_bank1(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w1_b1_rdata),
        .ena(data_w1_b1_en),
        .wea(data_w1_b1_we)
);
data_bank_ram data_way1_bank2(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w1_b2_rdata),
        .ena(data_w1_b2_en),
        .wea(data_w1_b2_we)
);
data_bank_ram data_way1_bank3(
        .addra(data_addr),
        .clka(clk),
        .dina(data_wdata),
        .douta(data_w1_b3_rdata),
        .ena(data_w1_b3_en),
        .wea(data_w1_b3_we)
);

wire replace_way;
reg  random_way;
always @(posedge clk) begin
        if(~resetn)
                random_way <= 1'b0;
        else if(next_state == LOOKUP)
                random_way <= $random() % 2;
end
assign replace_way = random_way;

wire            cacop_store_tag;
wire            cacop_index_invalidate;
wire            cacop_hit_invalidate;
wire  [20:0]    cacop_store_tag_data;
wire  [20:0]    cacop_index_invalidate_data;
wire  [20:0]    cacop_hit_invalidate_data;

assign cacop_store_tag        = (reg_cacop_code[4:3] == 2'b00) && (cacop_en | reg_cacop_en);
assign cacop_index_invalidate = (reg_cacop_code[4:3] == 2'b01) && (cacop_en | reg_cacop_en);
assign cacop_hit_invalidate   = (reg_cacop_code[4:3] == 2'b10) && (cacop_en | reg_cacop_en);

assign cacop_store_tag_data        = reg_cacop_addr[0]? {20'b0, tagv_w1_rdata[0]}: 
                                                        {20'b0, tagv_w0_rdata[0]};
assign cacop_index_invalidate_data = reg_cacop_addr[0]? {tagv_w1_rdata[20:1], 1'b0} :
                                                        {tagv_w0_rdata[20:1], 1'b0};
assign cacop_hit_invalidate_data   = way0_hit ?         {tagv_w0_rdata[20:1],1'b0}:
                                     way1_hit ?         {tagv_w1_rdata[20:1],1'b0}:
                                     21'b0;

assign tagv_wdata = cacop_store_tag ? cacop_store_tag_data :
                    cacop_hit_invalidate ? cacop_hit_invalidate_data:
                    cacop_index_invalidate ? cacop_index_invalidate_data :
                    {reg_tag, 1'b1}; // 替换时将新数据写入tagv

assign tagv_addr  = (cacop_store_tag | cacop_index_invalidate | cacop_hit_invalidate) ? reg_cacop_addr[11:4] :
                    {8{check}} & index | {8{replace_write}} & reg_index;

assign tagv_w0_en = check || (replace_write && (replace_way == 1'b0));
assign tagv_w1_en = check || (replace_write && (replace_way == 1'b1));
assign tagv_w0_we = replace_write && (replace_way == 1'b0) && (refill_counter == reg_offset[3:2]) && reg_cacheable;
assign tagv_w1_we = replace_write && (replace_way == 1'b1) && (refill_counter == reg_offset[3:2]) && reg_cacheable;


wire [127:0] way0_data, way1_data, replace_data;
wire [ 31:0] way0_load_word, way1_load_word;
wire [ 31:0] load_res;

assign way0_data = {data_w0_b3_rdata, data_w0_b2_rdata, data_w0_b1_rdata, data_w0_b0_rdata};
assign way1_data = {data_w1_b3_rdata, data_w1_b2_rdata, data_w1_b1_rdata, data_w1_b0_rdata};
assign way0_load_word = way0_data[reg_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[reg_offset[3:2]*32 +: 32];

assign load_res = {32{way0_hit}} & way0_load_word |
                  {32{way1_hit}} & way1_load_word |
                  {32{replace_write}} & ret_data;       // 替换回写进cache

// dirty 表
always @(posedge clk) begin
        if (~resetn) begin
                dirty[0] <= 256'b0;
                dirty[1] <= 256'b0;
        end
        else if (hitwrite) begin
                dirty[hitwrite_way][hitwrite_index] <= 1'b1;
        end
        else if (replace_write) begin
                dirty[replace_way][reg_index] <= reg_op;
        end
end
assign replace_dirty = (replace_way == 1'b0) && dirty[0][reg_index] && way0_v 
                    || (replace_way == 1'b1) && dirty[1][reg_index] && way1_v;
assign replace_data = replace_way? way1_data : way0_data;

wire [31:0] refill_data;
wire [31:0] rewrite_data;

assign rewrite_data = {{reg_wstrb[3]? reg_wdata[31:24] : ret_data[31:24]},
                       {reg_wstrb[2]? reg_wdata[23:16] : ret_data[23:16]},
                       {reg_wstrb[1]? reg_wdata[15: 8] : ret_data[15: 8]},
                       {reg_wstrb[0]? reg_wdata[ 7: 0] : ret_data[ 7: 0]}};
// 写缺失时,要写的数据为内存旧数据叠加输入新数据，不能直接靠wstrb解决，因为wstrb为0就不再写入
assign refill_data = ((refill_counter == reg_offset[3:2]) && reg_op)? rewrite_data : //写缺失写回混合数据
                                                                                ret_data; //读缺失写回内存旧数据
assign data_wdata = replace_write? refill_data :
                    hitwrite? hitwrite_data : 32'b0;

assign data_addr  = (replace_write) ? reg_index   :
                (hitwrite           ? hitwrite_index ://hitwrite后存的数据，可能已被更新，不能直接使用寄存
                (check              ? index       : 8'b0));

assign data_w0_b0_en = check  && (offset[3:2] == 2'b00) || //此时读，不写
                hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b00)  || 
                replace_write && (replace_way == 1'b0) && (refill_counter == 2'b00);
assign data_w0_b1_en = check  && (offset[3:2] == 2'b01) ||
                hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b01)  ||
                replace_write && (replace_way == 1'b0) && (refill_counter == 2'b01);
assign data_w0_b2_en = check  && (offset[3:2] == 2'b10) ||
                hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b10)  ||
                replace_write && (replace_way == 1'b0) && (refill_counter == 2'b10);
assign data_w0_b3_en = check  && (offset[3:2] == 2'b11) ||
                hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b11)  ||
                replace_write && (replace_way == 1'b0) && (refill_counter == 2'b11);
assign data_w1_b0_en = check  && (offset[3:2] == 2'b00) ||
                hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b00)  ||
                replace_write && (replace_way == 1'b1) && (refill_counter == 2'b00);
assign data_w1_b1_en = check  && (offset[3:2] == 2'b01) ||
                hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b01)  ||
                replace_write && (replace_way == 1'b1) && (refill_counter == 2'b01);
assign data_w1_b2_en = check  && (offset[3:2] == 2'b10) ||
                hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b10)  ||
                replace_write && (replace_way == 1'b1) && (refill_counter == 2'b10);
assign data_w1_b3_en = check  && (offset[3:2] == 2'b11) ||
                hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b11)  ||
                replace_write && (replace_way == 1'b1) && (refill_counter == 2'b11);

assign data_w0_b0_we = {4{hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b00)}} & hitwrite_strb |
                {4{replace_write&& (replace_way == 1'b0) && (refill_counter == 2'b00)}};
assign data_w0_b1_we = {4{hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b01)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b0) && (refill_counter == 2'b01)}};
assign data_w0_b2_we = {4{hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b10)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b0) && (refill_counter == 2'b10) }};
assign data_w0_b3_we = {4{hitwrite && (hitwrite_way == 1'b0) && (hitwrite_bank == 2'b11)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b0) && (refill_counter == 2'b11)}};
assign data_w1_b0_we = {4{hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b00)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b1) && (refill_counter == 2'b00)}};
assign data_w1_b1_we = {4{hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b01)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b1) && (refill_counter == 2'b01)}};
assign data_w1_b2_we = {4{hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b10)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b1) && (refill_counter == 2'b10)}};
assign data_w1_b3_we = {4{hitwrite && (hitwrite_way == 1'b1) && (hitwrite_bank == 2'b11)}} & hitwrite_strb |
                {4{replace_write && (replace_way == 1'b1) && (refill_counter == 2'b11)}};


assign addr_ok = (current_state == IDLE) ||
                 (current_state == LOOKUP) && cache_hit && valid && ~need_pause;
assign data_ok = (current_state == LOOKUP) && cache_hit || 
                 (current_state == LOOKUP) && reg_op    ||
                 (current_state == REFILL) && ret_valid && (reg_cacheable && (refill_counter == reg_offset[3:2]) || ~reg_cacheable) && ~reg_op;
assign rdata   = load_res;

// AXI 
assign rd_req = (current_state == REPLACE) && (reg_cacheable || ~reg_op);
assign rd_type = reg_cacheable? 3'b100 : 3'b010;
assign rd_addr = reg_cacheable? {reg_tag, reg_index, 4'b0000} : 
                            {reg_tag, reg_index, reg_offset};

// reg reg_wr_req;
// always @(posedge clk) begin
//         if (!resetn) begin
//                 reg_wr_req <= 1'b0;
//         end
//         else if (current_state == MISS && next_state == REPLACE) begin
//                 reg_wr_req <= 1'b1;
//         end
//         else if (wr_rdy) begin
//                 reg_wr_req <= 1'b0;
//         end
// end

assign wr_req = (current_state == MISS) && (replace_dirty || (~reg_cacheable && reg_op));
assign wr_type = reg_cacheable? 3'b100 : 3'b010;
assign wr_addr = ~reg_cacheable? {reg_tag, reg_index, reg_offset} :
                 replace_way? {way1_tag, reg_index, 4'b0000} :
                              {way0_tag, reg_index, 4'b0000};
assign wr_wstrb = reg_cacheable? 4'b1111 : reg_wstrb;
assign wr_data = reg_cacheable? replace_data : {96'b0, reg_wdata};

endmodule