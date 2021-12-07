`include "mycpu.h"

module if_stage#(
    parameter TLBNUM = 16
)
(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output                         inst_sram_req  ,
    output [                  3:0] inst_sram_wstrb,
    output [                 31:0] inst_sram_addr ,
    output [                 31:0] inst_sram_wdata,
    input  [                 31:0] inst_sram_rdata,
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus,
    input  [`ES_FORWARD_WD   -1:0] es_forward,
    input  [`MS_FORWARD_WD   -1:0] ms_forward,
    input  [`WS_FORWARD_WD   -1:0] ws_forward,
    input                          back_ertn_flush,
    input                          back_ex,
    output [                  1:0] inst_sram_size,//0: 1bytes; 1: 2bytes; 2: 4bytes
    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    output                         inst_sram_wr,
    input                          es_ex_detected_to_fs,
    input                          ms_ex_detected,
    // search port 0 (for fetch)
    output [              18:0] s0_vppn,
    output                      s0_va_bit12,
    output [               9:0] s0_asid,
    input                       s0_found,
    input  [$clog2(TLBNUM)-1:0] s0_index,
    input  [              19:0] s0_ppn,
    input  [               5:0] s0_ps,
    input  [               1:0] s0_plv,
    input  [               1:0] s0_mat,
    input                       s0_d,
    input                       s0_v  
);

// Handshake signals
reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        ps_ready_go;

wire        tlb_reflush;
wire [31:0] refetch_pc;
// PC 
wire [31:0] seq_pc;
wire [31:0] nextpc;
reg  [31:0] fs_pc;
wire [31:0] final_nextpc;
// Ws to fs bus
wire [31:0] ex_entry;
wire        final_ex;
wire [31:0] ex_era;
wire has_int;
wire ertn_flush;

wire fs_tlb_refetch;

// Branch bus
wire         fs_ex_detected;
wire         br_taken;
wire [ 31:0] br_target;
wire         br_stall;      
// Fs to ds bus                      
wire [31:0] fs_inst;

// Exception
wire        fs_esubcode;
wire [ 5:0] fs_ecode;  
wire        fs_ex;
wire        adef_ex;
wire        fs_tlb_refill_ex;
wire        fs_tlb_invalid_ex;
wire        fs_tlb_ppe_ex;
wire        refill_ex;
// Handshake signals
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

/*-------------------- Address translation --------------------*/
wire [31:0] vaddr;
wire [31:0] paddr;
wire [19:0] vpn         = vaddr[31:12];
wire [21:0] offset      = vaddr[21:0];

wire dmw_hit = dmw0_hit || dmw1_hit;
wire dmw0_hit;
wire dmw1_hit;
wire [31:0] dmw_addr;
wire [31:0] tlb_addr;

wire [31:0] csr_asid_rvalue;
wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;
wire [31:0] csr_tlbrentry_rvalue;

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


// pre-IF stage
// assign ps_ready_go    = final_ex || ertn_flush || ~adef_ex;
assign to_fs_valid    = ~reset && ps_ready_go || fs_ex;//lab10

// IF stage

assign fs_ready_go    = (inst_sram_data_ok || fs_inst_buf_valid) && ~final_ex && ~fs_abandon || fs_ex;//~cancel; //lab10
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin || final_ex;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~br_taken;

// PC
assign seq_pc       = fs_pc + 32'h4;
assign nextpc       = refill_ex ? csr_tlbrentry_rvalue : 
                      final_ex & ~refill_ex ? (~ertn_flush ? ex_entry : ex_era) : 
                      (br_taken ? br_target : seq_pc);
assign final_nextpc = refill_ex ?           csr_tlbrentry_rvalue :
                      tlb_reflush ?                   refetch_pc :
                      final_ex & ~refill_ex?              nextpc :
                      (br_taken_buf | ex_buf_valid) ? nextpc_buf : 
                                                          nextpc;

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= final_nextpc;
    end
end

/* -------------------  lab 10 ------------------- */
assign ps_ready_go = inst_sram_req && inst_sram_addr_ok;//????fs_ex

reg [31:0] fs_inst_buf;
reg        fs_inst_buf_valid;
reg        br_taken_buf;
reg [31:0] nextpc_buf;
reg        ex_buf_valid;
reg        fs_abandon;
reg        mid_handshake;

always @(posedge clk) begin
    if(reset) begin
        fs_inst_buf <= 32'b0; 
    end
    else if(inst_sram_data_ok && ~ds_allowin) begin
        fs_inst_buf <= inst_sram_rdata;
    end
end

always @(posedge clk) begin
    if(reset) begin
        fs_inst_buf_valid <= 1'b0;
    end
    else if(fs_ready_go && ds_allowin || final_ex) begin
        fs_inst_buf_valid <= 1'b0;
    end
    else if(inst_sram_data_ok && ~ds_allowin) begin
        fs_inst_buf_valid <= 1'b1;
    end
end

always @(posedge clk)begin
    if(reset) begin
        br_taken_buf <= 1'b0;
    end
    else if(br_taken_buf && inst_sram_req && inst_sram_addr_ok && fs_allowin) begin
        br_taken_buf <= 1'b0;
    end 
    else if(br_taken && ~br_stall && ~(inst_sram_req && inst_sram_addr_ok)) begin
        br_taken_buf <= br_taken;
    end
end

always @(posedge clk) begin
    if(reset) begin
        ex_buf_valid <= 1'b0;
    end
    else if(ex_buf_valid && inst_sram_req && inst_sram_addr_ok && fs_allowin) begin
        ex_buf_valid <= 1'b0;
    end
    else if(final_ex && ~(inst_sram_req && inst_sram_addr_ok)) begin
        ex_buf_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        nextpc_buf <= 32'b0;
    end
    else if(br_taken && ~br_stall || final_ex) begin
        nextpc_buf <= nextpc;
    end
end

always @(posedge clk) begin
    if(reset) begin
        fs_abandon <= 1'b0;
    end
    else if(inst_sram_data_ok) begin
        fs_abandon <= 1'b0;
    end
    else if(final_ex && (~fs_allowin && ~fs_ready_go)) begin
        fs_abandon <= 1'b1;
    end
end

assign inst_sram_size  = 2'b10;
// Sram interface
assign inst_sram_req   = fs_allowin && ~fs_ex && ~br_stall && ~mid_handshake 
                        && ~fs_ex_detected && ~es_ex_detected_to_fs && ~ms_ex_detected;  //req
assign inst_sram_wstrb = 4'h0;  //wstrb
assign inst_sram_addr  = paddr;
assign inst_sram_wdata = 32'b0;
assign inst_sram_wr    = 1'b0;
// Exception
assign fs_esubcode     = adef_ex ? `ESUBCODE_ADEF : 1'b0;
assign fs_ecode        = adef_ex ? `ECODE_ADE :
                         fs_tlb_refill_ex ? `ECODE_TLBR : 
                         fs_tlb_invalid_ex ? `ECODE_PIF  : 
                         fs_tlb_ppe_ex ? `ECODE_PPE : 6'b0;
assign fs_ex           = adef_ex | fs_tlb_invalid_ex | fs_tlb_ppe_ex | fs_tlb_refill_ex;
assign adef_ex         = ~(final_nextpc[1:0] == 2'b00 && final_nextpc[31] == 1'b0);


// Waiting for response state
// This state will occur after first handshake occurs
// and will disappear when second handshake arrives

always @(posedge clk) begin
    if (reset)
        mid_handshake <= 1'b0;
    else if (inst_sram_data_ok)
        mid_handshake <= 1'b0;
    else if (inst_sram_req && inst_sram_addr_ok)
        mid_handshake <= 1'b1;
end

assign  {refill_ex, //260
         csr_tlbrentry_rvalue, //259:228
         csr_asid_rvalue, //227:196
         csr_crmd_rvalue, //195:164
         csr_dmw0_rvalue, //163:132
         csr_dmw1_rvalue, //131:100
         tlb_reflush,//99
         refetch_pc,//98:67
         has_int,   //66
         ex_era,    //65:34
         ex_entry,  //33:2
         final_ex,  //1
         ertn_flush //0
        } = ws_to_fs_bus;

assign {fs_tlb_refetch, fs_ex_detected, br_stall,br_taken,br_target} = br_bus;

assign fs_inst         = fs_ex ? {11'b0, 1'b1, 20'b0} : 
                         fs_inst_buf_valid ? fs_inst_buf : inst_sram_rdata;

assign fs_to_ds_bus = {fs_tlb_refill_ex,//73
                       fs_tlb_refetch,//72
                       fs_esubcode ,  //71
                       fs_ecode    ,  //70:65
                       fs_ex       ,  //64
                       fs_inst     ,  //63:32
                       fs_pc          //31:0
                       };

/*-------------------- Address translation --------------------*/
assign vaddr = final_nextpc;

// TLB
assign s0_vppn = vpn[19:1];
assign s0_va_bit12 = vpn[0];
assign s0_asid = csr_asid_asid;

assign tlb_addr = (s0_ps == 6'd12) ? {s0_ppn[19:0], offset[11:0]} :
                                     {s0_ppn[19:10], offset[21:0]};


assign da_hit = (csr_crmd_da == 1) && (csr_crmd_pg == 0);

// DMW
assign dmw0_hit = (csr_crmd_plv == 2'b00 && csr_dmw0_plv0   ||
                   csr_crmd_plv == 2'b11 && csr_dmw0_plv3 ) && (vaddr[31:29] == csr_dmw0_vseg); 
assign dmw1_hit = (csr_crmd_plv == 2'b00 && csr_dmw1_plv0   ||
                   csr_crmd_plv == 2'b11 && csr_dmw1_plv3 ) && (vaddr[31:29] == csr_dmw1_vseg); 

assign dmw_addr = {32{dmw0_hit}} & {csr_dmw0_vseg, vaddr[28:0]} |
                  {32{dmw1_hit}} & {csr_dmw1_vseg, vaddr[28:0]};

// PADDR
assign paddr = da_hit  ? vaddr    :
               dmw_hit ? dmw_addr :
                         tlb_addr;

assign fs_tlb_refill_ex  = ~da_hit & ~dmw_hit & ~s0_found;
assign fs_tlb_invalid_ex = ~da_hit & ~dmw_hit & s0_found & ~s0_v;
assign fs_tlb_ppe_ex     = ~da_hit & ~dmw_hit & csr_crmd_plv == 2'b11 && s0_plv == 2'b00;

endmodule
