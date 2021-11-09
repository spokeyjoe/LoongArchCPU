`include "mycpu.h"

module if_stage(
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
    input  [                 66:0] ws_to_fs_bus,
    input  [`ES_FORWARD_WD   -1:0] es_forward,
    input  [`MS_FORWARD_WD   -1:0] ms_forward,
    input  [`WS_FORWARD_WD   -1:0] ws_forward,
    input                          back_ertn_flush,
    input                          back_ex,
    output [                  1:0] inst_sram_size,//0: 1bytes; 1: 2bytes; 2: 4bytes
    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    output                         inst_sram_wr
);

// Handshake signals
reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        ps_ready_go;

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



// Branch bus
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

// Handshake signals
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

// pre-IF stage
// assign ps_ready_go    = final_ex || ertn_flush || ~adef_ex;
assign to_fs_valid    = ~reset && ps_ready_go || adef_ex;//lab10

// IF stage

assign fs_ready_go    = (inst_sram_data_ok || fs_inst_buf_valid) && ~final_ex && ~fs_abandon || adef_ex;//~cancel; //lab10
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin || final_ex;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~br_taken;

// PC
assign seq_pc       = fs_pc + 32'h4;
assign nextpc       = final_ex ? (~ertn_flush ? ex_entry : ex_era):(br_taken ? br_target : seq_pc);
assign final_nextpc = final_ex ?                          nextpc :
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
//reg        cancel;
reg        br_taken_buf;
reg [31:0] nextpc_buf;
reg        ex_buf_valid;
reg        fs_abandon;
reg mid_handshake;

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
    else if(inst_sram_data_ok && ~ds_allowin) begin
        fs_inst_buf_valid <= 1'b1;
    end
    else if(fs_ready_go && ds_allowin) begin
        fs_inst_buf_valid <= 1'b0;
    end
end
/*
always@(posedge clk) begin
    if(reset) begin
        cancel <= 1'b0;
    end
    else if(inst_sram_data_ok) begin
        cancel <= 1'b0;
    end 
    else if(final_ex && ~fs_ex && ~(inst_sram_req && inst_sram_addr_ok)) begin
        cancel <= 1'b1;
    end
end
*/
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

assign inst_sram_size = 2'b10;
// Sram interface
assign inst_sram_req    = fs_allowin && ~adef_ex && ~br_stall && ~mid_handshake;  //req
assign inst_sram_wstrb  = 4'h0;  //wstrb
assign inst_sram_addr   = final_nextpc;
assign inst_sram_wdata  = 32'b0;
assign inst_sram_wr     = 1'b0;
// Exception
assign fs_esubcode     = adef_ex ? `ESUBCODE_ADEF : 1'b0;
assign fs_ecode        = adef_ex ? `ECODE_ADE : 6'b0;
assign fs_ex           = adef_ex;
assign adef_ex         = ~(final_nextpc[1:0] == 2'b00);


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

assign  {has_int,   //66
         ex_era,    //65:34
         ex_entry,  //33:2
         final_ex,  //1
         ertn_flush //0
        } = ws_to_fs_bus;

assign {br_stall,br_taken,br_target} = br_bus;

assign fs_inst         = adef_ex ? {11'b0, 1'b1, 20'b0} : 
                         fs_inst_buf_valid ? fs_inst_buf : inst_sram_rdata;

assign fs_to_ds_bus = {fs_esubcode ,  //71
                       fs_ecode    ,  //70:65
                       fs_ex       ,  //64
                       fs_inst     ,  //63:32
                       fs_pc          //31:0
                       };

endmodule
