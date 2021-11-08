`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    input                          final_ex      ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input                          data_sram_data_ok,

    output [57                 :0] ms_forward,
    input  back_ertn_flush,
    output ms_ertn_flush,
    output ms_to_es_valid,
    input  back_ex

);

/* --------------  Handshaking signals -------------- */

reg         ms_valid;
wire        ms_ready_go;



/* -------------------  BUS ------------------- */

// ES to MS bus
reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;



/* --------------  MEM related  -------------- */
wire        ms_op_st_w;
wire        ms_op_ld_w;
wire        ms_op_ld_b;
wire        ms_op_ld_bu;
wire        ms_op_ld_h;
wire        ms_op_ld_hu;
wire        ms_op_st_b;
wire        ms_op_st_h;
wire        ms_op_mem = ms_op_st_w || ms_op_st_h || ms_op_st_b || ms_op_ld_w || ms_op_ld_hu || ms_op_ld_h || ms_op_ld_bu || ms_op_ld_b;

wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire [1:0]  ms_addr_lowbits;
wire        addr00;
wire        addr01;
wire        addr10;
wire        addr11;
wire [7:0]  mem_byte_data;
wire [15:0] mem_halfword_data;
wire [31:0] mem_result;
wire [31:0] ms_final_result;
wire [31:0] ms_vaddr;


/* --------------  CSR instructions  -------------- */
wire [13:0] ms_csr_num;
wire        ms_csr_re;
wire [31:0] ms_csr_wmask; 
wire [31:0] ms_csr_wvalue;
wire        ms_csr_we;

wire        ms_csr_block;



/* --------------  Exceptions  -------------- */

wire        ms_inst_rdcntid;

wire        ms_ertn_flush;
wire        ms_esubcode;
wire [ 5:0] ms_ecode;
wire        ms_ex;


/* --------------  Abandon  -------------- */
reg ms_abandon;

/* --------------  Handshaking signals -------------- */
assign ms_ready_go    = ms_op_mem ? (data_sram_data_ok || data_sram_rdata_buf_valid) && ~ms_abandon : 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
    if (reset | final_ex | back_ertn_flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
end



/* -------------------  BUS ------------------- */

always @(posedge clk) begin
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

assign {ms_op_st_w     ,  //170
        ms_inst_rdcntid,  //169
        ms_ertn_flush  ,  //168
        ms_esubcode    ,  //167
        ms_ecode       ,  //166:161
        ms_ex          ,  //160
        ms_csr_re      ,  //159
        ms_csr_num     ,  //158:145
        ms_csr_wvalue  ,  //144:113
        ms_csr_wmask   ,  //112:81
        ms_csr_we      ,  //80
        ms_addr_lowbits,  //79:78
        ms_op_ld_w     ,  //77
        ms_op_ld_b     ,  //76
        ms_op_ld_bu    ,  //75
        ms_op_ld_h     ,  //74
        ms_op_ld_hu    ,  //73
        ms_op_st_b     ,  //72
        ms_op_st_h     ,  //71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

// MS to WS bus
assign ms_to_ws_bus = {ms_inst_rdcntid,  //191
                       ms_vaddr       ,  //190:159
                       ms_ertn_flush  ,  //158
                       ms_esubcode    ,  //157
                       ms_ecode       ,  //156:151
                       ms_ex          ,  //150
                       ms_csr_re      ,  //149
                       ms_csr_num     ,  //148:135
                       ms_csr_wvalue  ,  //134:103
                       ms_csr_wmask   ,  //102:71
                       ms_csr_we      ,  //70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

// MS forward bus
assign ms_forward = {ms_csr_block,
                     ms_csr_re, //56
                     ms_csr_num, //55:42
                     ms_csr_we, //41
                     ms_ertn_flush, //40
                     ms_ex&ms_to_ws_valid, //39
                     ms_final_result, //38:7
                     ms_dest , //6:2 
                     ms_gr_we, //1:1
                     ms_valid  //0:0
                    };



/* --------------  MEM read interface  -------------- */

assign ms_vaddr = ms_alu_result;

// SRAM data buffer
reg  [32:0] data_sram_rdata_buf;
reg        data_sram_rdata_buf_valid;
wire [32:0] final_data_sram_rdata;

always @(posedge clk) begin
    if (reset)
        data_sram_rdata_buf <= 32'b0;
    else if (data_sram_data_ok && ~ws_allowin)      // If data is back, WB stage do not allow in
                                                    // Then write it into buffer, wait for allowin to rise
        data_sram_rdata_buf <= data_sram_rdata;
end

always @(posedge clk) begin
    if (reset)
        data_sram_rdata_buf_valid <= 1'b0;
    else if (data_sram_data_ok && ~ws_allowin)
        data_sram_rdata_buf_valid <= 1'b1;
    else if (ms_ready_go && ws_allowin)
        data_sram_rdata_buf_valid <= 1'b0;
end

assign final_data_sram_rdata = data_sram_rdata_buf_valid ? data_sram_rdata_buf : data_sram_rdata;

// mem_byte_data mux 
assign addr00 = ms_addr_lowbits == 2'b00;
assign addr01 = ms_addr_lowbits == 2'b01;
assign addr10 = ms_addr_lowbits == 2'b10;
assign addr11 = ms_addr_lowbits == 2'b11;
assign mem_byte_data = {8{addr00}} & final_data_sram_rdata[7:0]   |
                       {8{addr01}} & final_data_sram_rdata[15:8]  |
                       {8{addr10}} & final_data_sram_rdata[23:16] |
                       {8{addr11}} & final_data_sram_rdata[31:24];

// mem_halfword_data mux
assign mem_halfword_data = {16{addr00}} & final_data_sram_rdata[15:0] |
                           {16{addr10}} & final_data_sram_rdata[31:16];
// mem_result mux
assign mem_result = {32{ms_op_ld_w}}  & final_data_sram_rdata                                 |
                    {32{ms_op_ld_b}}  & {{24{mem_byte_data[7]}}, mem_byte_data}         |
                    {32{ms_op_ld_bu}} & {24'b0, mem_byte_data}                          |
                    {32{ms_op_ld_h}}  & {{16{mem_halfword_data[15]}}, mem_halfword_data}|
                    {32{ms_op_ld_hu}} & {16'b0, mem_halfword_data};


assign ms_final_result = ms_res_from_mem ? mem_result : ms_alu_result;



/* --------------  Abandon  -------------- */
always @(posedge clk) begin
    if (reset)
        ms_abandon <= 1'b0;
    else if (ms_op_mem && data_sram_data_ok)
        ms_abandon <= 1'b0;
    else if (ms_op_mem && final_ex && (es_to_ms_valid || ~ws_allowin && ~ms_ready_go))
        ms_abandon <= 1'b1;
end

/* --------------  CSR instructions  -------------- */

assign ms_csr_block = ms_valid & ms_csr_re;

assign ms_to_es_valid = ms_valid;

endmodule
