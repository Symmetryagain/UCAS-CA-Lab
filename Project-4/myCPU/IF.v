module IF (
        input   wire            clk,
        input   wire            rst,
        input   wire            inst_ready,
        input   wire            inst_valid,

        input   wire            ID_allowin,

        input   wire [31:0]     inst,

        input   wire            ID_flush,
        input   wire [31:0]     ID_flush_target,

        input   wire            flush,
        input   wire [31:0]     flush_target,
        
        output  wire            inst_sram_en,
        output  wire [31:0]     pc_next,
        output  reg  [64:0]     IF_to_ID_reg
);

`define PC_INIT 32'h1bfffffc

assign inst_sram_en = ~rst & ID_allowin;

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

reg  [31:0]     pc;
reg  [31:0]     IR;

assign pc_next = flush ? flush_target: ID_flush ? ID_flush_target : pc + 4;

always @(posedge clk) begin
        if (rst) begin
                pc <= `PC_INIT;
        end
        else if (ID_allowin) begin 
                pc <= pc_next;
        end 
        else begin
                pc <= pc;
        end
end

always @(posedge clk) begin
        if (rst) begin
                IR <= 32'b0;
        end
        else if (ID_allowin) begin
                IR <= inst;
        end
        else begin
                IR <= IR;
        end
end

always @(posedge clk) begin
        if (rst) begin
                IF_to_ID_reg <= {1'b0, 32'b0, `PC_INIT};
        end
        // else if(flush)begin
        //         IF_to_ID_reg <= {predict, ,pc};
        // end
        else if (ID_allowin) begin
                IF_to_ID_reg <= {predict, inst, pc};
        end else begin
                IF_to_ID_reg <= IF_to_ID_reg;
        end
end

endmodule
