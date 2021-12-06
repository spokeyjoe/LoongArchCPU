`include "mycpu.h"

module regcsr(
    input         clk       ,
    input         reset     ,
    input         ws_valid  ,
    input         csr_we    , //写使�??
    input  [13:0] csr_num   , //寄存器号
    input  [31:0] csr_wmask , //写掩�??
    input  [31:0] csr_wvalue, //写数�??
    output [31:0] csr_rvalue, //读返回�??

    input         ertn_flush, //ertn执行有效信号
    input         wb_ex     , //写回流水级异�??
    input         refill_ex ,
    input  [ 5:0] wb_ecode  , //异常类型
    input         wb_esubcode,//
    input  [31:0] wb_pc     , //!!!!
    input  [31:0] wb_vaddr  , //访存虚地�??

    output [31:0] ex_entry  , //to pre-IF, 异常处理入口地址
    output [31:0] ex_era    ,
    output        has_int   , //to id, 中断有效信号
    // counter
    output [63:0] counter   ,
    output [31:0] counter_id,
    // tlb
    input  [97:0] csr_tlb_in,
    output [97:0] csr_tlb_out,
    output [31:0] csr_asid_rvalue,
    output [31:0] csr_tlbehi_rvalue,
    output [31:0] csr_crmd_rvalue,
    output [31:0] csr_dmw0_rvalue,
    output [31:0] csr_dmw1_rvalue,
    output [31:0] csr_tlbrentry_rvalue
);
//wire        es_valid;
wire        inst_tlbfill;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        s1_found;
wire [ 3:0] s1_index;
wire        we;
wire [ 3:0] w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [ 5:0] w_ps;
wire [ 9:0] w_asid;
wire        w_g;
wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
wire [ 3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [ 5:0] r_ps;
wire [ 9:0] r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [ 1:0] r_plv0;
wire [ 1:0] r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [ 1:0] r_plv1;
wire [ 1:0] r_mat1;
wire        r_d1;
wire        r_v1;

assign  {//es_valid,    //96
          inst_tlbwr,//97
          inst_tlbfill,//96
          inst_tlbsrch,//95
          inst_tlbrd,  //94
          s1_found,    //93
          s1_index,    //92:89
          r_e,         //88
          r_vppn,      //87:69
          r_ps,        //68:63
          r_asid,      //62:53
          r_g,         //52
          r_ppn0,      //51:32
          r_plv0,      //31:30
          r_mat0,      //29:28
          r_d0,        //27
          r_v0,        //26
          r_ppn1,      //25:6
          r_plv1,      //5:4
          r_mat1,      //3:2
          r_d1,        //1
          r_v1         //0
        } = csr_tlb_in ;

assign csr_tlb_out   = {we,     //97
                        w_index,//96:93
                        w_e,    //92
                        w_vppn, //91:73
                        w_ps,   //72:67
                        w_asid, //66:57
                        w_g,    //56
                        w_ppn0, //55:36
                        w_plv0, //35:34
                        w_mat0, //33:32
                        w_d0,   //31
                        w_v0,   //30
                        w_ppn1, //29:10
                        w_plv1, //9:8
                        w_mat1, //7:6
                        w_d1,   //5
                        w_v1,   //4
                        r_index //3:0
                       };
                       
reg  [ 1:0] csr_crmd_plv;     //priority level
reg         csr_crmd_ie;      //interrupt enable
reg         csr_crmd_da;      //direct address enable
reg         csr_crmd_pg;      //mapping address enable
reg  [ 1:0] csr_crmd_datf;    //in direct address
reg  [ 1:0] csr_crmd_datm;    //in direct address
reg  [ 1:0] csr_prmd_pplv;
reg         csr_prmd_pie;
reg  [12:0] csr_ecfg_lie;
reg  [12:0] csr_estat_is;
reg  [ 5:0] csr_estat_ecode;
reg  [ 8:0] csr_estat_esubcode;
reg  [31:0] csr_era_pc;
reg  [25:0] csr_eentry_va;
reg  [31:0] csr_save0_data;
reg  [31:0] csr_save1_data;
reg  [31:0] csr_save2_data;
reg  [31:0] csr_save3_data;

// Add in lab 9
reg  [31:0] csr_badv_vaddr;
reg  [31:0] csr_tid_tid;
reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg  [31:0] timer_cnt;
wire        csr_ticlr_clr;
wire        wb_ex_addr_err; 

// Add in lab 14

// TLBIDX 
reg  [ 3:0] csr_tlbidx_index;
reg  [ 5:0] csr_tlbidx_ps;
reg         csr_tlbidx_ne;

// TLBEHI
reg  [18:0] csr_tlbehi_vppn;

// TLBELO
reg         csr_tlbelo0_v;
reg         csr_tlbelo0_d;
reg  [ 1:0] csr_tlbelo0_plv;
reg  [ 1:0] csr_tlbelo0_mat;
reg         csr_tlbelo0_g;
reg  [23:0] csr_tlbelo0_ppn;  
reg         csr_tlbelo1_v;
reg         csr_tlbelo1_d;
reg  [ 1:0] csr_tlbelo1_plv;
reg  [ 1:0] csr_tlbelo1_mat;
reg         csr_tlbelo1_g;
reg  [23:0] csr_tlbelo1_ppn;

// ASID
reg  [ 9:0] csr_asid_asid;
wire [ 7:0] csr_asid_asidbits = 8'd10;

// TLBRENTRY
reg  [25:0] csr_tlbrentry_pa;

// DMW
reg         csr_dmw0_plv0;
reg         csr_dmw0_plv3;
reg  [ 1:0] csr_dmw0_mat;
reg  [ 2:0] csr_dmw0_pseg;
reg  [ 2:0] csr_dmw0_vseg;
reg         csr_dmw1_plv0;
reg         csr_dmw1_plv3;
reg  [ 1:0] csr_dmw1_mat;
reg  [ 2:0] csr_dmw1_pseg;
reg  [ 2:0] csr_dmw1_vseg;

always @(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0; //highest priority level
        csr_crmd_ie  <= 1'b0;
        csr_crmd_da  <= 1'b1;//!
        csr_crmd_pg  <= 1'b0;
        csr_crmd_datf<= 2'b0;
        csr_crmd_datm<= 2'b0;
    end
    else if(wb_ex | refill_ex) begin
        if(refill_ex) begin
            csr_crmd_pg <= 1'h0;
            csr_crmd_da <= 1'h1;
        end
        csr_crmd_plv <= 2'b0; //when exception happens, set highest priority level
        csr_crmd_ie  <= 1'b0; //when exception happens, set interrupt disenble, to mask interrupt
    end
    else if(ertn_flush) begin
        if(csr_estat_ecode == `ECODE_TLBR) begin
            csr_crmd_pg <= 1'h1;
            csr_crmd_da <= 1'h0;
        end
        csr_crmd_plv <= csr_prmd_pplv; //when ERTN, recover pplv
        csr_crmd_ie  <= csr_prmd_pie;  //when ERTN, recover pie
    end
    else if(csr_we && csr_num==`CSR_CRMD) begin //csrwr, csrxchg
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie  <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                     | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
        csr_crmd_da  <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                     | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg  <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                     | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF]
                     | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
        csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM]
                     | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;                    
    end
end

assign csr_crmd_rvalue = {23'b0,         //31:9
                          csr_crmd_datm, //8:7
                          csr_crmd_datf, //6:5
                          csr_crmd_pg,   //4
                          csr_crmd_da,   //3
                          csr_crmd_ie,   //2
                          csr_crmd_plv   //1:0
                         };

always @(posedge clk) begin
    if(reset) begin
        csr_prmd_pplv <= 2'b0; //when exception happens, save context
        csr_prmd_pie  <= 1'b0;
    end
    if((wb_ex | refill_ex) && csr_crmd_rvalue[2:0]!=3'b000) begin //!!!
        csr_prmd_pplv <= csr_crmd_plv; //when exception happens, save context
        csr_prmd_pie  <= csr_crmd_ie ;
    end
    else if(csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]  & csr_wvalue[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE]  & csr_prmd_pie;
    end
end

wire [31:0] csr_prmd_rvalue = {29'b0        , //31:3
                               csr_prmd_pie , //2
                               csr_prmd_pplv  //1:0
                              };

always @ (posedge clk) begin
    if (reset) 
        csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_num == `CSR_ECFG) 
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                     | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
end


wire [31:0] csr_ecfg_rvalue = {19'b0,          //31:13
                               csr_ecfg_lie    //12:0
                              };

always @(posedge clk) begin
    if(reset)
        csr_estat_is[1:0] <= 2'b0;
    else if(csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                          | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    
    csr_estat_is[9:2] <= 8'b0;//hw_int_in[7:0];//hardware interrupt
    csr_estat_is[10]  <= 1'b0;          //no define

    if (csr_tcfg_en && timer_cnt[31:0]==32'b0)
        csr_estat_is[11] <= 1'b1; //timer interrupt
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0; // Finish in lab 9

    csr_estat_is[12] <= 1'b0;//ipi_int_in; //ipi interrupt
end

always @(posedge clk) begin
    if((wb_ex | refill_ex) & ~ertn_flush) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

wire [31:0] csr_estat_rvalue = {1'b0              , //31
                                csr_estat_esubcode, //30:22
                                csr_estat_ecode   , //21:16, exception types
                                3'b0              , //15:13
                                csr_estat_is[12:2], //12:2,other interrupt
                                csr_estat_is[ 1:0]  //1:0, software interrupt
                               };

always @(posedge clk) begin
    if(reset)
        csr_era_pc <= 32'b0;
    else if((wb_ex | refill_ex) & ~ertn_flush)
        csr_era_pc <= wb_pc;
    else if(csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                   | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end

wire [31:0] csr_era_rvalue = csr_era_pc;
assign ex_era = csr_era_rvalue;

always @(posedge clk) begin
    if(reset) begin
        csr_eentry_va <= 26'b0;
    end
    if(csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                      | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

wire [31:0] csr_eentry_rvalue = {csr_eentry_va, //31:6
                                 6'b0           // 5:0
                                };//that is, the address must be xxx000000
                                
assign ex_entry = csr_eentry_rvalue;

always @(posedge clk) begin
    if (reset) begin
        csr_save0_data <= 32'b0;
        csr_save1_data <= 32'b0;
        csr_save2_data <= 32'b0;
        csr_save3_data <= 32'b0;
    end
    else if(csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
    else if(csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
    else if(csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
    else if(csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

wire [31:0]  csr_save0_rvalue = csr_save0_data;
wire [31:0]  csr_save1_rvalue = csr_save1_data;
wire [31:0]  csr_save2_rvalue = csr_save2_data;
wire [31:0]  csr_save3_rvalue = csr_save3_data;

// BADV
assign wb_ex_addr_err = wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE 
                     || wb_ecode == `ECODE_TLBR || wb_ecode == `ECODE_PIF || wb_ecode == `ECODE_PIS || wb_ecode == `ECODE_PIL || wb_ecode == `ECODE_PME || wb_ecode == `ECODE_PPE;

always @(posedge clk) begin
    if(reset) begin
        csr_badv_vaddr <= 32'b0;
    end
    if ((wb_ex | refill_ex) && wb_ex_addr_err)
        csr_badv_vaddr <= (wb_ecode == `ECODE_ADE && wb_esubcode == `ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
end

wire [31:0] csr_badv_rvalue = csr_badv_vaddr;

// TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= 32'd0;
    else if (csr_we && csr_num == `CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID] 
                    | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
end

wire [31:0] csr_tid_rvalue = csr_tid_tid;

// TCFG
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num == `CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN] |
                      ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
                    
    if (csr_we && csr_num == `CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC] & csr_wvalue[`CSR_TCFG_PERIODIC] |
                            ~csr_wmask[`CSR_TCFG_PERIODIC] & csr_tcfg_periodic;
        csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITVAL]  & csr_wvalue[`CSR_TCFG_INITVAL]  |
                            ~csr_wmask[`CSR_TCFG_INITVAL]  & csr_tcfg_initval;
    end
end

wire [31:0] csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

// TVAL
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0] |
                        ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
        if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else 
            timer_cnt <= timer_cnt - 1'b1;
    end
end

assign csr_tval = timer_cnt[31:0];

// TICLR
assign csr_ticlr_clr = 1'b0;

wire [31:0] csr_ticlr = {31'd0, csr_ticlr_clr};

// TLBIDX
always @(posedge clk) begin
    if(reset) begin
        csr_tlbidx_ne    <= 1'b1;
        csr_tlbidx_ps    <= 6'b0;
        csr_tlbidx_index <= 4'b0;
    end
    else if(inst_tlbsrch) begin
        if(s1_found) begin
            csr_tlbidx_ne    <= 1'b0;
            csr_tlbidx_index <= s1_index;
        end
        else 
            csr_tlbidx_ne    <= 1'b1;
    end
    else if(ws_valid && inst_tlbrd) begin
        csr_tlbidx_ne    <= ~r_e;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbidx_ps    <= r_ps;
    end
    else if(csr_we && csr_num==`CSR_TLBIDX)begin
        csr_tlbidx_ne    <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                         | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne; 
        csr_tlbidx_ps    <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                         | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                         | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
    end
end

wire [31:0] csr_tlbidx_rvalue = {csr_tlbidx_ne   ,//31
                                 1'b0            ,//30
                                 csr_tlbidx_ps   ,//29:24
                                 8'b0            ,//23:16
                                 12'b0           ,//15:4
                                 csr_tlbidx_index //3:0
                                };
// TLBEHI
always @(posedge clk) begin
    if(reset) begin
        csr_tlbehi_vppn <= 19'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbehi_vppn <= r_vppn;
    end
    else if (wb_ex & ~ertn_flush & (wb_ecode == `ECODE_TLBR | `ECODE_PIL | `ECODE_PIS | `ECODE_PIF | `ECODE_PME |`ECODE_PPE)) 
        csr_tlbehi_vppn <= wb_vaddr[31:13];
    else if(csr_we && csr_num == `CSR_TLBEHI) begin
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                        | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;   
    end 
end

assign csr_tlbehi_rvalue = {csr_tlbehi_vppn,//31:13
                            13'b0           //12:0
                           };

// TLBELO0//even
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo0_v   <= 1'b0;
        csr_tlbelo0_d   <= 1'b0;
        csr_tlbelo0_plv <= 2'b0;
        csr_tlbelo0_mat <= 2'b0;
        csr_tlbelo0_g   <= 1'b0;
        csr_tlbelo0_ppn <= 24'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbelo0_v   <= r_v0;
        csr_tlbelo0_d   <= r_d0;
        csr_tlbelo0_plv <= r_plv0;
        csr_tlbelo0_mat <= r_mat0;
        csr_tlbelo0_g   <= r_g;
        csr_tlbelo0_ppn <= r_ppn0;
    end
    else if(csr_we && csr_num == `CSR_TLBELO0) begin
        csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo0_v; 
        csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo0_d;
        csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
        csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
        csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo0_g;    
    end
end

wire [31:0] csr_tlbelo0_rvalue = {csr_tlbelo0_ppn,//31:8
                                  1'b0           ,//7
                                  csr_tlbelo0_g  ,//6
                                  csr_tlbelo0_mat,//5:4
                                  csr_tlbelo0_plv,//3:2
                                  csr_tlbelo0_d  ,//1
                                  csr_tlbelo0_v   //0
                                 };

// TLBELO1//odd
always @(posedge clk) begin
    if(reset) begin
        csr_tlbelo1_v   <= 1'b0;
        csr_tlbelo1_d   <= 1'b0;
        csr_tlbelo1_plv <= 2'b0;
        csr_tlbelo1_mat <= 2'b0;
        csr_tlbelo1_g   <= 1'b0;
        csr_tlbelo1_ppn <= 24'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_tlbelo1_v   <= r_v1;
        csr_tlbelo1_d   <= r_d1;
        csr_tlbelo1_plv <= r_plv1;
        csr_tlbelo1_mat <= r_mat1;
        csr_tlbelo1_g   <= r_g;
        csr_tlbelo1_ppn <= r_ppn1;
    end
    else if(csr_we && csr_num == `CSR_TLBELO1) begin
        csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo1_v; 
        csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo1_d;
        csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
        csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
        csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo1_g;    
    end
end

wire [31:0] csr_tlbelo1_rvalue = {csr_tlbelo1_ppn,//31:8
                                  1'b0           ,//7
                                  csr_tlbelo1_g  ,//6
                                  csr_tlbelo1_mat,//5:4
                                  csr_tlbelo1_plv,//3:2
                                  csr_tlbelo1_d  ,//1
                                  csr_tlbelo1_v   //0
                                 };

// ASID                                 
always @(posedge clk) begin
    if(reset) begin
        csr_asid_asid <= 10'b0;
    end
    else if(inst_tlbrd && r_e) begin
        csr_asid_asid <= r_asid;
    end
    else if(csr_we && csr_num == `CSR_ASID)begin
        csr_asid_asid  <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                       | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid; 
    end
end

assign csr_asid_rvalue = {8'b0             ,//31:24
                          csr_asid_asidbits,//23:16
                          6'b0             ,//15:10
                          csr_asid_asid     //9:0
                         };
// TLBRENTRY
always @(posedge clk ) begin
    if(reset)begin
        csr_tlbrentry_pa <= 26'b0;
    end 
    else if(csr_we && csr_num == `CSR_TLBRENTRY) begin
        csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                         | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa; 
    end
end

assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa,//31:6
                               6'b0             //5:0    
                              };
// DMW0
always @ (posedge clk) begin
    if (reset) begin
        csr_dmw0_vseg <= 3'b0;
        csr_dmw0_pseg <= 3'b0;
        csr_dmw0_mat  <= 2'b0;
        csr_dmw0_plv3 <= 1'b0;
        csr_dmw0_plv0 <= 1'b0;
    end
    else if (csr_we & (csr_num == `CSR_DMW0)) begin
        csr_dmw0_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                      | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;
        csr_dmw0_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                      | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
        csr_dmw0_mat  <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]
                      | ~csr_wmask[`CSR_DMW_MAT]  & csr_dmw0_mat;
        csr_dmw0_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                      | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3;
        csr_dmw0_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                      | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0;
    end
end

assign csr_dmw0_rvalue = {csr_dmw0_vseg, //31:29
                          1'b0,          //28
                          csr_dmw0_pseg, //27:25
                          19'b0,         //24:6
                          csr_dmw0_mat,  //5:4
                          csr_dmw0_plv3, //3
                          2'b0,          //2:1
                          csr_dmw0_plv0  //0
                         };

// DMW1
always @ (posedge clk) begin
    if (reset) begin
        csr_dmw1_vseg <= 3'b0;
        csr_dmw1_pseg <= 3'b0;
        csr_dmw1_mat  <= 2'b0;
        csr_dmw1_plv3 <= 1'b0;
        csr_dmw1_plv0 <= 1'b0;
    end
    else if (csr_we & (csr_num == `CSR_DMW1)) begin
        csr_dmw1_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                      | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;
        csr_dmw1_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                      | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
        csr_dmw1_mat  <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]
                      | ~csr_wmask[`CSR_DMW_MAT]  & csr_dmw1_mat;
        csr_dmw1_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                      | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3;
        csr_dmw1_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                      | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0;
    end
end

assign csr_dmw1_rvalue = {csr_dmw1_vseg, //31:29
                          1'b0,          //28
                          csr_dmw1_pseg, //27:25
                          19'b0,         //24:6
                          csr_dmw1_mat,  //5:4
                          csr_dmw1_plv3, //3
                          2'b0,          //2:1
                          csr_dmw1_plv0  //0
                         };

reg [ 3:0] tlbfill_index;
always @(posedge clk)begin
    if(reset)begin
        tlbfill_index <= 4'b0;
    end
    else if(inst_tlbfill & ws_valid) begin
        if(tlbfill_index == 4'd15) begin
            tlbfill_index <= 4'b0;
        end
        else begin
            tlbfill_index <= tlbfill_index + 4'b1;
        end
    end
end

assign we      = ws_valid && inst_tlbwr || inst_tlbfill;;
assign w_index = ws_valid && inst_tlbfill ?tlbfill_index : csr_tlbidx_index;
assign w_e     = csr_estat_ecode == 6'h3f ? 1'b1         : ~csr_tlbidx_ne;
assign w_vppn  = csr_tlbehi_vppn;
assign w_ps    = csr_tlbidx_ps;
assign w_asid  = csr_asid_asid;
assign w_g     = csr_tlbelo0_g && csr_tlbelo1_g;
assign w_ppn0  = csr_tlbelo0_ppn;
assign w_plv0  = csr_tlbelo0_plv;
assign w_mat0  = csr_tlbelo0_mat;
assign w_d0    = csr_tlbelo0_d;
assign w_v0    = csr_tlbelo0_v;
assign w_ppn1  = csr_tlbelo1_ppn;
assign w_plv1  = csr_tlbelo1_plv;
assign w_mat1  = csr_tlbelo1_mat;
assign w_d1    = csr_tlbelo1_d;
assign w_v1    = csr_tlbelo1_v;
assign r_index = csr_tlbidx_index;

assign csr_rvalue = {32{csr_num==`CSR_CRMD     }} & csr_crmd_rvalue
                  | {32{csr_num==`CSR_PRMD     }} & csr_prmd_rvalue
                  | {32{csr_num==`CSR_ESTAT    }} & csr_estat_rvalue
                  | {32{csr_num==`CSR_ERA      }} & csr_era_rvalue
                  | {32{csr_num==`CSR_EENTRY   }} & csr_eentry_rvalue
                  | {32{csr_num==`CSR_ECFG     }} & csr_ecfg_rvalue
                  | {32{csr_num==`CSR_SAVE0    }} & csr_save0_rvalue
                  | {32{csr_num==`CSR_SAVE1    }} & csr_save1_rvalue
                  | {32{csr_num==`CSR_SAVE2    }} & csr_save2_rvalue
                  | {32{csr_num==`CSR_SAVE3    }} & csr_save3_rvalue
                  | {32{csr_num==`CSR_BADV     }} & csr_badv_rvalue
                  | {32{csr_num==`CSR_TID      }} & csr_tid_rvalue
                  | {32{csr_num==`CSR_TCFG     }} & csr_tcfg_rvalue
                  | {32{csr_num==`CSR_TVAL     }} & csr_tval
                  | {32{csr_num==`CSR_TICLR    }} & csr_ticlr
                  | {32{csr_num==`CSR_TLBIDX   }} & csr_tlbidx_rvalue
                  | {32{csr_num==`CSR_TLBEHI   }} & csr_tlbehi_rvalue
                  | {32{csr_num==`CSR_TLBELO0  }} & csr_tlbelo0_rvalue
                  | {32{csr_num==`CSR_TLBELO1  }} & csr_tlbelo1_rvalue
                  | {32{csr_num==`CSR_ASID     }} & csr_asid_rvalue
                  | {32{csr_num==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                  | {32{csr_num==`CSR_DMW0     }} & csr_dmw0_rvalue
                  | {32{csr_num==`CSR_DMW1     }} & csr_dmw1_rvalue; 

assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0)
                && (csr_crmd_ie == 1'b1);

reg [63:0] cnt;
always @(posedge clk) begin
    if (reset)
        cnt <= 64'b0;
    else 
        cnt <= cnt + 1'b1;
end

assign counter = cnt;
assign counter_id = csr_tid_tid;

endmodule