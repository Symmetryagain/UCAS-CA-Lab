module mmu(

        input  wire [31:0]      vaddr,
        output wire [31:0]      paddr,

        output wire [18:0]      s_vppn,
        output wire             s_va_bit12,
        output wire [9:0]       s_asid,
        input  wire             s_found,
        input  wire [3:0]       s_index,
        input  wire [19:0]      s_ppn,
        input  wire [5:0]       s_ps,
        input  wire [1:0]       s_plv,
        input  wire [1:0]       s_mat,
        input  wire             s_d,
        input  wire             s_v,

        input  wire [31:0]  csr_tlbehi_data,
        input  wire [31:0]  csr_tlbelo0_data,
        input  wire [31:0]  csr_tlbelo1_data,
        input  wire [31:0]  csr_tlbidx_data, 
        input  wire [7:0]   csr_asid_data,
        input  wire [5:0]   csr_crmd_data,
        input  wire         csr_estat_data,

        output wire             except_,
        output wire             except_,
        output wire             except_,
        output wire             except_
        
);
wire    csr_crmd_da, csr_crmd_pg, mode;
assign csr_crmd_da   = csr_crmd_data[3];
assign csr_crmd_pg   = csr_crmd_data[4];
assign s_vppn = vaddr[31:13];
assign s_va_bit12 = vaddr[12];
assign s_asid = csr_asid_data;



assign paddr = (s_found && s_v) ? {s_ppn, vaddr[11:0]} : vaddr;

endmodule