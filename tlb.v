module tlb
#(
parameter TLBNUM = 16
)
(
input clk,
// search port 0 (for fetch)
input  [              18:0] s0_vppn,//虚双页号
input                       s0_va_bit12,
input  [               9:0] s0_asid,//地址空间标识
output                      s0_found,
output [$clog2(TLBNUM)-1:0] s0_index,
output [              19:0] s0_ppn,//物理页号
output [               5:0] s0_ps,//页大小
output [               1:0] s0_plv,//特权等级
output [               1:0] s0_mat,//存储访问类型
output                      s0_d,
output                      s0_v,
// search port 1 (for load/store)
input  [              18:0] s1_vppn,
input                       s1_va_bit12,
input  [               9:0] s1_asid,
output                      s1_found,
output [$clog2(TLBNUM)-1:0] s1_index,
output [              19:0] s1_ppn,
output [               5:0] s1_ps,
output [               1:0] s1_plv,
output [               1:0] s1_mat,
output                      s1_d,
output                      s1_v,
// invtlb opcode
input  [               4:0] invtlb_op,
input                       inst_invtlb,
// write port
input                       we, //w(rite) e(nable)
input  [$clog2(TLBNUM)-1:0] w_index,
input                       w_e,//存在位
input  [              18:0] w_vppn,
input  [               5:0] w_ps,
input  [               9:0] w_asid,
input                       w_g,//全局标识位
input  [              19:0] w_ppn0,
input  [               1:0] w_plv0,
input  [               1:0] w_mat0,
input                       w_d0,
input                       w_v0,
input  [              19:0] w_ppn1,
input  [               1:0] w_plv1,
input  [               1:0] w_mat1,
input                       w_d1,
input                       w_v1,
// read port
input  [$clog2(TLBNUM)-1:0] r_index,
output                      r_e,
output [              18:0] r_vppn,
output [               5:0] r_ps,
output [               9:0] r_asid,
output                      r_g,
output [              19:0] r_ppn0,
output [               1:0] r_plv0,
output [               1:0] r_mat0,
output                      r_d0,
output                      r_v0,
output [              19:0] r_ppn1,
output [               1:0] r_plv1,
output [               1:0] r_mat1,
output                      r_d1,
output                      r_v1
);
reg [TLBNUM-1:0] tlb_e;
reg [TLBNUM-1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
reg [ 18     :0] tlb_vppn   [TLBNUM-1:0];
reg [ 9      :0] tlb_asid   [TLBNUM-1:0];
reg              tlb_g      [TLBNUM-1:0];
reg [ 19     :0] tlb_ppn0   [TLBNUM-1:0];
reg [ 1      :0] tlb_plv0   [TLBNUM-1:0];
reg [ 1      :0] tlb_mat0   [TLBNUM-1:0];
reg              tlb_d0     [TLBNUM-1:0];
reg              tlb_v0     [TLBNUM-1:0];
reg [ 19     :0] tlb_ppn1   [TLBNUM-1:0];
reg [ 1      :0] tlb_plv1   [TLBNUM-1:0];
reg [ 1      :0] tlb_mat1   [TLBNUM-1:0];
reg              tlb_d1     [TLBNUM-1:0];
reg              tlb_v1     [TLBNUM-1:0];

wire      [15:0] match0;
wire      [15:0] match1;
wire             cond1      [TLBNUM-1:0];
wire             cond2      [TLBNUM-1:0];
wire             cond3      [TLBNUM-1:0];
wire             cond4      [TLBNUM-1:0];
wire             inv_match  [TLBNUM-1:0];  

genvar i;
    generate 
        for (i = 0; i < TLBNUM; i = i + 1)
        begin: tlb_match
            assign match0[i] = (s0_vppn[18:10] == tlb_vppn[i][18:10]) 
               && (tlb_ps4MB[i] || s0_vppn[9:0] == tlb_vppn[i][9:0])
               && (s0_asid == tlb_asid[i] || tlb_g[i]);

            assign match1[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) 
               && (tlb_ps4MB[i] || s1_vppn[9:0] == tlb_vppn[i][ 9: 0])
               && (s1_asid == tlb_asid[i] || tlb_g[i]);

            assign cond1[i] = tlb_g[i] == 0;
            assign cond2[i] = tlb_g[i] == 1;
            assign cond3[i] = tlb_asid[i] == s1_asid;
            assign cond4[i] = (s1_vppn[18:10] == tlb_vppn[i][18:10])
                           && (tlb_ps4MB[i] || s1_vppn[9:0]==tlb_vppn[i][9:0]);

            assign inv_match[i] = (invtlb_op == 0 || invtlb_op == 1) & (cond1[i] || cond2[i]) |
							      (invtlb_op == 2)                   & cond2[i]               |
							      (invtlb_op == 3)                   & cond1[i]               |
							      (invtlb_op == 4)                   & (cond1[i] && cond3[i]) |
							      (invtlb_op == 5)       & (cond1[i] && cond3[i] && cond4[i]) |
							      (invtlb_op == 6)                   & match1[i];
            
                                          
            always @(posedge clk )begin
                if (we && w_index == i) begin
                    tlb_e    [i] <= w_e;
                    tlb_ps4MB[i] <= (w_ps == 6'd22);
                    tlb_vppn [i] <= w_vppn;
                    tlb_asid [i] <= w_asid;
                    tlb_g    [i] <= w_g;                    
                    tlb_ppn0 [i] <= w_ppn0;
                    tlb_plv0 [i] <= w_plv0;
                    tlb_mat0 [i] <= w_mat0;
                    tlb_d0   [i] <= w_d0;
                    tlb_v0   [i] <= w_v0;                    
                    tlb_ppn1 [i] <= w_ppn1;
                    tlb_plv1 [i] <= w_plv1;
                    tlb_mat1 [i] <= w_mat1;
                    tlb_d1   [i] <= w_d1;
                    tlb_v1   [i] <= w_v1;
                end
                else if (inv_match[i] & inst_invtlb) begin
                    tlb_e    [i] <= 1'b0;
                end
            end
       end 
    endgenerate                

/* -------------------  search port 0 ------------------- */
assign s0_found = (match0 != 16'd0);
assign s0_index = {4{match0[ 0]}} & 4'd0 
                | {4{match0[ 1]}} & 4'd1
                | {4{match0[ 2]}} & 4'd2
                | {4{match0[ 3]}} & 4'd3
                | {4{match0[ 4]}} & 4'd4
                | {4{match0[ 5]}} & 4'd5
                | {4{match0[ 6]}} & 4'd6
                | {4{match0[ 7]}} & 4'd7
                | {4{match0[ 8]}} & 4'd8
                | {4{match0[ 9]}} & 4'd9
                | {4{match0[10]}} & 4'd10
                | {4{match0[11]}} & 4'd11
                | {4{match0[12]}} & 4'd12
                | {4{match0[13]}} & 4'd13
                | {4{match0[14]}} & 4'd14
                | {4{match0[15]}} & 4'd15;
wire   s0_odd   = tlb_ps4MB[s0_index] ? s0_vppn[9] : s0_va_bit12;
assign s0_ppn   = s0_odd ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
assign s0_ps    = {6{tlb_ps4MB[s0_index]}} & 6'd22
                | {6{~tlb_ps4MB[s0_index]}} & 6'd12;
assign s0_plv   = {2{s0_odd}} & tlb_plv1[s0_index] 
                | {2{~s0_odd}} & tlb_plv0[s0_index];
assign s0_mat   = {2{s0_odd}} & tlb_mat1[s0_index] 
                | {2{~s0_odd}} & tlb_mat0[s0_index];
assign s0_d     = s0_odd & tlb_d1[s0_index] 
                | ~s0_odd & tlb_d0[s0_index];
assign s0_v     = s0_odd & tlb_v1[s0_index] 
                | ~s0_odd & tlb_v0[s0_index];

/* -------------------  search port 1 ------------------- */
assign s1_found = (match1 != 16'b0);
assign s1_index = {4{match1[ 0]}} & 4'd0 
                | {4{match1[ 1]}} & 4'd1
                | {4{match1[ 2]}} & 4'd2
                | {4{match1[ 3]}} & 4'd3
                | {4{match1[ 4]}} & 4'd4
                | {4{match1[ 5]}} & 4'd5
                | {4{match1[ 6]}} & 4'd6
                | {4{match1[ 7]}} & 4'd7
                | {4{match1[ 8]}} & 4'd8
                | {4{match1[ 9]}} & 4'd9
                | {4{match1[10]}} & 4'd10
                | {4{match1[11]}} & 4'd11
                | {4{match1[12]}} & 4'd12
                | {4{match1[13]}} & 4'd13
                | {4{match1[14]}} & 4'd14
                | {4{match1[15]}} & 4'd15;
wire   s1_odd   = tlb_ps4MB[s1_index] ? s1_vppn[9] : s1_va_bit12;
assign s1_ppn   = s1_odd ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
assign s1_ps    = {6{tlb_ps4MB[s1_index]}} & 6'd22
                | {6{~tlb_ps4MB[s1_index]}} & 6'd12;
assign s1_plv   = {2{s1_odd}} & tlb_plv1[s1_index] 
                | {2{~s1_odd}} & tlb_plv0[s1_index];
assign s1_mat   = {2{s1_odd}} & tlb_mat1[s1_index] 
                | {2{~s1_odd}} & tlb_mat0[s1_index];
assign s1_d     = s1_odd & tlb_d1[s1_index] 
                | ~s1_odd & tlb_d0[s1_index];
assign s1_v     = s1_odd & tlb_v1[s1_index] 
                | ~s1_odd & tlb_v0[s1_index];

/* -------------------  read port  ------------------- */
assign r_e      = tlb_e[r_index]; 
assign r_vppn   = tlb_vppn[r_index];
assign r_ps     = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
assign r_asid   = tlb_asid[r_index];
assign r_g      = tlb_g[r_index];
assign r_ppn0   = tlb_ppn0[r_index];
assign r_plv0   = tlb_plv0[r_index];
assign r_mat0   = tlb_mat0[r_index];
assign r_d0     = tlb_d0[r_index];
assign r_v0     = tlb_v0[r_index];
assign r_ppn1   = tlb_ppn1[r_index];
assign r_plv1   = tlb_plv1[r_index];
assign r_mat1   = tlb_mat1[r_index];
assign r_d1     = tlb_d1[r_index];
assign r_v1     = tlb_v1[r_index];

endmodule