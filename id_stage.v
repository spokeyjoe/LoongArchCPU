`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input  [`ES_FORWARD_WD   -1:0] es_forward,
    input  [`MS_FORWARD_WD   -1:0] ms_forward,
    input  [`WS_FORWARD_WD   -1:0] ws_forward,
    input                          back_ertn_flush,
    input                          back_ex
);

/* --------------  Instruction Decoder -------------- */

wire [18:0] alu_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        src_reg_is_rd;

wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
  
// Instructions
wire        inst_add_w; 
wire        inst_sub_w;  
wire        inst_slt;    
wire        inst_sltu;   
wire        inst_nor;    
wire        inst_and;    
wire        inst_or;     
wire        inst_xor;    
wire        inst_slli_w;  
wire        inst_srli_w;  
wire        inst_srai_w;  
wire        inst_addi_w; 
wire        inst_ld_w;  
wire        inst_st_w;   
wire        inst_jirl;   
wire        inst_b;      
wire        inst_bl;     
wire        inst_beq;    
wire        inst_bne;    
wire        inst_lu12i_w;

// Add in Lab 6
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_mod_w;
wire        inst_div_wu;
wire        inst_mod_wu;

// Add in Lab 7
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu; 
wire        inst_bgeu;
wire        inst_ld_b; 
wire        inst_ld_h; 
wire        inst_ld_bu;
wire        inst_ld_hu; 
wire        inst_st_b; 
wire        inst_st_h;  
wire        inst_mem;

// Add in Lab 8
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;

// Add in Lab 9
wire        inst_break;
wire        inst_rdcntid;
wire        inst_rdcntvh_w;
wire        inst_rdcntvl_w;

// Load/Store signals
// Add in Lab 7
wire        op_ld_w;
wire        op_ld_b;
wire        op_ld_bu;
wire        op_ld_h;
wire        op_ld_hu;
wire        op_st_b;
wire        op_st_h;
wire        op_st_w;

// CSR instruction related signals
wire [13:0] csr_num;
wire        csr_re;
wire [31:0] csr_wmask;  //rj
wire [31:0] csr_wvalue; //rd
wire        csr_we;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;  
wire        src2_is_4;




/* --------------  Adder for comparison -------------- */
// Add in Lab 7
wire        rj_eq_rd;
wire        rj_lt_rd;
wire        rj_ltu_rd;

wire        sign_bit;
wire [31:0] out;
wire        overflow;


/* --------------  Handshaking signals -------------- */

reg         ds_valid   ;
wire        ds_ready_go;
wire        csr_block;



/* ------------------- BUS ------------------- */

// FS to DS bus
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        fs_esubcode;
wire [ 5:0] fs_ecode;  
wire        fs_ex;

// WS to RF bus
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

// ES forward bus
wire        es_ertn_flush;
wire        es_ex;
wire        es_res_from_mem;
wire [31:0] es_alu_result;
wire [13:0] es_csr_num;
wire        es_csr_re;
wire [4:0]  es_dest; 
wire        es_csr_we;
wire        es_gr_we;
wire        es_valid;
wire        es_csr_block;

// MS forward bus
wire        ms_ertn_flush;
wire        ms_ex;
//wire        ms_res_from_mem;
wire [31:0] ms_final_result;
wire [13:0] ms_csr_num;
wire        ms_csr_re;
wire [4:0]  ms_dest; 
wire        ms_csr_we;
wire        ms_gr_we;
wire        ms_valid;
wire        ms_csr_block;

// WS forward bus
wire        has_int;
wire [31:0] ex_era;
wire [31:0] ex_entry;
wire        ws_ertn_flush;
wire        ws_ex;
wire        final_ex;
wire [31:0] ws_final_result;
wire [13:0] ws_csr_num;
wire        ws_csr_re;
wire [ 4:0] ws_dest; 
wire        ws_csr_we;
wire        ws_rf_we;
wire        ws_valid;
wire [ 2:0] ds_rdcnt;  



/* ------------------- Branch ------------------- */

wire        br_taken;
wire [31:0] br_target;



/* ------------------- Exceptions ------------------- */
// Add in Lab 8 & Lab 9

wire        ds_ex;
wire [ 5:0] ds_ecode;
wire        ds_esubcode;

// INE exception
wire        ine_ex;

reg         ex_detected_unsolved;
wire        ex_detected_to_fs;

/* ------------------- Regfile Interface ------------------- */

wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire [4: 0] dest;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
 


/* ------------------- RAW Conflict ------------------- */
wire [31:0] rj_value;
wire [31:0] rkd_value;

wire no_src1;
wire no_src2;

wire [4:0] src1;
wire [4:0] src2;

wire raw1;
wire raw2;
wire raw3;
wire raw4;
wire raw5;
wire raw6;
wire raw;

wire br_stall;
/* ------------------------------------------  ASSIGNMENTS ------------------------------------------ */


/* --------------  Instruction Decoder -------------- */

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

//Add in lab6
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8]; //0000001000
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9]; //0000001001
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd]; //0000001101
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he]; //0000001110
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf]; //0000001111
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e]; //00000000000101110
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f]; //00000000000101111
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10]; //00000000000110000
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25]; //0001110;
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18]; //00000000000111000
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19]; //00000000000111001
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a]; //00000000000111010
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00]; //00000000001000000
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01]; //00000000001000001
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02]; //00000000001000010
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03]; //00000000001000011

// Add in lab7
assign inst_mem    = op_31_26_d[6'h0a];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

// Add in lab8
assign inst_csrrd  = op_31_26_d[6'h01] && ~ds_inst[25] && ~ds_inst[24] && (rj==6'b00); //00000100
assign inst_csrwr  = op_31_26_d[6'h01] && ~ds_inst[25] && ~ds_inst[24] && (rj==6'b01); //00000100
assign inst_csrxchg= op_31_26_d[6'h01] & ~ds_inst[25] & ~ds_inst[24] & ~inst_csrrd & ~inst_csrwr; //00000100
assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10]; //00000110010010000 01110?
assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16]; //00000000001010110

// Add in lab9
assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);
assign op_ld_w     = inst_ld_w;
assign op_ld_b     = inst_ld_b;
assign op_ld_h     = inst_ld_h;
assign op_ld_bu    = inst_ld_bu;
assign op_ld_hu    = inst_ld_hu;
assign op_st_b     = inst_st_b;
assign op_st_h     = inst_st_h;
assign op_st_w     = inst_st_w;

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_mem | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor; 
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;

assign res_from_mem = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori //slti, sltui, andi, ori, xori use addi.w in id stage
                    | inst_mem;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i; //pcaddu12i: PC+{si20, 12'b0}, uses lu12i.w in id stage
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign ds_imm = src2_is_4 ? 32'h4                      :
		need_si20 ? {i20[19:0], 12'b0} :  //i20[16:5]==i12[11:0]
        inst_andi | inst_ori | inst_xori ? {20'b0,i12[11:0]} : // (rj) zero extension
  /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | 
                       inst_bgeu | inst_st_w | inst_st_b | inst_st_h| 
                       inst_csrrd | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w | 
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       //add in lab6
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_pcaddu12i |
                       // add in lab7
                       inst_mem
                       ;

// CSR signals
// Add in Lab 8
assign csr_num      = inst_rdcntid ? 14'd64 : ds_inst[23:10];
assign csr_we       = inst_csrwr | inst_csrxchg;
assign csr_re       = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
assign csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{~inst_csrxchg}};
assign csr_wvalue   = rkd_value;


/* --------------  Adder for comparison -------------- */

assign {sign_bit, out} = {1'b0, rj_value} + {1'b1, ~rkd_value} + 33'd1;
assign overflow = (rj_value[31] ^ rkd_value[31]) & (rj_value[31] ^ out[31]);
assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = out[31] ^ overflow;
assign rj_ltu_rd = sign_bit;



/* --------------  Handshaking signals -------------- */

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin 
    if (reset | final_ex | ws_ertn_flush) begin
        ds_valid <= 1'b0;
    end
    else if (br_taken)
        ds_valid <= 1'b0;
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
end

assign  load_block = es_valid && es_res_from_mem && (raw1 || raw4);
assign  csr_block =  es_csr_block & (raw1 | raw4)
                   | ms_csr_block & (raw2 | raw5) 
                   | ws_valid & ws_csr_re & (raw3 | raw6) ;
                
assign  ds_ready_go  = !load_block &&
                        !(!final_ex && ((es_valid && es_ex) || (ms_valid && ms_ex) || (ws_valid && ws_ex)) && ds_valid) &&
                        !(ds_valid && csr_block) &&
                        !(has_int && ((es_valid && (es_ertn_flush || (es_csr_we && (es_csr_num == `CSR_CRMD || es_csr_num == `CSR_ECFG )))) || 
                        (ms_valid && (ms_ertn_flush || (ms_csr_we && (ms_csr_num == `CSR_CRMD || ms_csr_num == `CSR_ECFG )))) ||
                        (ws_valid && (ws_ertn_flush || (ws_csr_we && (ws_csr_num == `CSR_CRMD || ws_csr_num == `CSR_ECFG ))))
                        )) && ~csr_block;

/* ------------------- lab10 ------------------- */
assign br_stall = es_valid && es_res_from_mem && (need_si16 && (raw1 || raw4)
               || need_si16 && (raw2 || raw5));

/* ------------------- BUS ------------------- */

// FS to DS bus
always @(posedge clk) begin
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign {fs_esubcode ,  //71
        fs_ecode    ,  //70:65
        fs_ex       ,  //64
        ds_inst,
        ds_pc  
       } = fs_to_ds_bus_r;

// WS to RF bus
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

// BR bus
assign br_bus       = {ex_detected_to_fs, br_stall,br_taken,br_target};

// ES forward bus
assign  {es_csr_block,
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
        } = es_forward;

// MS forward bus
assign  {ms_csr_block,
         ms_csr_re, //56
         ms_csr_num, //55:42
         ms_csr_we, //41
         ms_ertn_flush, //40
         ms_ex, //39
         ms_final_result, //38:7
         ms_dest , //6:2 
         ms_gr_we, //1:1
         ms_valid  //0:0
        } = ms_forward;  

// WS forward bus
assign  {has_int, //122
         ex_era,    //121:90
         ex_entry,  //89:58
         final_ex, //57
         ws_csr_re, //56
         ws_csr_num, //55:42
         ws_csr_we, //41
         ws_ertn_flush, //40
         ws_ex, //39
         ws_final_result, //38:7
         ws_dest , //6:2
         ws_rf_we, //1
         ws_valid //0
        } = ws_forward;

// DS to ES bus

// ds_rdcnt signal is the combination of three inst signals
assign ds_rdcnt     = {inst_rdcntid, inst_rdcntvh_w, inst_rdcntvl_w};

assign ds_to_es_bus = {ds_rdcnt    ,  //256:254
                       inst_ertn   ,  //253
                       ds_esubcode ,  //252
                       ds_ecode    ,  //251:246
                       ds_ex & ds_valid,  //245
                       csr_re      ,  //244
                       csr_num     ,  //243:230
                       csr_wvalue  ,  //229:198
                       csr_wmask   ,  //197:166
                       csr_we ,  //165
                       op_st_w     ,  //164
                       op_ld_w     ,  //163
                       op_ld_b     ,  //162
                       op_ld_bu    ,  //161
                       op_ld_h     ,  //160
                       op_ld_hu    ,  //159
                       op_st_b     ,  //158
                       op_st_h     ,  //157
                       alu_op      ,  //156:138
                       res_from_mem,  //137:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };



/* ------------------- Branch ------------------- */

assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  && !rj_lt_rd
                   || inst_bltu &&  rj_ltu_rd
                   || inst_bgeu && !rj_ltu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                    ) && ds_valid && ds_ready_go; 
assign br_target = inst_jirl ? (rj_value + jirl_offs) : (ds_pc + br_offs);




/* ------------------- Regfile Interface ------------------- */

assign dst_is_r1     = inst_bl;
assign dst_is_rj     = inst_rdcntid;
assign gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bltu 
                        & ~inst_bge & ~inst_bgeu & ~inst_b & ~inst_ertn;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : 
                       dst_is_rj ? rj   : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );



/* ------------------- RAW Conflict ------------------- */


assign no_src1 = inst_b || inst_bl || inst_pcaddu12i || 
                 inst_csrrd || inst_csrwr || inst_rdcntvl_w || inst_rdcntvh_w || inst_rdcntid;

assign no_src2 = inst_b || inst_bl || inst_jirl || inst_addi_w ||
                 inst_ld_w || inst_ld_b || inst_ld_bu || inst_ld_h || inst_ld_hu ||
                 inst_slli_w || inst_srli_w || inst_srai_w || inst_slti || inst_sltui ||
                 inst_andi || inst_ori || inst_xori || inst_pcaddu12i || inst_csrrd || inst_rdcntvh_w || inst_rdcntid;

assign src1 = no_src1 ? 5'd0 : rf_raddr1;
assign src2 = no_src2 ? 5'd0 : rf_raddr2; 

assign raw1 = (src1 == es_dest) && (src1 != 5'd0) && (es_dest != 5'd0) && es_valid && es_gr_we;
assign raw2 = (src1 == ms_dest) && (src1 != 5'd0) && (ms_dest != 5'd0) && ms_valid && ms_gr_we;
assign raw3 = (src1 == ws_dest) && (src1 != 5'd0) && (ws_dest != 5'd0) && ws_rf_we ;
assign raw4 = (src2 == es_dest) && (src2 != 5'd0) && (es_dest != 5'd0) && es_valid && es_gr_we;
assign raw5 = (src2 == ms_dest) && (src2 != 5'd0) && (ms_dest != 5'd0) && ms_valid && ms_gr_we;
assign raw6 = (src2 == ws_dest) && (src2 != 5'd0) && (ws_dest != 5'd0) && ws_rf_we ;

assign raw = raw1 || raw2 || raw3 || raw4 || raw5 || raw6;

assign rj_value  = raw1 ? es_alu_result   :
                   raw2 ? ms_final_result :
                   raw3 ? ws_final_result : rf_rdata1; 

assign rkd_value = raw4 ? es_alu_result   :
                   raw5 ? ms_final_result :
                   raw6 ? ws_final_result : rf_rdata2; 



/* ------------------- Exceptions ------------------- */

assign ds_ex = ds_ready_go & (inst_syscall | inst_break | fs_ex | ine_ex | has_int);
assign ds_ecode = ~ds_valid    ? 6'b0       :
                  fs_ex        ? fs_ecode   :
                  ine_ex       ? `ECODE_INE :
                  has_int      ? `ECODE_INT :
                  inst_syscall ? `ECODE_SYS :
                  inst_ertn    ? `ECODE_ERT :
                  inst_break   ? `ECODE_BRK : 6'b0;

assign ds_esubcode = fs_esubcode;

always @(posedge clk) begin
    if (reset)
        ex_detected_unsolved <= 1'b0;
    else if (ms_ex)
        ex_detected_unsolved <= 1'b0;
    else if (ds_ex && ~final_ex)
        ex_detected_unsolved <= 1'b1;
    else
        ex_detected_unsolved <= 1'b0;
end

assign ex_detected_to_fs = ex_detected_unsolved;

// INE exception
// Add in Lab 9
assign ine_ex = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor |
                  inst_slli_w |inst_srli_w |inst_srai_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b |
                  inst_bl | inst_beq | inst_bne | inst_lu12i_w | inst_slti | inst_sltui | inst_andi | inst_ori | 
                  inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                  inst_div_w | inst_mod_w |inst_div_wu | inst_mod_wu | inst_blt | inst_bge | inst_bltu |
                  inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_pcaddu12i |
                  inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_syscall |
                  inst_break | inst_rdcntid | inst_rdcntvh_w | inst_rdcntvl_w);


endmodule
