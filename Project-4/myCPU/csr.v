`define CSR_CRMD    14'h00
`define CSR_PRMD    14'h01
`define CSR_EUEN    14'h02
`define CSR_ECFG    14'h04
`define CSR_ESTAT   14'h05
`define CSR_ERA     14'h06
`define CSR_BADV    14'h07
`define CSR_EENTRY  14'h0c
`define CSR_SAVE0   14'h30
`define CSR_SAVE1   14'h31
`define CSR_SAVE2   14'h32
`define CSR_SAVE3   14'h33
`define CSR_TICLR   14'h44


`define CSR_CRMD_PLV    1:0
`define CSR_CRMD_PIE    2

`define CSR_PRMD_PPLV   1:0
`define CSR_PRMD_PIE    2

`define CSR_ESTAT_IS10  1:0
`define CSR_ERA_PC      31:0
`define CSR_EENTRY_VA   31:6
`define CSR_SAVE_DATA   31:0
`define CSR_TICLR_CLR   0


module csr(
        input   wire            clk,
        input   wire            reset,
        input   wire            csr_re,
        input   wire [13:0]     csr_num,
        output  wire [31:0]     csr_rvalue,
        input   wire            csr_we,
        input   wire [31:0]     csr_wmask,
        input   wire [31:0]     csr_wvalue,

        input  wire             ertn_flush,
        input  wire             wb_ex,  
        input  wire  [31:0]     wb_pc,
        input  wire  [ 5:0]     wb_ecode,  
        input  wire  [ 8:0]     wb_esubcode,
        output wire  [31:0]     csr_eentry_data,
        output reg   [31:0]     csr_era_pc
);

wire [31: 0] csr_crmd_data;
reg  [ 1: 0] csr_crmd_plv;      
reg          csr_crmd_ie;       
wire         csr_crmd_da;       
wire         csr_crmd_pg;
wire [ 6: 5] csr_crmd_datf;
wire [ 8: 7] csr_crmd_datm;

wire [31: 0] csr_prmd_data;
reg  [ 1: 0] csr_prmd_pplv;     
reg          csr_prmd_pie; 

wire [31: 0] csr_estat_data;    
reg  [12: 0] csr_estat_is;      
reg  [ 5: 0] csr_estat_ecode;   
reg  [ 8: 0] csr_estat_esubcode;

// reg  [31: 0] csr_era_pc;  
// wire [31: 0] csr_eentry_data;   
reg  [25: 0] csr_eentry_va;  

reg  [31: 0] csr_save0_data;
reg  [31: 0] csr_save1_data;
reg  [31: 0] csr_save2_data;
reg  [31: 0] csr_save3_data;

wire [ 7: 0] hw_int_in;
wire         ipi_int_in;
reg  [31: 0] timer_cnt;

assign hw_int_in = 8'b0;
assign ipi_int_in= 1'b0;
always @(posedge clk) begin
    if (reset) begin
        timer_cnt <= 32'hffffffff;
    end
    else begin
        timer_cnt <= timer_cnt - 1'b1;
    end
end

// CRMD
always @(posedge clk) begin
    if (reset)
        csr_crmd_plv <= 2'b0;
    else if (wb_ex)
        csr_crmd_plv <= 2'b0;
    else if (ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
 end

always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_ex)
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]
                    | ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
 end

assign csr_crmd_da   = 1'b1; 
assign csr_crmd_pg   = 1'b0; 
assign csr_crmd_datf = 2'b00; 
assign csr_crmd_datm = 2'b00;
assign csr_crmd_data = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

// PRMD
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
 end
assign csr_prmd_data  = {29'b0, csr_prmd_pie, csr_prmd_pplv};

// ESTAT
always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <=  csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[10] <= 1'b0;
    if (timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
             && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= ipi_int_in;
 end

always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
 end
assign csr_estat_data = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};

// ERA
always @(posedge clk) begin
    if (wb_ex)
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                    | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
end

// EENTRY
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                       | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
 end
assign csr_eentry_data= {csr_eentry_va, 6'b0};

// SAVE0～3
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
 end

assign csr_rvalue =     {32{csr_num == `CSR_CRMD  }} & csr_crmd_data
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_data
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_data
                      | {32{csr_num == `CSR_ERA   }} & csr_era_pc
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_data
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data;

endmodule

