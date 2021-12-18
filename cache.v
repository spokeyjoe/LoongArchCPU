module cache (
    input         clk_g,
    input         resetn,
    // CPU Interface
    input         valid,
    input         op,     //1: write, 0: read
    input  [ 8:0] index,
    input  [19:0] tag,
    input  [ 3:0] offset,
    input  [ 3:0] wstrb,
    input  [31:0] wdata,
    output        addr_ok,
    output        data_ok,
    output [31:0] rdata,

    // AXI Interface
    output         rd_req,
    output [  2:0] rd_type,
    output [ 31:0] rd_addr,
    input          rd_rdy,
    input          ret_valid,
    input          ret_last,
    input  [ 31:0] ret_data,
    output         wr_req,
    output [  2:0] wr_type,
    output [ 31:0] wr_addr,
    output [  3:0] wr_wstrb,
    output [127:0] wr_data, 
    input          wr_rdy
);

/*-------------------- MAIN FSM --------------------*/

localparam MAIN_IDLE    = 5'b00001; 
localparam MAIN_LOOKUP  = 5'b00010;
localparam MAIN_MISS    = 5'b00100;      
localparam MAIN_REPLACE = 5'b01000;
localparam MAIN_REFILL  = 5'b10000;

reg [4:0] main_state;
reg [4:0] main_next_state;

wire main_idle    = main_state == MAIN_IDLE;
wire main_lookup  = main_state == MAIN_LOOKUP;
wire main_miss    = main_state == MAIN_MISS;
wire main_replace = main_state == MAIN_REPLACE;
wire main_refill  = main_state == MAIN_REFILL;

/*-------------------- WRITE BUFFER FSM --------------------*/

localparam WRITE_BUFFER_IDLE  = 2'b01; 
localparam WRITE_BUFFER_WRITE = 2'b10;

reg [1:0] write_buffer_state;
reg [1:0] write_buffer_next_state;


/*-------------------- Cache RAM Interface --------------------*/

wire [ 7:0] tag_v_way0_addr;
wire [20:0] tag_v_way0_wdata;
wire [20:0] tag_v_way0_rdata;
wire        tag_v_way0_wen;
wire [ 7:0] tag_v_way1_addr;
wire [20:0] tag_v_way1_wdata;
wire [20:0] tag_v_way1_rdata;
wire        tag_v_way1_wen;

wire [ 7:0] bank0_way0_addr;
wire [31:0] bank0_way0_wdata;
wire [31:0] bank0_way0_rdata;
wire [ 3:0] bank0_way0_wen;
wire [ 7:0] bank1_way0_addr;
wire [31:0] bank1_way0_wdata;
wire [31:0] bank1_way0_rdata;
wire [ 3:0] bank1_way0_wen;
wire [ 7:0] bank2_way0_addr;
wire [31:0] bank2_way0_wdata;
wire [31:0] bank2_way0_rdata;
wire [ 3:0] bank2_way0_wen;
wire [ 7:0] bank3_way0_addr;
wire [31:0] bank3_way0_wdata;
wire [31:0] bank3_way0_rdata;
wire [ 3:0] bank3_way0_wen;

wire [ 7:0] bank0_way1_addr;
wire [31:0] bank0_way1_wdata;
wire [31:0] bank0_way1_rdata;
wire [ 3:0] bank0_way1_wen;
wire [ 7:0] bank1_way1_addr;
wire [31:0] bank1_way1_wdata;
wire [31:0] bank1_way1_rdata;
wire [ 3:0] bank1_way1_wen;
wire [ 7:0] bank2_way1_addr;
wire [31:0] bank2_way1_wdata;
wire [31:0] bank2_way1_rdata;
wire [ 3:0] bank2_way1_wen;
wire [ 7:0] bank3_way1_addr;
wire [31:0] bank3_way1_wdata;
wire [31:0] bank3_way1_rdata;
wire [ 3:0] bank3_way1_wen;

TAGV_RAM tag_v_way0(
    .addra(tag_v_way0_addr),
    .clka(clk_g),
    .dina(tag_v_way0_wdata),
    .douta(tag_v_way0_rdata),
    .wea(tag_v_way0_wen)
    );
TAGV_RAM tag_v_way1(
    .addra(tag_v_way1_addr),
    .clka(clk_g),
    .dina(tag_v_way1_wdata),
    .douta(tag_v_way1_rdata),
    .wea(tag_v_way1_wen)
    );
BANK_RAM bank0_way_0(
    .addra(bank0_way_0_addr),
    .clka(clk_g),
    .dina(bank0_way_0_wdata),
    .douta(bank0_way_0_rdata),
    .wea(bank0_way_0_wen)
    );
BANK_RAM bank1_way_0(
    .addra(bank1_way_0_addr),
    .clka(clk_g),
    .dina(bank1_way_0_wdata),
    .douta(bank1_way_0_rdata),
    .wea(bank1_way_0_wen)
    );
BANK_RAM bank2_way_0(
    .addra(bank2_way_0_addr),
    .clka(clk_g),
    .dina(bank2_way_0_wdata),
    .douta(bank2_way_0_rdata),
    .wea(bank2_way_0_wen)
    );
BANK_RAM bank3_way_0(
    .addra(bank3_way_0_addr),
    .clka(clk_g),
    .dina(bank3_way_0_wdata),
    .douta(bank3_way_0_rdata),
    .wea(bank3_way_0_wen)
    );
BANK_RAM bank0_way_1(
    .addra(bank0_way_1_addr),
    .clka(clk_g),
    .dina(bank0_way_1_wdata),
    .douta(bank0_way_1_rdata),
    .wea(bank0_way_1_wen)
    );
BANK_RAM bank1_way_1(
    .addra(bank1_way_1_addr),
    .clka(clk_g),
    .dina(bank1_way_1_wdata),
    .douta(bank1_way_1_rdata),
    .wea(bank1_way_1_wen)
    );
BANK_RAM bank2_way_1(
    .addra(bank2_way_1_addr),
    .clka(clk_g),
    .dina(bank2_way_1_wdata),
    .douta(bank2_way_1_rdata),
    .wea(bank2_way_1_wen)
    );
BANK_RAM bank3_way_1(
    .addra(bank3_way_1_addr),
    .clka(clk_g),
    .dina(bank3_way_1_wdata),
    .douta(bank3_way_1_rdata),
    .wea(bank3_way_1_wen)
    );

/*-------------------- Request Buffer --------------------*/

reg        rq_op_r;
reg [ 8:0] rq_index_r;
reg [19:0] rq_tag_r;
reg [ 3:0] rq_offset_r;
reg [ 3:0] rq_wstrb_r;
reg [31:0] rq_wdata_r;

/*-------------------- Write Buffer --------------------*/
reg        wr_way_r;
reg [ 1:0] wr_bank_r;
reg [ 8:0] wr_index_r;
reg [ 3:0] wr_wstrb_r;
reg [31:0] wr_wdata_r;

/*-------------------- Tag Compare --------------------*/

wire hit_way;
wire way0_hit;
wire way1_hit;
wire cache_hit;


/*-------------------- Data Select --------------------*/

wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;
wire [127:0] replace_data;

/*-------------------- Miss Buffer --------------------*/

wire replace_way = pseudo_random_23[0];

reg [1:0] num_ret_data;


/*-------------------- LFSR --------------------*/
reg [22:0] pseudo_random_23;

/*-------------------- Cache rdata --------------------*/
wire          way0_v;
wire          way1_v;
wire  [ 19:0] way0_tag;
wire  [ 19:0] way1_tag;
wire  [127:0] way0_data;
wire  [127:0] way1_data;

assign way0_v = tag_v_way0_rdata[0];
assign way1_v = tag_v_way1_rdata[0];
assign way0_tag = tag_v_way0_rdata[20:1];
assign way1_tag = tag_v_way1_rdata[20:1];
assign way0_data= {bank3_way0_rdata, bank2_way0_rdata,
                    bank1_way0_rdata, bank0_way0_rdata
                    };
assign way1_data= {bank3_way1_rdata, bank2_way1_rdata,
                    bank1_way1_rdata, bank0_way1_rdata
                    };

/*-------------------- Tag Compare --------------------*/
assign way0_hit = way0_v && (way0_tag == rq_tag_r);
assign way1_hit = way1_v && (way1_tag == rq_tag_r);
assign hit_way = way1_hit;
assign cache_hit = way0_hit || way1_hit;

/*-------------------- MAIN FSM --------------------*/

always @(posedge clk_g) begin
    if(~resetn) begin
        main_state <= MAIN_IDLE;
    end
    else begin
        main_state <= main_next_state;
    end
end

always @(*) begin
    case (main_state)
        MAIN_IDLE: begin
            if(valid && addr_ok) begin
                main_next_state = MAIN_LOOKUP; 
            end
            else begin
                main_next_state = MAIN_IDLE;
            end
        end
        MAIN_LOOKUP: begin
            if(~cache_hit) begin
              main_next_state = MAIN_MISS;
            end
            else if (cache_hit && ~valid) begin
              main_next_state = MAIN_IDLE;
            end
            else if (cache_hit && valid) begin
              main_next_state = MAIN_LOOKUP;
            end
        end
        MAIN_MISS: begin
            if(wr_rdy) begin
              main_next_state = MAIN_REPLACE;
            end
            else begin
              main_next_state = MAIN_MISS;
            end
        end
        MAIN_REPLACE: begin
            if(rd_rdy) begin
              main_next_state = MAIN_REFILL;
            end
            else begin
              main_next_state = MAIN_REPLACE;
            end
        end
        MAIN_REFILL: begin
            if(ret_valid && ret_last) begin
              main_next_state = MAIN_IDLE;
            end
            else begin
              main_next_state = MAIN_REFILL;
            end
        end
        default: 
            main_next_state = MAIN_IDLE;
    endcase
end

/*-------------------- WRITE BUFFER FSM --------------------*/

always @(posedge clk_g) begin
    if(~resetn) begin
        write_buffer_state <= WRITE_BUFFER_IDLE;
    end
    else begin
        write_buffer_state <= write_buffer_next_state;
    end
end

always @(*) begin
    case (write_buffer_state)
        WRITE_BUFFER_IDLE: begin
            if(main_lookup && hit_write) begin
              write_buffer_next_state = WRITE_BUFFER_WRITE;
            end
            else begin
              write_buffer_next_state = WRITE_BUFFER_IDLE;
            end
        end
        WRITE_BUFFER_WRITE: begin
            if(~hit_write) begin
                write_buffer_next_state = WRITE_BUFFER_IDLE;
            end
            else begin
                write_buffer_next_state = WRITE_BUFFER_WRITE;
            end
        end
    endcase
end


/*-------------------- Request Buffer --------------------*/
always @(posedge clk_g) begin
    if (main_idle && main_next_state == MAIN_LOOKUP || 
        main_lookup && main_next_state == MAIN_LOOKUP) begin //only in these conditions, request can be accepted
        rq_op_r     <= op;
        rq_index_r  <= index;
        rq_tag_r    <= tag;
        rq_offset_r <= offset;
        rq_wstrb_r  <= wstrb;
        rq_wdata_r  <= wdata;
    end
end

/*-------------------- LFSR --------------------*/
always @ (posedge clk_g) begin
   if (!resetn)
       pseudo_random_23 <= (SIMULATION == 1'b1) ? {7'b1010101,16'h00FF} : {7'b1010101,led_r_n};
   else
       pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
end

/*-------------------- Miss Buffer --------------------*/
always @(posedge clk_g) begin
    if (rd_rdy)
        num_ret_data <= 2'b00;
    else if (ret_valid)
        num_ret_data <= num_ret_data + 1;
end

/*-------------------- Data Select --------------------*/
assign way0_load_word  = way0_data[pa[3:2]*32 +: 32];
assign way1_load_word  = way1_data[pa[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word |
                         {32{way1_hit}} & way1_load_word;

assign replace_data   = replace_way ? way1_data : way0_data;

/*-------------------- Write Buffer --------------------*/
always @(posedge clk_g) begin
    if (main_lookup && hit_write) begin
        wr_way_r   <= hit_way;
        wr_bank_r  <= rq_offset_r[3:2];
        wr_index_r <= rq_index_r;
        wr_wstrb_r <= rq_wstrb_r;
        wr_wdata_r <= rq_wdata_r;
    end
end

/*-------------------- CPU Interface --------------------*/
assign rdata = main_lookup ? load_res :
               main_refill ? rq_wdata_r : 
                             32'b0;
assign addr_ok = main_idle   && main_next_state == MAIN_LOOKUP ||
                 main_lookup && main_next_state == MAIN_LOOKUP;
assign data_ok = main_lookup && main_next_state == MAIN_IDLE   ||
                 main_lookup && main_next_state == MAIN_LOOKUP ||
                 main_refill && ret_valid && ret_valid;

endmodule