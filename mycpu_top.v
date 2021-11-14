module mycpu_top(
    input         aclk,
    input         aresetn,
    
    // AXI bridge interface
    // read request channel
    output     [ 3:0] arid,//inst: 0,data: 1
    output     [31:0] araddr,
    output     [ 7:0] arlen,//0
    output     [ 2:0] arsize,
    output     [ 1:0] arburst,//0b01
    output     [ 1:0] arlock,//0
    output     [ 3:0] arcache,//0
    output     [ 2:0] arprot,//0
    output            arvalid,//read address valid
    input             arready,//read address valid
    // read respond channel
    input      [ 3:0] rid,
    input      [31:0] rdata,
    input      [ 1:0] rresp,//ignore
    input             rlast,//ignore
    input             rvalid,//read valid
    output            rready,//read ready
    // write request channel
    output     [ 3:0] awid,//1
    output     [31:0] awaddr,
    output     [ 7:0] awlen,//0
    output     [ 2:0] awsize,
    output     [ 1:0] awburst,//0b01
    output     [ 1:0] awlock,//0
    output     [ 3:0] awcache,//0
    output     [ 2:0] awprot,//0
    output            awvalid,//write address valid
    input             awready,//write address valid
    // write data channel
    output     [ 3:0] wid,//1
    output     [31:0] wdata,
    output     [ 3:0] wstrb,//WSTRB[n] corresponds to WDATA[(8n) + 7: (8n)].
    output            wlast,//1
    output            wvalid,
    input             wready,
    // write respond channel
    input      [ 3:0] bid,//ignore
    input      [ 1:0] bresp,//ignore
    input             bvalid,//write response valid
    output            bready,//write response ready

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

    wire         clk;
    wire         resetn;
    assign       clk = aclk;
    assign       resetn = aresetn;

    wire         inst_sram_req;
    wire  [ 3:0] inst_sram_wstrb;
    wire  [31:0] inst_sram_addr;
    wire  [31:0] inst_sram_wdata;
    wire  [31:0] inst_sram_rdata;
    wire  [ 1:0] inst_sram_size;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire         inst_sram_wr;

    wire         data_sram_req;
    wire  [ 3:0] data_sram_wstrb;
    wire  [31:0] data_sram_addr;
    wire  [31:0] data_sram_wdata;
    wire  [31:0] data_sram_rdata;
    wire  [ 1:0] data_sram_size;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire         data_sram_wr;

axi_bridge axi_bridge(
    .aclk      (aclk    ),
    .aresetn   (aresetn ),
    // read request
    .arid      (arid    ),
    .araddr    (araddr  ),
    .arlen     (arlen   ),
    .arsize    (arsize  ),
    .arburst   (arburst ),
    .arlock    (arlock  ),
    .arcache   (arcache ),
    .arprot    (arprot  ),
    .arvalid   (arvalid ),
    .arready   (arready ),
    // read respond
    .rid       (rid     ),
    .rdata     (rdata   ),
    .rresp     (rresp   ),
    .rvalid    (rvalid  ),
    .rready    (rready  ),
    // write request
    .awid      (awid    ),
    .awaddr    (awaddr  ),
    .awlen     (awlen   ),
    .awsize    (awsize  ),
    .awburst   (awburst ),
    .awlock    (awlock  ),
    .awcache   (awcache ),
    .awprot    (awprot  ),
    .awvalid   (awvalid ),
    .awready   (awready ),
    // write data
    .wid       (wid     ),
    .wdata     (wdata   ),
    .wstrb     (wstrb   ),
    .wlast     (wlast   ),
    .wvalid    (wvalid  ),
    .wready    (wready  ),
    // write respond
    .bid       (bid     ),
    .bresp     (bresp   ),
    .bvalid    (bvalid  ),
    .bready    (bready  ),

    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_wr      (inst_sram_wr     ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_rdata   (data_sram_rdata  ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_wr      (data_sram_wr     )
);



cpu_core cpu_core(
    .clk               (clk              ),
    .resetn            (resetn           ),
    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_wr      (inst_sram_wr     ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_rdata   (data_sram_rdata  ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_wr      (data_sram_wr     ),
    // trace debug interface
    .debug_wb_pc       (debug_wb_pc      ),
    .debug_wb_rf_wen   (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata)
);



endmodule
