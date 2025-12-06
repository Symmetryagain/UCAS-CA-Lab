module tlb #(
        parameter TLBNUM = 16
) (
        input                   clk,
        // search port 0 (for fetch)
        input   [ 18:0]         s0_vppn,
        input                   s0_va_bit12,
        input   [ 9:0]          s0_asid,
        output                  s0_found,
        output  [$clog2(TLBNUM)-1:0]    s0_index,
        output  [ 19:0]         s0_ppn,
        output  [ 5:0]          s0_ps,
        output  [ 1:0]          s0_plv,
        output  [ 1:0]          s0_mat,
        output                  s0_d,
        output                  s0_v,
        // search port 1 (for load/store)
        input   [ 18:0]         s1_vppn,
        input                   s1_va_bit12,
        input   [ 9:0]          s1_asid,
        output                  s1_found,
        output  [$clog2(TLBNUM)-1:0]    s1_index,
        output  [ 19:0]         s1_ppn,
        output  [ 5:0]          s1_ps,
        output  [ 1:0]          s1_plv,
        output  [ 1:0]          s1_mat,
        output                  s1_d,
        output                  s1_v,
        // invtlb opcode
        input                   invtlb_valid,    
        input   [ 4:0]          invtlb_op,
        // write port
        input                   we, //w(rite) e(nable)
        input   [$clog2(TLBNUM)-1:0]    w_index,
        input                   w_e,
        input   [ 18:0]         w_vppn,
        input   [ 5:0]          w_ps,
        input   [ 9:0]          w_asid,
        input                   w_g,
        input   [ 19:0]         w_ppn0,
        input   [ 1:0]          w_plv0,
        input   [ 1:0]          w_mat0,
        input                   w_d0,
        input                   w_v0,
        input   [ 19:0]         w_ppn1,
        input   [ 1:0]          w_plv1,
        input   [ 1:0]          w_mat1,
        input                   w_d1,
        input                   w_v1,
        // read port
        input   [$clog2(TLBNUM)-1:0]    r_index,
        output                  r_e,
        output  [ 18:0]         r_vppn,
        output  [ 5:0]          r_ps,
        output  [ 9:0]          r_asid,
        output                  r_g,
        output  [ 19:0]         r_ppn0,
        output  [ 1:0]          r_plv0,
        output  [ 1:0]          r_mat0,
        output                  r_d0,
        output                  r_v0,
        output  [ 19:0]         r_ppn1,
        output  [ 1:0]          r_plv1,
        output  [ 1:0]          r_mat1,
        output                  r_d1,
        output                  r_v1
);

reg [TLBNUM-1:0]        tlb_e;
reg [TLBNUM-1:0]        tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg [ 18:0]             tlb_vppn        [TLBNUM-1:0];
reg [ 9:0]              tlb_asid        [TLBNUM-1:0];
reg                     tlb_g           [TLBNUM-1:0];
reg [ 19:0]             tlb_ppn0        [TLBNUM-1:0];
reg [ 1:0]              tlb_plv0        [TLBNUM-1:0];
reg [ 1:0]              tlb_mat0        [TLBNUM-1:0];
reg                     tlb_d0          [TLBNUM-1:0];
reg                     tlb_v0          [TLBNUM-1:0];
reg [ 19:0]             tlb_ppn1        [TLBNUM-1:0];
reg [ 1:0]              tlb_plv1        [TLBNUM-1:0];
reg [ 1:0]              tlb_mat1        [TLBNUM-1:0];
reg                     tlb_d1          [TLBNUM-1:0];
reg                     tlb_v1          [TLBNUM-1:0];



endmodule