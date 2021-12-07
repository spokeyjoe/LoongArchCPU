`include "mycpu.h"
module cpu_core
#(
    parameter TLBNUM = 16
)
(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    output [ 1:0] inst_sram_size,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    output        inst_sram_wr,
    // data sram interface
    output        data_sram_req,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    output [ 1:0] data_sram_size,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    output        data_sram_wr,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn; 

wire                         ds_allowin;
wire                         es_allowin;
wire                         ms_allowin;
wire                         ws_allowin;
wire                         fs_to_ds_valid;
wire                         ds_to_es_valid;
wire                         es_to_ms_valid;
wire                         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`WS_TO_ES_BUS_WD -1:0] ws_to_es_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`ES_FORWARD_WD   -1:0] es_forward;
wire [`MS_FORWARD_WD   -1:0] ms_forward;
wire [`WS_FORWARD_WD   -1:0] ws_forward;
//wire                         es_valid;
wire                         final_ex;
wire [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus;
wire                         back_ertn_flush;
wire                         back_ex;
wire [63                 :0] counter;
wire                         ms_ertn_flush;
wire                         ms_to_es_valid;
wire                         ms_to_es_ex;
wire                         es_ex_detected_to_fs;
wire                         ms_ex_detected;
// tlb
wire [              18:0]    s0_vppn;
wire                         s0_va_bit12;
wire [               9:0]    s0_asid;
wire                         s0_found;
wire [$clog2(TLBNUM)-1:0]    s0_index;
wire [              19:0]    s0_ppn;
wire [               5:0]    s0_ps;
wire [               1:0]    s0_plv;
wire [               1:0]    s0_mat;
wire                         s0_d;
wire                         s0_v;
wire  [              18:0]   s1_vppn;
wire                         s1_va_bit12;
wire  [               9:0]   s1_asid;
wire                         s1_found;
wire [$clog2(TLBNUM)-1:0]    s1_index;
wire [              19:0]    s1_ppn;
wire [               5:0]    s1_ps;
wire [               1:0]    s1_plv;
wire [               1:0]    s1_mat;
wire                         s1_d;
wire                         s1_v;
wire  [               4:0]   invtlb_op;
wire                         inst_invtlb;
wire                         we;
wire  [$clog2(TLBNUM)-1:0]   w_index;
wire                         w_e;
wire  [               5:0]   w_ps;
wire  [              18:0]   w_vppn;
wire  [               9:0]   w_asid;
wire                         w_g;
wire  [              19:0]   w_ppn0;
wire  [               1:0]   w_plv0;
wire  [               1:0]   w_mat0;
wire                         w_d0;
wire                         w_v0;
wire  [              19:0]   w_ppn1;
wire  [               1:0]   w_plv1;
wire  [               1:0]   w_mat1;
wire                         w_d1;
wire                         w_v1;
wire  [$clog2(TLBNUM)-1:0]   r_index;
wire                         r_e;
wire [              18:0]    r_vppn;
wire [               5:0]    r_ps;
wire [               9:0]    r_asid;
wire                         r_g;
wire [              19:0]    r_ppn0;
wire [               1:0]    r_plv0;
wire [               1:0]    r_mat0;
wire                         r_d0;
wire                         r_v0;
wire [              19:0]    r_ppn1;     
wire [               1:0]    r_plv1;
wire [               1:0]    r_mat1;
wire                         r_d1;
wire                         r_v1;
wire                         inst_tlbsrch;
wire                         inst_tlbrd;
wire                         inst_tlbfill;
wire                         inst_tlbwr;
wire [              97:0]    csr_tlb_in;
wire [              97:0]    csr_tlb_out;
assign csr_tlb_in = {//es_valid,    //96
                     inst_tlbwr,  //97
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
                    };
assign {we,     //97
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
       } = csr_tlb_out;

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req   (inst_sram_req   ),
    .inst_sram_wstrb (inst_sram_wstrb ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .ws_to_fs_bus   (ws_to_fs_bus   ),
    .es_forward     (es_forward     ),
    .ms_forward     (ms_forward     ),
    .ws_forward     (ws_forward     ),
    .back_ertn_flush(back_ertn_flush),
    .back_ex        (back_ex        ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_wr   (inst_sram_wr   ),
    .es_ex_detected_to_fs(es_ex_detected_to_fs),
    .ms_ex_detected (ms_ex_detected ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
 
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .es_forward     (es_forward     ),
    .ms_forward     (ms_forward     ),
    .ws_forward     (ws_forward     ),
    .back_ertn_flush(back_ertn_flush),
    .back_ex        (back_ex        )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .final_ex       (final_ex       ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
 //   .es_valid       (es_valid       ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_req  (data_sram_req   ),
    .data_sram_wstrb(data_sram_wstrb  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .es_forward     (es_forward     ),
    .ms_ertn_flush  (ms_ertn_flush  ),
    .ms_to_es_valid (ms_to_es_valid ),
    // counter from ws
    .es_counter     (counter        ),
    .back_ertn_flush(back_ertn_flush),
    .back_ex        (back_ex        ),
    .data_sram_size (data_sram_size ),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_wr   (data_sram_wr   ),
    .ms_to_es_ex    (ms_to_es_ex    ),
    .es_ex_detected_to_fs(es_ex_detected_to_fs),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
 //   .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_op     (invtlb_op      ),
    .inst_tlbsrch  (inst_tlbsrch   ),
    .inst_tlbrd    (inst_tlbrd     ),
    .inst_tlbwr    (inst_tlbwr     ),
    .inst_tlbfill  (inst_tlbfill   ),
    .inst_invtlb   (inst_invtlb    ),
    .ws_to_es_bus  (ws_to_es_bus   )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    .final_ex       (final_ex       ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .ms_forward     (ms_forward     ),
    .back_ertn_flush(back_ertn_flush),
    .ms_ertn_flush  (ms_ertn_flush  ),
    .ms_to_es_valid (ms_to_es_valid ),
    .back_ex        (back_ex        ),
    .ms_to_es_ex    (ms_to_es_ex    ),
    .ms_ex_detected (ms_ex_detected )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .final_ex       (final_ex       ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_forward       (ws_forward       ),
    .ws_to_fs_bus     (ws_to_fs_bus     ),
    //counter
    .counter          (counter          ),
    .back_ertn_flush  (back_ertn_flush  ),
    .back_ex          (back_ex          ),
    // tlb
    .csr_tlb_out      (csr_tlb_out      ),
    .csr_tlb_in       (csr_tlb_in       ),
    .ws_to_es_bus     (ws_to_es_bus     )
);
// tlb
tlb tlb(
    .clk           (clk            ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_op     (invtlb_op      ),
    .inst_invtlb   (inst_invtlb    ),
    // write port
    .we            (we             ),
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);
endmodule
