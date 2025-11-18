`include "macros.h"

module IF (
        input   wire            clk,
        input   wire            rst,
        input   wire            inst_sram_addr_ok,
        input   wire            inst_sram_data_ok,

        input   wire            ID_allowin,

        input   wire [31:0]     inst,

        input   wire            ID_flush,
        input   wire [31:0]     ID_flush_target,

        input   wire            flush,
        input   wire [31:0]     flush_target,
        
        output  wire            inst_sram_en,
        output  reg  [31:0]     pc,
        output  reg  [66:0]     IF_to_ID_reg,

        output  wire            IF_to_ID
);


assign IF_to_ID = readygo & ID_allowin;

assign inst_sram_en = wait_addr_ok | lock_addr;

wire            predict;
// wire            br_taken;
// wire [31:0]     br_target;
// wire [ 5:0]     op_31_26;
// wire            inst_b;
// wire            inst_bl;
// wire            inst_beq;
// wire            inst_bne;
// wire            inst_jirl;
// wire            need_si26;
// wire [31:0]     br_offs;
// wire [63:0]     op_31_26_d;
// wire [15:0]     i16;
// wire [25:0]     i26;

// assign op_31_26         = inst[31:26];
// assign inst_jirl        = op_31_26_d[6'h13];
// assign inst_b           = op_31_26_d[6'h14];
// assign inst_bl          = op_31_26_d[6'h15];
// assign inst_beq         = op_31_26_d[6'h16];
// assign inst_bne         = op_31_26_d[6'h17];

// assign need_si26        = inst_b | inst_bl;
// assign i16              = inst[25:10];
// assign i26              = {inst[ 9: 0], inst[25:10]};
// assign br_offs          = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0}:
//                                       {{14{i16[15]}}, i16[15:0], 2'b0};

assign predict          = 1'b0;
// assign br_taken         = inst_beq & predict | inst_bne & predict | inst_bl | inst_b | inst_jirl;
// assign br_target        = pc_reg + br_offs;

// decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));

reg  [31:0]     IR;
reg             lock_addr;
reg             lock_data;
reg             wait_addr_ok;
reg             wait_data_ok;
reg             readygo;

wire [31:0]     pc_next;
assign pc_next = flush ? flush_target : 
                 ID_flush ? ID_flush_target : 
                 lock_data ? last_target : pc + 4;

wire            except_adef;
assign except_adef = (|pc[1:0]);

wire            g_flush;
assign g_flush = flush | ID_flush;

reg  [31:0]     last_target;
always @(posedge clk) begin
        if (rst) begin
                last_target <= 32'b0;
        end
        else if (g_flush) begin
                last_target <= flush ? flush_target : ID_flush_target;
        end
        else begin
                last_target <= last_target;
        end
end

wire            nxt_is_wait_addr_ok;
assign nxt_is_wait_addr_ok = wait_data_ok & g_flush & inst_sram_data_ok
                           | readygo & g_flush 
                           | readygo & ID_allowin 
                           | lock_data & inst_sram_data_ok;

always @(posedge clk) begin
        if (rst) begin
                pc <= `PC_INIT;
        end
        else if (nxt_is_wait_addr_ok) begin 
                pc <= pc_next;
        end 
        else begin
                pc <= pc;
        end
end

always @(posedge clk) begin
        if (rst) begin
                wait_addr_ok <= 1'b1;
        end
        else if (nxt_is_wait_addr_ok) begin
                wait_addr_ok <= 1'b1;
        end
        else if (wait_addr_ok & inst_sram_addr_ok | wait_addr_ok & g_flush) begin
                wait_addr_ok <= 1'b0;
        end
        else begin
                wait_addr_ok <= wait_addr_ok;
        end
end

always @(posedge clk) begin
        if (rst | g_flush) begin
                wait_data_ok <= 1'b0;
        end
        else if (wait_addr_ok & inst_sram_addr_ok) begin
                wait_data_ok <= 1'b1;
        end
        else if (wait_data_ok & inst_sram_data_ok) begin
                wait_data_ok <= 1'b0;
        end
        else begin
                wait_data_ok <= wait_data_ok;
        end
end

always @(posedge clk) begin
        if (rst | g_flush) begin
                readygo <= 1'b0;
        end
        else if (wait_data_ok & inst_sram_data_ok) begin
                readygo <= 1'b1;
        end
        else if (readygo & ID_allowin) begin
                readygo <= 1'b0;
        end
        else begin
                readygo <= readygo;
        end
end

always @(posedge clk) begin
        if (rst) begin
                lock_addr <= 1'b0;
        end
        else if (wait_addr_ok & g_flush & ~inst_sram_addr_ok) begin
                lock_addr <= 1'b1;
        end
        else if (lock_addr & inst_sram_addr_ok) begin 
                lock_addr <= 1'b0;
        end
        else begin
                lock_addr <= lock_addr;
        end
end

always @(posedge clk) begin
        if (rst) begin
                lock_data <= 1'b0;
        end
        else if (wait_addr_ok & g_flush & inst_sram_addr_ok | lock_addr & inst_sram_addr_ok | wait_data_ok & g_flush & ~inst_sram_data_ok) begin
                lock_data <= 1'b1;
        end
        else if (lock_data & inst_sram_data_ok) begin 
                lock_data <= 1'b0;
        end
        else begin
                lock_data <= lock_data;
        end
end

always @(posedge clk) begin
        if (rst) begin
                IR <= 32'b0;
        end
        else if (wait_data_ok & inst_sram_data_ok) begin
                IR <= inst;
        end
        else begin
                IR <= IR;
        end
end

always @(posedge clk) begin
        if (rst) begin
                IF_to_ID_reg <= 67'b0;
        end
        else if (readygo & ID_allowin) begin
                IF_to_ID_reg <= {~g_flush, predict, IR, pc, except_adef};
        end else begin
                IF_to_ID_reg <= IF_to_ID_reg;
        end
end

endmodule
