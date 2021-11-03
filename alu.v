module alu(
  input         clk,
  input         reset,
  input  [18:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output        div_ready_go,
  output [31:0] alu_result
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate

wire op_mul;   //multiply signed/unsigned low 32
wire op_mulh;  //multiply signed high 32
wire op_mulhu; //multiply unsigned high 32
wire op_div;   //division quotient
wire op_divu;  //division unsigned quotient
wire op_mod;   //division remainder
wire op_modu;  //division unsigned remainder

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
//Add in lab6
assign op_mul  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu= alu_op[14];
assign op_div  = alu_op[15];
assign op_divu = alu_op[16];
assign op_mod  = alu_op[17];
assign op_modu = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
//Add in lab6
wire [65:0] mul_result; //33*33 for mulh.w, mulh.wu
wire [63:0] signed_div_result;
wire [63:0] unsigned_div_result;
wire [32:0] mul_a;
wire [32:0] mul_b;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;//{alu_src2[14:0], alu_src2[19:15], 12'b0};

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

assign sr_result   = sr64_result[31:0];

assign mul_a       = {33{op_mulhu}} & {1'b0,alu_src1} | {33{~op_mulhu}} & {alu_src1[31],alu_src1};
assign mul_b       = {33{op_mulhu}} & {1'b0,alu_src2} | {33{~op_mulhu}} & {alu_src2[31],alu_src2};
assign mul_result  = $signed(mul_a) * $signed(mul_b);

//assign signed_div_result = ~(slt_result[0] && (alu_src1[31]==alu_src2[31]))  ? signed_div_result : 64'b0;

wire [3:0] div_op = alu_op[18:15];
wire [31:0] div_src1 = alu_src1;
wire [31:0] div_src2 = alu_src2;
wire [31:0] div_final_result;
wire div_running;
wire op_div; 
wire op_divu; 
wire op_mod;  
wire op_modu; 

assign op_div  = div_op[0];
assign op_divu = div_op[1];
assign op_mod  = div_op[2];
assign op_modu = div_op[3];

wire [63:0] div_result;
wire [63:0] div_u_result;

wire div_src_ready;
wire div_ans_valid;
wire div_divisor_ready;
wire div_dividend_ready;
wire div_work;
wire div_u_src_ready;
wire div_u_ans_valid;
wire div_u_divisor_ready;
wire div_u_dividend_ready;
wire div_u_work;

reg div_src_valid;
reg div_u_src_valid;
reg div_state;

assign div_work = op_div | op_mod;
assign div_src_ready = div_divisor_ready & div_dividend_ready;
assign div_u_work = op_divu | op_modu;
assign div_u_src_ready = div_u_divisor_ready & div_u_dividend_ready;
assign div_running = div_work & ~div_ans_valid | div_u_work & ~div_u_ans_valid;
assign div_ready_go = ~div_running;

always @ (posedge clk) begin
  if(reset) begin
    div_src_valid <= 1'b0;
  end
  else if (~div_state & div_work) begin
    div_src_valid <= 1'b1;
  end
  else if (div_src_valid & div_src_ready) begin
    div_src_valid <= 1'b0;
  end
end

always @ (posedge clk) begin
  if(reset) begin
    div_u_src_valid <= 1'b0;
  end
  else if (~div_state & div_u_work) begin
    div_u_src_valid <= 1'b1;
  end
  else if (div_u_src_valid & div_u_src_ready) begin
    div_u_src_valid <= 1'b0;
  end
end

always @ (posedge clk) begin
  if(reset) begin
    div_state <= 1'b0;
  end
  else if (~div_state & (div_work | div_u_work)) begin
    div_state <= 1'b1; 
  end
  else if (div_ans_valid | div_u_ans_valid) begin
    div_state <= 1'b0; 
  end
end

mydiv mydiv(
  .s_axis_divisor_tdata(div_src2),
  .s_axis_dividend_tdata(div_src1),
  .s_axis_divisor_tvalid(div_src_valid),
  .s_axis_dividend_tvalid(div_src_valid),
  .s_axis_divisor_tready(div_divisor_ready),
  .s_axis_dividend_tready(div_dividend_ready),
  .aclk(clk),
  .m_axis_dout_tdata(div_result),
  .m_axis_dout_tvalid(div_ans_valid)
);

my_unsigned_div my_unsigned_div(
  .s_axis_divisor_tdata(div_src2),
  .s_axis_dividend_tdata(div_src1),
  .s_axis_divisor_tvalid(div_u_src_valid),
  .s_axis_dividend_tvalid(div_u_src_valid),
  .s_axis_divisor_tready(div_u_divisor_ready),
  .s_axis_dividend_tready(div_u_dividend_ready),
  .aclk(clk),
  .m_axis_dout_tdata(div_u_result),
  .m_axis_dout_tvalid(div_u_ans_valid)
);

assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mul       }} & mul_result[31:0]) //the low 32
                  | ({32{op_mulh|op_mulhu}} & mul_result[63:32]) //the high 32
                  | ({32{op_div       }} & div_result[63:32]) //the high 32 for quotient
                  | ({32{op_divu      }} & div_u_result[63:32])
                  | ({32{op_mod       }} & div_result[31:0]) //the low 32 for remainder
                  | ({32{op_modu      }} & div_u_result[31:0]);
                  

endmodule