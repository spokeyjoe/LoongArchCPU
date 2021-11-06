`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    input                          final_ex      ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
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
    output [                 58:0] es_forward     ,
    // counter
    input  [                 63:0] es_counter     ,
    input                          ms_ertn_flush  ,
    input                          back_ertn_flush,
    input                          back_ex
);

/* --------------  Handshaking signals -------------- */

reg         es_valid      ;
wire        es_ready_go   ;



/* -------------------  BUS ------------------- */
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;




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
    .alu_op     (es_alu_op & {19{es_valid}}    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .div_ready_go (alu_ready_go)
    );





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




/* ------------------- CSR related ------------------- */

wire        es_csr_block;

wire [13:0] es_csr_num;
wire        es_csr_re;
wire [31:0] es_csr_wmask; 
wire [31:0] es_csr_wvalue;
wire        es_csr_we;



assign es_csr_block = es_valid & es_csr_re;



/* --------------  Handshaking signals -------------- */

assign es_ready_go    = ~es_op_mem ? alu_ready_go : alu_ready_go && (data_sram_req && data_sram_addr_ok) ; 
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && ~final_ex;//!!!

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


assign {es_rdcnt       ,  //256:254
        es_ertn_flush  ,  //253
        ds_esubcode    ,  //252
        ds_ecode       ,  //251:246
        ds_ex          }  //245
        = ds_to_es_bus_r[256:245];
        
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
assign es_to_ms_bus = {es_op_st_w     ,  //170
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




/* --------------  MEM write interface  -------------- */

assign data_sram_req    = (es_res_from_mem || es_mem_we) && es_valid 
                      && ~back_ertn_flush && ~ms_ertn_flush && ~ale_ex
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

assign data_sram_wstrb   = es_mem_we & ~ale_ex ? data_sram_wstrb_sp : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = {32{es_op_st_b}} & {4{es_rkd_value[ 7:0]}} |
                         {32{es_op_st_h}} & {2{es_rkd_value[15:0]}} |
                         {32{es_op_st_w}} & es_rkd_value[31:0];
assign data_sram_wr    = (|data_sram_wstrb);

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

assign es_esubcode = ds_esubcode;
assign es_ex = ale_ex | ds_ex;
assign es_ecode = ale_ex ? `ECODE_ALE : ds_ecode;

// Add in Lab 9
// ALE exception
assign ale_ex = (es_op_ld_h || es_op_ld_hu || es_op_st_h) && data_sram_addr[0]             ||
                (es_op_ld_w || es_op_st_w               ) && (data_sram_addr[1:0] != 2'b00);




endmodule
