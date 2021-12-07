`include "mycpu.h"

module wb_stage#(
parameter TLBNUM = 16
)
(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    output                          final_ex      ,
    //trace debug interface
    output [31                 :0]  debug_wb_pc     ,
    output [ 3                 :0]  debug_wb_rf_wen ,
    output [ 4                 :0]  debug_wb_rf_wnum,
    output [31                 :0]  debug_wb_rf_wdata,
    output [`WS_FORWARD_WD   -1:0]  ws_forward,
    output [`WS_TO_FS_BUS_WD -1:0]  ws_to_fs_bus,

    // counter to es
    output [63:0] counter,
    output back_ertn_flush,
    output back_ex,
    // tlb
    output [                 97:0]  csr_tlb_out,
    input  [                 97:0]  csr_tlb_in,
    output [`WS_TO_ES_BUS_WD -1:0]  ws_to_es_bus
);

/* --------------  Handshaking signals -------------- */

reg         ws_valid;
wire        ws_ready_go;

/* -------------------  BUS ------------------- */

// MS to WS bus
reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire       ws_tlb_refetch;

/* -------------------  CSR Interface ------------------- */

wire [13:0] ws_csr_num;
wire        ws_csr_re;
wire [31:0] ws_csr_wmask; 
wire [31:0] ws_csr_wvalue;
wire [31:0] ws_csr_rvalue;
wire        ws_csr_we;

wire [31:0] counter_id;

wire [31:0] ws_vaddr;
wire [31:0] ws_final_result;

wire        ws_tlb_refetch;
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_tlbrentry_rvalue;

/* -------------------  Regfile Interface ------------------- */

wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_pc; 

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;

wire        ws_inst_rdcntid;



/* -------------------  Exceptions ------------------- */

wire        ws_ertn_flush;
wire        fixed_ertn_flush;
wire        ws_esubcode;
wire [ 5:0] ws_ecode;
wire        ws_ex;

wire [31:0] ex_entry;
wire [31:0] ex_era;
wire        has_int;

wire        es_tlb_refill_ex;
wire        refill_ex;
/* -------------------  Debug Interface ------------------- */

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;


/* --------------  Handshaking signals -------------- */

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;

always @(posedge clk) begin
    if (reset | final_ex | fixed_ertn_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
end

/* -------------------  BUS ------------------- */

always @(posedge clk) begin
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign {es_tlb_refill_ex, //198
 //       s1_index       ,  //201:198
        ws_tlb_refetch ,  //197
        inst_tlbsrch   ,  //196
        inst_tlbrd     ,  //195
        inst_tlbwr     ,  //194
        inst_tlbfill   ,  //193
        inst_invtlb    ,  //192
        ws_inst_rdcntid,  //191
        ws_vaddr       ,  //190:159
        ws_ertn_flush  ,  //158
        ws_esubcode    ,  //157
        ws_ecode       ,  //156:151
        ws_ex          ,  //150
        ws_csr_re      ,  //149
        ws_csr_num     ,  //148:135
        ws_csr_wvalue  ,  //134:103
        ws_csr_wmask   ,  //102:71
        ws_csr_we      ,  //70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

// WS forward bus
assign ws_forward       = {(inst_tlbwr || inst_tlbrd || inst_tlbfill || inst_invtlb) && ws_valid , //123
                           has_int        , //122
                           ex_era         , //121:90
                           ex_entry       , //89:58
                           final_ex       , //57
                           ws_csr_re      , //56
                           ws_csr_num     , //55:42
                           ws_csr_we      , //41
                           fixed_ertn_flush  , //40
                           ws_ex&ws_valid , //39
                           ws_final_result, //38:7
                           ws_dest        , //6:2
                           rf_we          , //1
                           ws_valid         //0
                          };

// WS to FS bus
assign ws_to_fs_bus     ={refill_ex, //260
                          csr_tlbrentry_rvalue, //259:228
                          csr_asid_rvalue, //227:196
                          csr_crmd_rvalue, //195:164
                          csr_dmw0_rvalue, //163:132
                          csr_dmw1_rvalue, //131:100
                          (inst_tlbwr || inst_tlbrd || inst_tlbfill || inst_invtlb) && ws_valid, //99
                          ws_pc + 32'd4 , //98:67
                          has_int       , //66
                          ex_era        , //65:34
                          ex_entry      , //33:2
                          final_ex      , //1
                          fixed_ertn_flush   //0
                         };

assign ws_to_es_bus     ={csr_crmd_rvalue,
                          csr_dmw0_rvalue,
                          csr_dmw1_rvalue,
                          csr_asid_rvalue, //63:32
                          csr_tlbehi_rvalue//31:0
                         };

/* -------------------  CSR Interface ------------------- */

// assign ws_vaddr = ws_final_result;

regcsr u_regcsr(
    .clk        (clk          ),
    .reset      (reset        ),
    .ws_valid   (ws_valid     ),
    .csr_we     (ws_csr_we    ),
    .csr_num    (ws_csr_num   ),
    .csr_wmask  (ws_csr_wmask ),
    .csr_wvalue (ws_csr_wvalue),
    .csr_rvalue (ws_csr_rvalue), 
    .ertn_flush (ws_ertn_flush),
    .wb_ex      (final_ex     ), 
    .refill_ex  (refill_ex    ),
    .wb_ecode   (ws_ecode     ),
    .wb_esubcode(ws_esubcode  ),
    .wb_pc      (ws_pc        ),
    .ex_entry   (ex_entry     ),
    .ex_era     (ex_era       ),
    .has_int    (has_int      ),
    .wb_vaddr   (ws_vaddr     ),
    .counter    (counter      ),
    .counter_id (counter_id   ),
    .csr_tlb_in (csr_tlb_in   ),
    .csr_tlb_out(csr_tlb_out  ),
    .csr_asid_rvalue  (csr_asid_rvalue  ),
    .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
    .csr_crmd_rvalue  (csr_crmd_rvalue  ),
    .csr_dmw0_rvalue  (csr_dmw0_rvalue  ),
    .csr_dmw1_rvalue  (csr_dmw1_rvalue  ),
    .csr_tlbrentry_rvalue(csr_tlbrentry_rvalue)
);

/* -------------------  Regfile Interface ------------------- */

assign rf_we    = ws_gr_we && ws_valid && ~ws_ex && ~ws_tlb_refetch;
assign rf_waddr = ws_dest;
assign rf_wdata = {32{ws_csr_re}} & ws_csr_rvalue | 
                //  {32{ws_inst_rdcntid}} & counter_id |
                  {32{~ws_csr_re}} & ws_final_result;

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

/* -------------------  Exceptions ------------------- */
assign final_ex         = ws_valid & (ws_ex | ws_ertn_flush | refill_ex);
assign fixed_ertn_flush = (ws_ecode == `ECODE_ERT) && ws_valid;
assign back_ertn_flush  = fixed_ertn_flush;
assign back_ex          = final_ex;
assign refill_ex        = ws_valid & es_tlb_refill_ex;
endmodule
