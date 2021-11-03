`include "mycpu.h"

module wb_stage(
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
    output [122                :0]  ws_forward,
    output [66                 :0]  ws_to_fs_bus,

    // counter to es
    output [63:0] counter,
    output back_ertn_flush,
    output back_ex
);


/* --------------  Handshaking signals -------------- */

reg         ws_valid;
wire        ws_ready_go;




/* -------------------  BUS ------------------- */

// MS to WS bus
reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;




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

assign {ws_inst_rdcntid,  //191
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
assign ws_forward       = {has_int        , //122
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
assign ws_to_fs_bus     ={has_int       , //66
                          ex_era        , //65:34
                          ex_entry      , //33:2
                          final_ex      , //1
                          fixed_ertn_flush   //0
                         };





/* -------------------  CSR Interface ------------------- */

// assign ws_vaddr = ws_final_result;

regcsr u_regcsr(
    .clk        (clk          ),
    .reset      (reset        ),
    .csr_we     (ws_csr_we    ),
    .csr_num    (ws_csr_num   ),
    .csr_wmask  (ws_csr_wmask ),
    .csr_wvalue (ws_csr_wvalue),
    .csr_rvalue (ws_csr_rvalue), 
    .ertn_flush (ws_ertn_flush),
    .wb_ex      (final_ex      ), 
    .wb_ecode   (ws_ecode     ),
    .wb_esubcode(ws_esubcode  ),
    .wb_pc      (ws_pc        ),
    .ex_entry   (ex_entry     ),
    .ex_era     (ex_era       ),
    .has_int    (has_int      ),
    .wb_vaddr   (ws_vaddr     ),
    .counter    (counter      ),
    .counter_id (counter_id   )
);



/* -------------------  Regfile Interface ------------------- */

assign rf_we    = ws_gr_we && ws_valid && ~ws_ex;
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
