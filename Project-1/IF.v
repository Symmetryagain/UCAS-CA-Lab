module IF (
        input   wire            clk,
        input   wire            rst,
        input   wire            flush,

        input   wire            ID_allowin,

        input   wire [31:0]     inst,
        input   wire [31:0]     pc_real,
        output  reg  [31:0]     pc,
        output  reg  [64:0]     IF_to_ID_reg
);

reg             readygo;
// readygo & ID_allowin
always @(posedge clk) begin
        if (rst) begin
                readygo <= 1'b0;
        end
        else begin
                readygo <= 1'b1;
        end
end

// wire [31:0]     seq_pc;
// wire [31:0]     nextpc;
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

reg  [31:0]     pc_reg;

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
// assign seq_pc           = pc + 32'h4;
// assign br_taken         = inst_beq & predict | inst_bne & predict | inst_bl | inst_b | inst_jirl;
// assign br_target        = pc_reg + br_offs;
// assign nextpc           = br_taken ? br_target : seq_pc;

// decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));

always @(posedge clk) begin
        if (rst) begin
                pc_reg <= 32'h1bfffffc;
        end
        else begin
                pc_reg <= pc;
        end
end

always @(posedge clk) begin
        if (rst) begin
                pc <= 32'h1bfffffc;
        end
        else if (flush) begin
                pc <= pc_real;
        end
        else begin
                pc <= pc + 4;
        end
end

always @(posedge clk) begin
        if (rst) begin
                IF_to_ID_reg <= {1'b0, 32'b0, 32'h1bfffffc};
        end
        else begin
                IF_to_ID_reg <= {predict, inst, pc_reg};
        end
end

endmodule
