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
    output                      we, 
    output [$clog2(TLBNUM)-1:0] w_index,
    output                      w_e,
    output [              18:0] w_vppn,
    output [               5:0] w_ps,
    output [               9:0] w_asid,
    output                      w_g,
    output [              19:0] w_ppn0,
    output [               1:0] w_plv0,
    output [               1:0] w_mat0,
    output                      w_d0,
    output                      w_v0,
    output [              19:0] w_ppn1,
    output [               1:0] w_plv1,
    output [               1:0] w_mat1,
    output                      w_d1,
    output                      w_v1,
    output [$clog2(TLBNUM)-1:0] r_index,
    input                       r_e,
    input  [              18:0] r_vppn,
    input  [               5:0] r_ps,
    input  [               9:0] r_asid,
    input                       r_g,
    input  [              19:0] r_ppn0,
    input  [               1:0] r_plv0,
    input  [               1:0] r_mat0,
    input                       r_d0,
    input                       r_v0,
    input  [              19:0] r_ppn1,
    input  [               1:0] r_plv1,
    input  [               1:0] r_mat1,
    input                       r_d1,
    input                       r_v1,
    output [`WS_TO_ES_BUS_WD -1:0] ws_to_es_bus
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

assign {ws_tlb_refetch ,  //197
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
assign ws_forward       = {ws_tlb_refetch && ws_valid , //123
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
assign ws_to_fs_bus     ={ws_tlb_refetch && ws_valid, //99
                          ws_pc         , //98:67
                          has_int       , //66
                          ex_era        , //65:34
                          ex_entry      , //33:2
                          final_ex      , //1
                          fixed_ertn_flush   //0
                         };

assign ws_to_es_bus     ={csr_asid_rvalue, //63:32
                          csr_tlbehi_rvalue//31:0
                         };

/* -------------------  CSR Interface ------------------- */

// assign ws_vaddr = ws_final_result;
wire [31:0] csr_estat_rvalue;
wire [31:0] csr_tlbidx_rvalue;
wire [31:0] csr_tlbehi_rvalue;
wire [31:0] csr_tlbelo0_rvalue;
wire [31:0] csr_tlbelo1_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_tlbrentry_rvalue;
reg  [ 3:0] tlbfill_index;

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

regcsr u_regcsr(
    .clk        (clk          ),
    .reset      (reset        ),
    .csr_we     (ws_csr_we    ),
    .csr_num    (ws_csr_num   ),
    .csr_wmask  (ws_csr_wmask ),
    .csr_wvalue (ws_csr_wvalue),
    .csr_rvalue (ws_csr_rvalue), 
    .ertn_flush (ws_ertn_flush),
    .wb_ex      (final_ex     ), 
    .wb_ecode   (ws_ecode     ),
    .wb_esubcode(ws_esubcode  ),
    .wb_pc      (ws_pc        ),
    .ex_entry   (ex_entry     ),
    .ex_era     (ex_era       ),
    .has_int    (has_int      ),
    .wb_vaddr   (ws_vaddr     ),
    .counter    (counter      ),
    .counter_id (counter_id   ),
    .inst_tlbsrch(inst_tlbsrch),
    .inst_tlbrd (inst_tlbrd   ),
    .r_e        (r_e&ws_valid ),
    .r_vppn     (r_vppn       ),
    .r_ps       (r_ps         ),
    .r_asid     (r_asid       ),
    .r_g        (r_g          ),
    .r_ppn0     (r_ppn0       ),
    .r_plv0     (r_plv0       ),
    .r_mat0     (r_mat0       ),
    .r_d0       (r_d0         ),
    .r_v0       (r_v0         ),
    .r_ppn1     (r_ppn1       ),
    .r_plv1     (r_plv1       ),
    .r_mat1     (r_mat1       ),
    .r_d1       (r_d1         ),
    .r_v1       (r_v1         ),
    .csr_estat_rvalue(csr_estat_rvalue),
    .csr_tlbidx_rvalue(csr_tlbidx_rvalue),
    .csr_tlbehi_rvalue(csr_tlbehi_rvalue),
    .csr_tlbelo0_rvalue(csr_tlbelo0_rvalue),
    .csr_tlbelo1_rvalue(csr_tlbelo1_rvalue),
    .csr_asid_rvalue(csr_asid_rvalue),
    .csr_tlbrentry_rvalue(csr_tlbrentry_rvalue)
);

assign we      = inst_tlbwr || inst_tlbfill;
assign w_index = inst_tlbwr   ? csr_tlbidx_rvalue[3:0]:
                 inst_tlbfill ? tlbfill_index[3:0]    : 4'b0;
assign w_ps    = csr_tlbidx_rvalue[29:24];
assign w_e     = (csr_estat_rvalue[21:16] == 6'h3f) || ~csr_tlbidx_rvalue[31];
assign w_vppn  = csr_tlbehi_rvalue[31:13];
assign w_v0    = csr_tlbelo0_rvalue [0];
assign w_d0    = csr_tlbelo0_rvalue [1];
assign w_plv0  = csr_tlbelo0_rvalue [3:2];
assign w_mat0  = csr_tlbelo0_rvalue [5:4];
assign w_ppn0  = csr_tlbelo0_rvalue [31:8];
assign w_v1    = csr_tlbelo1_rvalue [0];
assign w_d1    = csr_tlbelo1_rvalue [1];
assign w_plv1  = csr_tlbelo1_rvalue [3:2];
assign w_mat1  = csr_tlbelo1_rvalue [5:4];
assign w_ppn1  = csr_tlbelo1_rvalue [31:8];
assign w_g     = csr_tlbelo1_rvalue[6] & csr_tlbelo0_rvalue[6];
assign w_asid  = csr_asid_rvalue[9:0];
assign r_index = csr_tlbidx_rvalue[3:0];



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

assign final_ex = ws_valid & (ws_ex | ws_ertn_flush);
assign fixed_ertn_flush = (ws_ecode == `ECODE_ERT) && ws_valid;
assign back_ertn_flush = fixed_ertn_flush;
assign back_ex         = final_ex;

endmodule
