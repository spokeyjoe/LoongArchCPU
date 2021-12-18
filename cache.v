module cache (
    input         clk_g,
    input         resetn,
    // cache 与 CPU 流水线的交互接口
    input         valid,
    input         op,//1: write, 0: read
    input  [ 8:0] index,
    input  [19:0] tag,
    input  [ 3:0] offset,
    input  [ 3:0] wstrb,
    input  [31:0] wdata,
    output        addr_ok,
    output        data_ok,
    output [31:0] rdata,

    // cache与 AXI 总线接口的交互接口
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

/*-------------------- FSM --------------------*/

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


/*-------------------- Request Buffer --------------------*/

reg        op_r;
reg [ 8:0] index_r;
reg [19:0] tag_r;
reg [ 3:0] offset_r;
reg [ 3:0] wstrb_r;
reg [31:0] wdata_r;

always @(posedge clk_g) begin
    if (main_idle && main_next_state == MAIN_LOOKUP || 
       main_lookup && main_next_state == MAIN_LOOKUP) begin //only in these conditions, request can be accepted
        op_r     <= op;
        index_r  <= index;
        tag_r    <= tag;
        offset_r <= offset;
        wstrb_r  <= wstrb;
    end
end

/*-------------------- Tag Compare --------------------*/

wire way0_hit;
wire way1_hit;
wire cache_hit;

assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag);
assign cache_hit = way0_hit || way1_hit;

/*-------------------- Data Select --------------------*/

wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;
wire [127:0] replace_data;

assign way0_load_word = way0_data[pa[3:2]*32 +: 32];
assign way1_load_word = way1_data[pa[3:2]*32 +: 32];
assign load_res       = {32{way0_hit}} & way0_load_word
                       |{32{way1_hit}} & way1_load_word;
assign replace_data   = replace_way ? way1_data : way0_data;

/*-------------------- Miss Buffer --------------------*/

wire replace_way = pseudo_random_23[0];

reg [1:0] num_ret_data;

always @(posedge clk_g) begin
    if (rd_rdy)
        num_ret_data <= 2'b00;
    else if (ret_valid)
        num_ret_data <= num_ret_data + 1;

end

/*-------------------- LFSR --------------------*/
reg [22:0] pseudo_random_23;
always @ (posedge clk_g) begin
   if (!resetn)
       pseudo_random_23 <= (SIMULATION == 1'b1) ? {7'b1010101,16'h00FF} : {7'b1010101,led_r_n};
   else
       pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
end



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

localparam WRITE_BUFFER_IDLE  = 2'b01; 
localparam WRITE_BUFFER_WRITE = 2'b10;

reg [1:0] write_buffer_state;
reg [1:0] write_buffer_next_state;

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
            if(main hit_write) begin
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



endmodule