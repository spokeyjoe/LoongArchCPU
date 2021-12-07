`include "mycpu.h"

module exe_stage#(
    parameter TLBNUM = 16
)
(
    input                          clk           ,
    input                          reset         ,
    input                          final_ex      ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
  //  output                         es_valid      ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output                         data_sram_req  ,
    output                         data_sram_wr   ,
    output [                  3:0] data_sram_wstrb,
    output [                 31:0] data_sram_addr ,
    output [                 31:0] data_sram_wdata,
    output [                  1:0] data_sram_size ,
    input                          data_sram_addr_ok,
    output [`ES_FORWARD_WD   -1:0] es_forward     ,
    // counter
    input  [                 63:0] es_counter     ,
    input                          ms_ertn_flush  ,
    input                          ms_to_es_valid ,
    input                          back_ertn_flush,
    input                          back_ex        ,
    input                          ms_to_es_ex    ,
    output                         es_ex_detected_to_fs,
    // search port 1 (for load/store)
    output [              18:0] s1_vppn,
    output                      s1_va_bit12,
    output [               9:0] s1_asid,
    input                       s1_found,
//    input  [$clog2(TLBNUM)-1:0] s1_index,
    input  [              19:0] s1_ppn,
    input  [               5:0] s1_ps,
    input  [               1:0] s1_plv,
    input  [               1:0] s1_mat,
    input                       s1_d,
    input                       s1_v,
    // invtlb opcode
    output [               4:0] invtlb_op,
    output                      inst_tlbsrch,
    output                      inst_tlbrd,
    output                      inst_tlbwr,
    output                      inst_tlbfill,
    output                      inst_invtlb,
    input  [`WS_TO_ES_BUS_WD -1:0] ws_to_es_bus
);

/* --------------  Handshaking signals -------------- */

reg         es_valid      ;
wire        es_ready_go   ;

assign      invtlb_op = invop;

/* -------------------  BUS ------------------- */
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;



/*-------------------- Address translation --------------------*/
wire [31:0] badvaddr;
wire [31:0] vaddr;
wire [31:0] paddr;
wire [19:0] vpn         = vaddr[31:12];
wire [21:0] offset      = vaddr[21:0];

wire dmw_hit = dmw0_hit || dmw1_hit;
wire dmw0_hit;
wire dmw1_hit;
wire [31:0] dmw_addr;
wire [31:0] tlb_addr;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbehi_rvalue;



wire csr_crmd_da = csr_crmd_rvalue[`CSR_CRMD_DA];
wire csr_crmd_pg = csr_crmd_rvalue[`CSR_CRMD_PG];
wire [1:0] csr_crmd_plv = csr_crmd_rvalue[`CSR_CRMD_PLV];
wire csr_dmw0_plv0 = csr_dmw0_rvalue[`CSR_DMW_PLV0];
wire csr_dmw0_plv3 = csr_dmw0_rvalue[`CSR_DMW_PLV3];
wire [2:0] csr_dmw0_vseg = csr_dmw0_rvalue[`CSR_DMW_VSEG];
wire [2:0] csr_dmw0_pseg = csr_dmw0_rvalue[`CSR_DMW_PSEG];
wire csr_dmw1_plv0 = csr_dmw1_rvalue[`CSR_DMW_PLV0];
wire csr_dmw1_plv3 = csr_dmw1_rvalue[`CSR_DMW_PLV3];
wire [2:0] csr_dmw1_vseg = csr_dmw1_rvalue[`CSR_DMW_VSEG];
wire [2:0] csr_dmw1_pseg = csr_dmw1_rvalue[`CSR_DMW_PSEG];
wire [9:0] csr_asid_asid = csr_asid_rvalue[`CSR_ASID_ASID];

/* --------------  MEM write interface  -------------- */

// Add in Lab 7 
wire        es_op_ld_w    ;
wire        es_op_ld_b    ;
wire        es_op_ld_bu   ;
wire        es_op_ld_h    ;
wire        es_op_ld_hu   ;
wire        es_op_st_b    ;
wire        es_op_st_h    ;
wire        es_op_st_w    ;
wire        es_res_from_mem;
wire        es_op_mem = es_op_ld_w ||es_op_ld_b || es_op_ld_bu || es_op_ld_h || es_op_ld_hu || es_op_st_b || es_op_st_h || es_op_st_w;

wire        es_addr00;
wire        es_addr01;
wire        es_addr10;
wire        es_addr11;

wire [3:0] data_sram_wstrb_sp;



/* --------------  ALU  -------------- */

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire        alu_ready_go  ;
wire [18:0] es_alu_op     ; 
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;

wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;

alu u_alu(
    .clk        (clk          ),
    .reset      (reset        ),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .div_ready_go (alu_ready_go)
    );

    //{19{es_valid}}    

/* --------------  Counter  -------------- */

wire [ 2:0] es_rdcnt;

wire        es_inst_rdcntid;
wire        es_inst_rdcntvh_w;
wire        es_inst_rdcntvl_w;

wire [31:0] es_cnt_result;
wire [31:0] es_final_result;




/* ------------------- Exceptions ------------------- */

wire        ds_ex;
wire [ 5:0] ds_ecode;
wire        ds_esubcode;

wire        es_ex;
wire        es_ertn_flush;
wire        es_esubcode;
wire [ 5:0] es_ecode;

wire        ale_ex;

reg         es_ex_detected_unsolved;
wire        es_tlb_refetch;
wire        fs_tlb_refill_ex;
wire        es_tlb_refill_ex;
wire        es_tlb_load_invalid_ex;
wire        es_tlb_store_invalid_ex;
wire        es_tlb_modify_ex;
wire        es_tlb_ppe_ex;
wire        es_adem_ex;
/* ------------------- CSR related ------------------- */

wire        es_csr_block;

wire [13:0] es_csr_num;
wire        es_csr_re;
wire [31:0] es_csr_wmask; 
wire [31:0] es_csr_wvalue;
wire        es_csr_we;



assign es_csr_block = es_valid & es_csr_re;

wire [ 4:0] invop;

/* --------------  Handshaking signals -------------- */

assign es_ready_go    = ~es_op_mem ? alu_ready_go : alu_ready_go && (data_sram_req && data_sram_addr_ok) || 
                    (ale_ex | es_tlb_load_invalid_ex | es_tlb_store_invalid_ex | es_tlb_modify_ex | es_tlb_ppe_ex | es_adem_ex); 
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;//!!!

always @(posedge clk) begin
    if (reset | final_ex | back_ertn_flush) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end
end

/* -------------------  BUS ------------------- */

always @(posedge clk) begin
    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end


assign {fs_tlb_refill_ex, //268
        invop          ,  //267:263
        es_tlb_refetch ,  //262
        inst_tlbsrch   ,  //261
        inst_tlbrd     ,  //260
        inst_tlbwr     ,  //259
        inst_tlbfill   ,  //258
        inst_invtlb    ,  //257
        es_rdcnt       ,  //256:254
        es_ertn_flush  ,  //253
        ds_esubcode    ,  //252
        ds_ecode       ,  //251:246
        ds_ex          }  //245
        = ds_to_es_bus_r[268:245];
        
// When INE happens at ID stage, these signals are invalid
assign {es_csr_re      ,  //244
        es_csr_num     ,  //243:230
        es_csr_wvalue  ,  //229:198
        es_csr_wmask   ,  //197:166
        es_csr_we      ,  //165
        es_op_st_w     ,  //164
        es_op_ld_w     ,  //163
        es_op_ld_b     ,  //162
        es_op_ld_bu    ,  //161
        es_op_ld_h     ,  //160
        es_op_ld_hu    ,  //159
        es_op_st_b     ,  //158
        es_op_st_h     ,  //157
        es_alu_op      ,  //156:138
        es_res_from_mem,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   }  //63 :32
        = ds_to_es_bus_r[244:32] & {213{~(ds_ecode == `ECODE_INE)}};

assign  es_pc             //31 :0
        = ds_to_es_bus_r[31:0];

// ES to MS bus
assign es_to_ms_bus = {badvaddr       ,  //210:179
                       es_mem_ex      ,  //178
                       es_tlb_refill_ex, //177
                       es_tlb_refetch ,  //176
                       inst_tlbsrch   ,  //175
                       inst_tlbrd     ,  //174
                       inst_tlbwr     ,  //173
                       inst_tlbfill   ,  //172
                       inst_invtlb    ,  //171
                       es_op_st_w     ,  //170
                       es_inst_rdcntid,  //169
                       es_ertn_flush  ,  //168
                       es_esubcode    ,  //167
                       es_ecode       ,  //166:161
                       es_ex&es_valid ,  //160
                       es_csr_re      ,  //159
                       es_csr_num     ,  //158:145
                       es_csr_wvalue  ,  //144:113
                       es_csr_wmask   ,  //112:81
                       es_csr_we      ,  //80
                       data_sram_addr[1:0], //79:78
                       es_op_ld_w     ,  //77
                       es_op_ld_b     ,  //76
                       es_op_ld_bu    ,  //75
                       es_op_ld_h     ,  //74
                       es_op_ld_hu    ,  //73
                       es_op_st_b     ,  //72
                       es_op_st_h     ,  //71
                       es_res_from_mem & ~ale_ex,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_final_result  ,  //63:32
                       es_pc             //31:0
                      };


// ES forward bus
assign es_forward      = {es_csr_block,
                          es_csr_re, //57
                          es_csr_num, //56:43
                          es_csr_we, //42
                          es_ertn_flush, //41
                          es_ex, //40
                          es_res_from_mem,//39
                          es_alu_result,//38:7
                          es_dest , //6:2
                          es_gr_we, //1:1
                          es_valid  //0:0
                         };

assign {csr_crmd_rvalue, //159:128
        csr_dmw0_rvalue, //127:96
        csr_dmw1_rvalue, //95:64
        csr_asid_rvalue, //63:32
        csr_tlbehi_rvalue//31:0
       } = ws_to_es_bus;


/* --------------  MEM write interface  -------------- */

assign data_sram_req    = (es_res_from_mem || es_mem_we) && es_valid 
                      && ~back_ertn_flush && ~(ms_ertn_flush && ms_to_es_valid) && ~(ale_ex | es_tlb_load_invalid_ex | es_tlb_store_invalid_ex | es_tlb_modify_ex | es_tlb_ppe_ex | es_adem_ex)
                      && ms_allowin;

assign data_sram_size  = {2{es_op_st_b || es_op_ld_b || es_op_ld_bu}} & 2'b00 |
                         {2{es_op_st_h || es_op_ld_h || es_op_ld_hu}} & 2'b01 |
                         {2{es_op_st_w || es_op_ld_w}}                & 2'b10;


// Change in Lab 7
assign es_addr00 = data_sram_addr[1:0] == 2'b00;
assign es_addr01 = data_sram_addr[1:0] == 2'b01;
assign es_addr10 = data_sram_addr[1:0] == 2'b10;
assign es_addr11 = data_sram_addr[1:0] == 2'b11;
assign data_sram_wstrb_sp= {4{es_op_st_b && es_addr00}} & 4'b0001 |
                         {4{es_op_st_b && es_addr01}} & 4'b0010 |
                         {4{es_op_st_b && es_addr10}} & 4'b0100 |
                         {4{es_op_st_b && es_addr11}} & 4'b1000 |
                         {4{es_op_st_h && es_addr00}} & 4'b0011 |
                         {4{es_op_st_h && es_addr10}} & 4'b1100 |
                         {4{es_op_st_w}}              & 4'b1111;

assign data_sram_wstrb = es_mem_we & ~ale_ex ? data_sram_wstrb_sp : 4'h0;
assign data_sram_addr  = paddr;
assign data_sram_wdata = {32{es_op_st_b}} & {4{es_rkd_value[ 7:0]}} |
                         {32{es_op_st_h}} & {2{es_rkd_value[15:0]}} |
                         {32{es_op_st_w}} & es_rkd_value[31:0];
assign data_sram_wr    = (|data_sram_wstrb) & ~es_tlb_refetch;

/* --------------  ALU  -------------- */

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : es_rj_value;         
assign es_alu_src2 = es_src2_is_imm ? es_imm : es_rkd_value;



/* --------------  Counter  -------------- */

assign es_inst_rdcntid   = es_rdcnt[2];
assign es_inst_rdcntvh_w = es_rdcnt[1];
assign es_inst_rdcntvl_w = es_rdcnt[0];

assign es_cnt_result   = es_inst_rdcntid | es_inst_rdcntvh_w ? es_counter[63:32] : es_counter[31:0];


assign es_final_result = es_inst_rdcntvh_w | es_inst_rdcntvl_w ? es_cnt_result : es_alu_result;



/* ------------------- Exceptions ------------------- */

assign es_esubcode = es_adem_ex ? 1'b1 : ds_esubcode;
assign es_ex = ale_ex | es_tlb_load_invalid_ex | es_tlb_store_invalid_ex | es_tlb_modify_ex | es_tlb_ppe_ex | es_adem_ex | ds_ex | es_tlb_refill_ex;
assign es_ecode = ale_ex ? `ECODE_ALE : 
                  es_tlb_refill_ex ? `ECODE_TLBR :
                  es_tlb_load_invalid_ex ? `ECODE_PIL :
                  es_tlb_store_invalid_ex ? `ECODE_PIS : 
                  es_tlb_modify_ex ? `ECODE_PME :
                  es_tlb_ppe_ex ? `ECODE_PPE :
                  es_adem_ex ? `ECODE_ADE : 
                  ds_ecode;

// Add in Lab 9
// ALE exception
assign ale_ex = (es_op_ld_h || es_op_ld_hu || es_op_st_h) && data_sram_addr[0]             ||
                (es_op_ld_w || es_op_st_w               ) && (data_sram_addr[1:0] != 2'b00);


always @(posedge clk) begin
    if (reset)
        es_ex_detected_unsolved <= 1'b0;
    else if (ms_to_es_ex)
        es_ex_detected_unsolved <= 1'b0;
    else if ((ale_ex | es_tlb_load_invalid_ex | es_tlb_store_invalid_ex | es_tlb_modify_ex | es_tlb_ppe_ex | es_adem_ex) && ~final_ex)
        es_ex_detected_unsolved <= 1'b1;
    else
        es_ex_detected_unsolved <= 1'b0;
end

assign es_ex_detected_to_fs = es_ex_detected_unsolved;

/*-------------------- Address translation --------------------*/
assign vaddr = es_alu_result;

// TLB

assign s1_vppn     = inst_invtlb ? es_rkd_value[31:13] :
                     inst_tlbsrch ? csr_tlbehi_rvalue[31:13] :
                     vpn[19:1];
assign s1_asid     = inst_invtlb ? es_rj_value[9:0]   : csr_asid_rvalue[9:0];
assign s1_va_bit12 = inst_invtlb ? es_rkd_value[12]: 
                     inst_tlbsrch ? 1'b0 : vpn[0]; 

assign tlb_addr = (s1_ps == 6'd12) ? {s1_ppn[19:0], offset[11:0]} :
                                     {s1_ppn[19:10], offset[21:0]};

assign da_hit = (csr_crmd_da == 1) && (csr_crmd_pg == 0);

// DMW
assign dmw0_hit = (csr_crmd_plv == 2'b00 && csr_dmw0_plv0   ||
                   csr_crmd_plv == 2'b11 && csr_dmw0_plv3 ) && (vaddr[31:29] == csr_dmw0_vseg); 
assign dmw1_hit = (csr_crmd_plv == 2'b00 && csr_dmw1_plv0   ||
                   csr_crmd_plv == 2'b11 && csr_dmw1_plv3 ) && (vaddr[31:29] == csr_dmw1_vseg); 

assign dmw_addr = {32{dmw0_hit}} & {csr_dmw0_pseg, vaddr[28:0]} |
                  {32{dmw1_hit}} & {csr_dmw1_pseg, vaddr[28:0]};

// PADDR
assign paddr = da_hit  ? vaddr    :
               dmw_hit ? dmw_addr :
                         tlb_addr;
assign es_tlb_refill_ex        = ~da_hit & ~dmw_hit & (es_mem_we | es_res_from_mem) & ~s1_found | fs_tlb_refill_ex;
assign es_tlb_load_invalid_ex  = ~da_hit & ~dmw_hit & es_res_from_mem & s1_found & ~s1_v;
assign es_tlb_store_invalid_ex = ~da_hit & ~dmw_hit & es_mem_we & s1_found & ~s1_v;
assign es_tlb_modify_ex        = ~da_hit & ~dmw_hit & es_mem_we & s1_found & s1_v & ~es_tlb_ppe_ex & ~s1_d;
assign es_tlb_ppe_ex           = ~da_hit & ~dmw_hit & (es_mem_we | es_res_from_mem) & s1_found & s1_v & csr_crmd_plv == 2'b11 && s1_plv == 2'b00;            
assign es_adem_ex              = ~da_hit & ~dmw_hit & (es_mem_we | es_res_from_mem) & csr_crmd_plv == 2'b11 & vaddr[31];

wire   es_mem_ex               = ~da_hit & ~dmw_hit & (es_mem_we | es_res_from_mem) & ~s1_found ||
                                 es_tlb_load_invalid_ex                                         ||
                                 es_tlb_store_invalid_ex                                        ||
                                 es_tlb_modify_ex                                               ||
                                 es_tlb_ppe_ex                                                  ||
                                 es_adem_ex                                                     ||
                                 ale_ex;

assign badvaddr                = ds_ex ? es_pc : es_alu_result;
endmodule
