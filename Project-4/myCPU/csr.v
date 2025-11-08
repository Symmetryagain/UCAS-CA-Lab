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
`define CSR_TID     14'h40
`define CSR_TCFG    14'h41
`define CSR_TVAL   14'h42
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

`define CSR_ECFG_LIE    12:0
`define CSR_ESTAT_IS10  1:0

`define CSR_TCFG_EN     0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV  31:2
`define CSR_TID_TID     31:0

`define ECODE_ADE       6'h08   
`define ECODE_ALE       6'h09 
`define ESUBCODE_ADEF   9'b00

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
        input  wire  [31:0]     wb_vaddr,
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

  
reg  [25: 0] csr_eentry_va;  

reg  [31: 0] csr_save0_data;
reg  [31: 0] csr_save1_data;
reg  [31: 0] csr_save2_data;
reg  [31: 0] csr_save3_data;

wire [ 7: 0] hw_int_in;
wire         ipi_int_in;
reg  [31: 0] timer_cnt;

reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [29:0]  csr_tcfg_initval;
wire [31:0]  tcfg_next_value;
wire [31:0]  csr_tval;

reg  [12:0]  csr_ecfg_lie;
reg  [31:0]  csr_badv_vaddr;
reg  [31:0]  csr_tid_tid;
wire         wb_ex_addr_err;
wire         csr_ticlr_clr;
wire [31:0]  csr_ecfg_data;
wire [31:0]  csr_tcfg_data;
wire [31:0]  csr_ticlr_data;

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

// ECFG
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]
                    | ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;;
 end
assign csr_ecfg_data  = {19'b0, csr_ecfg_lie};

// BADV
assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
 always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err)
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
                           wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
 end

// TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= 32'b0;
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid  <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                     | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
 end

// TCFG
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                    | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                            | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
                            | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
    end
 end
assign csr_tcfg_data = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
// TVAL
assign tcfg_next_value =  csr_wmask[31:0]&csr_wvalue[31:0]
                       | ~csr_wmask[31:0]&{csr_tcfg_initval,
                                           csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

// TICLR
assign csr_ticlr_clr = 1'b0;
assign csr_ticlr_data = {31'b0, csr_ticlr_clr};

assign csr_rvalue =     {32{csr_num == `CSR_CRMD  }} & csr_crmd_data
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_data
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_data
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_data
                      | {32{csr_num == `CSR_ERA   }} & csr_era_pc
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_data
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data
                      | {32{csr_num == `CSR_BADV  }} & csr_badv_vaddr
                      | {32{csr_num == `CSR_TID   }} & csr_tid_tid
                      | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_data
                      | {32{csr_num == `CSR_TVAL  }} & csr_tval
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_data;

endmodule

