module cache (
    input         clk_g,
    input         resetn,
    // CPU Interface
    input         valid,
    input         op,     //1: write, 0: read
    input  [ 7:0] index,
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

wire write_idle  = write_buffer_state == WRITE_BUFFER_IDLE;
wire write_write = write_buffer_state == WRITE_BUFFER_WRITE;
/*-------------------- Dirty Bit Table --------------------*/
reg [255:0] D_way0;
reg [255:0] D_way1;

wire [7:0] dirty_index;

/*-------------------- Cache RAM Interface --------------------*/

wire [ 7:0] tagv_way0_addr;
wire [20:0] tagv_way0_wdata;
wire [20:0] tagv_way0_rdata;
wire        tagv_way0_wen;
wire [ 7:0] tagv_way1_addr;
wire [20:0] tagv_way1_wdata;
wire [20:0] tagv_way1_rdata;
wire        tagv_way1_wen;

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

TAGV_RAM tagv_way0(
    .addra(tagv_way0_addr),
    .clka(clk_g),
    .dina(tagv_way0_wdata),
    .douta(tagv_way0_rdata),
    .wea(tagv_way0_wen)
    );
TAGV_RAM tagv_way1(
    .addra(tagv_way1_addr),
    .clka(clk_g),
    .dina(tagv_way1_wdata),
    .douta(tagv_way1_rdata),
    .wea(tagv_way1_wen)
    );
BANK_RAM bank0_way0(
    .addra(bank0_way0_addr),
    .clka(clk_g),
    .dina(bank0_way0_wdata),
    .douta(bank0_way0_rdata),
    .wea(bank0_way0_wen)
    );
BANK_RAM bank1_way0(
    .addra(bank1_way0_addr),
    .clka(clk_g),
    .dina(bank1_way0_wdata),
    .douta(bank1_way0_rdata),
    .wea(bank1_way0_wen)
    );
BANK_RAM bank2_way0(
    .addra(bank2_way0_addr),
    .clka(clk_g),
    .dina(bank2_way0_wdata),
    .douta(bank2_way0_rdata),
    .wea(bank2_way0_wen)
    );
BANK_RAM bank3_way0(
    .addra(bank3_way0_addr),
    .clka(clk_g),
    .dina(bank3_way0_wdata),
    .douta(bank3_way0_rdata),
    .wea(bank3_way0_wen)
    );
BANK_RAM bank0_way1(
    .addra(bank0_way1_addr),
    .clka(clk_g),
    .dina(bank0_way1_wdata),
    .douta(bank0_way1_rdata),
    .wea(bank0_way1_wen)
    );
BANK_RAM bank1_way1(
    .addra(bank1_way1_addr),
    .clka(clk_g),
    .dina(bank1_way1_wdata),
    .douta(bank1_way1_rdata),
    .wea(bank1_way1_wen)
    );
BANK_RAM bank2_way1(
    .addra(bank2_way1_addr),
    .clka(clk_g),
    .dina(bank2_way1_wdata),
    .douta(bank2_way1_rdata),
    .wea(bank2_way1_wen)
    );
BANK_RAM bank3_way1(
    .addra(bank3_way1_addr),
    .clka(clk_g),
    .dina(bank3_way1_wdata),
    .douta(bank3_way1_rdata),
    .wea(bank3_way1_wen)
    );

/*-------------------- Bank Selection --------------------*/
wire wr_bank0_hit;
wire wr_bank1_hit;
wire wr_bank2_hit;
wire wr_bank3_hit;


/*-------------------- Request Buffer --------------------*/

reg        rq_op_r;
reg [ 7:0] rq_index_r;
reg [19:0] rq_tag_r;
reg [ 3:0] rq_offset_r;
reg [ 3:0] rq_wstrb_r;
reg [31:0] rq_wdata_r;

/*-------------------- Write Buffer --------------------*/
reg        wr_way_r;
reg [19:0] wr_tag_r;
reg [ 1:0] wr_bank_r;
reg [ 7:0] wr_index_r;
reg [ 3:0] wr_wstrb_r;
reg [31:0] wr_wdata_r;
reg [ 3:0] wr_offset_r;

/*-------------------- Tag Compare --------------------*/

wire hit_way;
wire way0_hit;
wire way1_hit;

wire wr_way0_hit;
wire wr_way1_hit;

wire cache_hit;


/*-------------------- Data Select --------------------*/

wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;
wire [127:0] replace_data;
wire [ 19:0] replace_tag;
reg  [127:0] replace_data_r;
reg  [ 19:0] replace_tag_r;
wire replace_way;

/*-------------------- Miss Buffer --------------------*/

reg rq_replace_way_r;
reg [1:0] num_ret_data;
// Generate a pseudo random number to choose **replaced way**
assign replace_way = rq_replace_way_r;

/*-------------------- LFSR --------------------*/
reg [22:0] pseudo_random_23;

/*-------------------- Cache rdata --------------------*/
wire          way0_v;
wire          way1_v;
wire  [ 19:0] way0_tag;
wire  [ 19:0] way1_tag;
wire  [127:0] way0_data;
wire  [127:0] way1_data;

assign way0_v = tagv_way0_rdata[0];
assign way1_v = tagv_way1_rdata[0];
assign way0_tag = tagv_way0_rdata[20:1];
assign way1_tag = tagv_way1_rdata[20:1];
assign way0_data= {bank3_way0_rdata, bank2_way0_rdata,
                   bank1_way0_rdata, bank0_way0_rdata
                  };
assign way1_data= {bank3_way1_rdata, bank2_way1_rdata,
                   bank1_way1_rdata, bank0_way1_rdata
                  };

/*-------------------- Tag Compare --------------------*/
assign way0_hit = way0_v && (way0_tag == rq_tag_r);
assign way1_hit = way1_v && (way1_tag == rq_tag_r);

assign wr_way0_hit = way0_v && (way0_tag == wr_tag_r);
assign wr_way1_hit = way1_v && (way1_tag == wr_tag_r);
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
            if(valid) begin
                main_next_state = MAIN_LOOKUP; 
            end
            else begin
                main_next_state = MAIN_IDLE;
            end
        end
        MAIN_LOOKUP: begin
            if (cache_hit && ~valid) begin
              main_next_state = MAIN_IDLE;
            end
            else if (cache_hit && valid) begin
              main_next_state = MAIN_LOOKUP;
            end
            else begin
              main_next_state = MAIN_MISS;
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
wire hit_write = main_lookup && cache_hit && rq_op_r;

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

/*-------------------- NOT IDLE STATE --------------------*/
reg not_idle;

always @(posedge clk_g) begin
    if (~resetn) begin
        not_idle <= 1'b0;        
    end
    else if (not_idle && data_ok) begin
        not_idle <= 1'b0;
    end
    else if (main_idle && valid) begin
        not_idle <= 1'b1;
    end
end

/*-------------------- Bank Selection --------------------*/

assign wr_bank0_hit = wr_offset_r[3:2] == 2'b00;
assign wr_bank1_hit = wr_offset_r[3:2] == 2'b01;
assign wr_bank2_hit = wr_offset_r[3:2] == 2'b10;
assign wr_bank3_hit = wr_offset_r[3:2] == 2'b11;

/*-------------------- Dirty Bit Table --------------------*/

assign dirty_index = not_idle ? rq_index_r :
                     valid    ? index      :
                                8'b0;

always @ (posedge clk_g) begin
    if(!resetn) begin
        D_way0 <= 256'b0;
        D_way1 <= 256'b0;
    end 
    else if(main_lookup && rq_op_r)begin
        if(way0_hit)
            D_way0[dirty_index] <= 1'b1;
        else if(way1_hit)
            D_way1[dirty_index] <= 1'b1;
    end  
    else if(main_refill)begin
        if(replace_way == 0)
            D_way0[dirty_index] <= rq_op_r;
        else
            D_way1[dirty_index] <= rq_op_r;
    end
end

/*-------------------- Request Buffer --------------------*/
always @(posedge clk_g) begin
    if (~resetn) begin
        rq_op_r     <= 1'b0;
        rq_index_r  <= 8'b0;
        rq_tag_r    <= 20'b0;
        rq_offset_r <= 4'b0;
        rq_wstrb_r  <= 4'b0;
        rq_wdata_r  <= 32'b0;
    end
    else if (main_idle && main_next_state == MAIN_LOOKUP || 
        main_lookup && main_next_state == MAIN_LOOKUP) begin //only in these conditions, request can be accepted
        rq_op_r          <= op;
        rq_index_r       <= index;
        rq_tag_r         <= tag;
        rq_offset_r      <= offset;
        rq_wstrb_r       <= wstrb;
        rq_wdata_r       <= wdata;
        rq_replace_way_r <= pseudo_random_23[0];
    end
end

/*-------------------- LFSR --------------------*/
always @ (posedge clk_g) begin
   if (~resetn)
       pseudo_random_23 <= {7'b1010101,16'h00FF};
   else
       pseudo_random_23 <= {pseudo_random_23[21:0], pseudo_random_23[22] ^ pseudo_random_23[17]};
end

/*-------------------- Miss Buffer --------------------*/
always @(posedge clk_g) begin
    if (!resetn)
        num_ret_data <= 2'b00;
    else if (ret_last && ret_valid)
        num_ret_data <= 2'b00;
    else if (ret_valid)
        num_ret_data <= num_ret_data + 1'b1;
end

/*-------------------- Data Select --------------------*/
assign way0_load_word  = way0_data[rq_offset_r[3:2]*32 +: 32];
assign way1_load_word  = way1_data[rq_offset_r[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word |
                  {32{way1_hit}} & way1_load_word;

assign replace_data   = replace_way ? way1_data : way0_data;
assign replace_tag    = replace_way ? way1_tag  : way0_tag;

always @(posedge clk_g) begin
    if (main_lookup & main_next_state == MAIN_MISS) begin
        replace_tag_r  <= replace_tag;
        replace_data_r <= replace_data;//!!not used, write buffer not yet finished now
    end
end

/*-------------------- Write Buffer --------------------*/
always @(posedge clk_g) begin
    if (main_lookup && hit_write) begin
        wr_tag_r   <= rq_tag_r;
        wr_way_r   <= hit_way;
        wr_bank_r  <= rq_offset_r[3:2];
        wr_index_r <= rq_index_r;
        wr_wstrb_r <= rq_wstrb_r;
        wr_wdata_r <= rq_wdata_r;
        wr_offset_r <= rq_offset_r;
    end
end

/*-------------------- CPU Interface --------------------*/

assign rdata = main_lookup              ? load_res :
               main_refill && ret_valid ? rq_wdata_r : 
                                          32'b0;
assign addr_ok = main_idle   && main_next_state == MAIN_LOOKUP ||
                 main_lookup && main_next_state == MAIN_LOOKUP;
assign data_ok = main_lookup && main_next_state == MAIN_IDLE   ||
                 main_lookup && main_next_state == MAIN_LOOKUP ||
                 main_refill && ret_valid && num_ret_data == rq_offset_r[3:2];

/*-------------------- AXI Interface --------------------*/

assign rd_req = main_replace;
assign rd_type = 3'b100;
assign rd_addr = {rq_tag_r, rq_index_r, 4'b0000};

reg wr_req_r;

// Replaced Cache block is dirty
// It's real *natural* language programming LOL
wire replaced_cache_is_dirty = D_way0[dirty_index] && ~replace_way ||
                               D_way1[dirty_index] && replace_way;

always @(posedge clk_g) begin
    if (~resetn) begin
        wr_req_r <= 1'b0;        
    end
    else if (main_miss && replaced_cache_is_dirty && wr_req_r == 1'b0) begin
        wr_req_r <= 1'b1;
    end
    else if (wr_rdy && wr_req)
        wr_req_r <= 1'b0;
end

assign wr_req = wr_req_r;
assign wr_type = 3'b100;
assign wr_addr = {replace_tag_r, rq_index_r, 4'b0000};
assign wr_data = replace_data;
assign wr_wstrb = 4'hf;

assign tagv_way0_addr = write_write                    ? wr_index_r : 
                        main_next_state == MAIN_LOOKUP ? index : rq_index_r;
                        /*not_idle ? rq_index_r :
                        valid    ? index      :
                                   8'b0;*///???
assign tagv_way1_addr  = tagv_way0_addr;
assign tagv_way0_wen   = main_refill && ~replace_way || write_write && ~wr_way_r;
assign tagv_way1_wen   = main_refill && replace_way  || write_write && wr_way_r;
assign tagv_way0_wdata = write_write ? {way0_tag, 1'b1} : {rq_tag_r, 1'b1};
assign tagv_way1_wdata = write_write ? {way1_tag, 1'b1} : {rq_tag_r, 1'b1};

assign bank0_way0_addr = write_write                    ? wr_index_r :
                         main_next_state == MAIN_LOOKUP ? index      :
                                                          rq_index_r;
assign bank1_way0_addr = bank0_way0_addr;
assign bank2_way0_addr = bank0_way0_addr;
assign bank3_way0_addr = bank0_way0_addr;
assign bank0_way1_addr = bank0_way0_addr;
assign bank1_way1_addr = bank0_way0_addr;
assign bank2_way1_addr = bank0_way0_addr;
assign bank3_way1_addr = bank0_way0_addr;

assign bank0_way0_wen  = (write_write && wr_way0_hit && wr_bank0_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b00 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank1_way0_wen  = (write_write && wr_way0_hit && wr_bank1_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b01 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank2_way0_wen  = (write_write && wr_way0_hit && wr_bank2_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b10 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank3_way0_wen  = (write_write && wr_way0_hit && wr_bank3_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b11 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank0_way1_wen  = (write_write && wr_way1_hit && wr_bank0_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b00 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank1_way1_wen  = (write_write && wr_way1_hit && wr_bank1_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b01 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank2_way1_wen  = (write_write && wr_way1_hit && wr_bank2_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b10 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank3_way1_wen  = (write_write && wr_way1_hit && wr_bank3_hit) ? wr_wstrb_r : 
                         (main_refill && num_ret_data == 2'b11 && ret_valid && replace_way) ? 4'hf : 4'h0;

wire [31:0] refill_data = {32{rq_wstrb_r == 4'b0000}} & ret_data                            |
                          {32{rq_wstrb_r == 4'b0001}} & {ret_data[31:8], rq_wdata_r[7:0]}   |
                          {32{rq_wstrb_r == 4'b0011}} & {ret_data[31:16], rq_wdata_r[15:0]} |
                          {32{rq_wstrb_r == 4'b0111}} & {ret_data[31:24], rq_wdata_r[23:0]} |
                          {32{rq_wstrb_r == 4'b1111}} & rq_wdata_r                          |
                          {32{rq_wstrb_r == 4'b1110}} & {rq_wdata_r[31:8], ret_data[7:0]}   |
                          {32{rq_wstrb_r == 4'b1100}} & {rq_wdata_r[31:16], ret_data[15:0]} |
                          {32{rq_wstrb_r == 4'b1000}} & {rq_wdata_r[31:24], ret_data[23:0]};

assign bank0_way0_wdata = write_write && ~wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b00) ? refill_data : ret_data : 32'b0;
assign bank1_way0_wdata = write_write && ~wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b01) ? refill_data : ret_data : 32'b0;
assign bank2_way0_wdata = write_write && ~wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b10) ? refill_data : ret_data : 32'b0;
assign bank3_way0_wdata = write_write && ~wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b11) ? refill_data : ret_data : 32'b0;
assign bank0_way1_wdata = write_write && wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b00) ? refill_data : ret_data : 32'b0;
assign bank1_way1_wdata = write_write && wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b01) ? refill_data : ret_data : 32'b0;
assign bank2_way1_wdata = write_write && wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b10) ? refill_data : ret_data : 32'b0;
assign bank3_way1_wdata = write_write && wr_way_r ? wr_wdata_r :
                          main_refill ? (rq_offset_r[3:2] == 2'b11) ? refill_data : ret_data : 32'b0;
endmodule