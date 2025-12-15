`include "macros.h"

module mmu(
        input  wire             mem_we, // 0: read, 1: write
        input  wire             mmu_en,
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

        input  wire [31:0]  csr_asid_data,
        input  wire [31:0]  csr_crmd_data,
        input  wire [31:0]  csr_dmw0_data,
        input  wire [31:0]  csr_dmw1_data,

        output wire         except_tlbr,
        output wire         except_pif,
        output wire         except_pis,
        output wire         except_pil,
        output wire         except_pme,
        output wire         except_ppi
);
wire            csr_crmd_da, csr_crmd_pg;
wire  [4:0]     csr_crmd_plv;
wire            direct_translate, direct_map, tlb_map;
wire            hit_dmw0, hit_dmw1;
wire  [31:0]    tlb_paddr;

assign csr_crmd_da   = csr_crmd_data[3];
assign csr_crmd_pg   = csr_crmd_data[4];
assign csr_crmd_plv  = {3'b0, csr_crmd_data[1:0]};

assign direct_translate =  csr_crmd_da & ~csr_crmd_pg;
assign direct_map       = ~csr_crmd_da &  csr_crmd_pg;
assign tlb_map          = direct_map & ~hit_dmw0 & ~hit_dmw1;

assign hit_dmw0 = direct_map && (csr_dmw0_data[31:29] == vaddr[31:29]) && csr_dmw0_data[csr_crmd_plv];
assign hit_dmw1 = direct_map && (csr_dmw1_data[31:29] == vaddr[31:29]) && csr_dmw1_data[csr_crmd_plv];

assign s_vppn     = vaddr[31:13];
assign s_va_bit12 = vaddr[12];
assign s_asid     = csr_asid_data[9:0];

assign tlb_paddr = (s_ps == 6'd12)? {s_ppn[19:0], vaddr[11:0]} :
                   (s_ps == 6'd21)? {s_ppn[19:9], vaddr[20:0]} :
                   32'b0;

assign paddr =  direct_translate? vaddr :
                hit_dmw0 ? {csr_dmw0_data[27:25], vaddr[28:0]} :
                hit_dmw1 ? {csr_dmw1_data[27:25], vaddr[28:0]} :
                tlb_paddr;
                
assign except_tlbr = mmu_en & tlb_map & ~s_found;
assign except_pif  = mmu_en & tlb_map & ~s_v;
assign except_pis  = mmu_en & tlb_map & ~s_v &  mem_we;
assign except_pil  = mmu_en & tlb_map & ~s_v & ~mem_we;
assign except_pme  = mmu_en & tlb_map & ~s_d &  mem_we;
assign except_ppi  = mmu_en & tlb_map & s_found & (csr_crmd_plv[1:0] > s_plv);

endmodule