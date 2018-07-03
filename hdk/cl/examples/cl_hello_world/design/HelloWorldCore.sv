//========================================================================
// HelloWorldCore
//========================================================================

`include "queues.sv"

module HelloWorldCore
(
  input  logic        clk,
  input  logic        reset,

  // AXI Lite: Write Address Channel (host -> FPGA)

  input  logic        awvalid,
  output logic        awready,
  input  logic [31:0] awaddr,

  // AXI Lite: Write Data Channel (host -> FPGA)

  input  logic        wvalid,
  output logic        wready,
  input  logic  [3:0] wstrb,  // Byte write enables
  input  logic [31:0] wdata,

  // AXI Lite: Write Response Channel (FPGA -> host)

  output logic        bvalid,
  input  logic        bready,
  output logic  [1:0] bresp,  // 00:ok, 01:exokay, 10:slverr, 11:decerr

  // AXI Lite: Read Address Channel (host -> FPGA)

  input  logic        arvalid,
  output logic        arready,
  input  logic [31:0] araddr,

  // AXI Lite: Read Data Channel (FPGA -> host)

  output logic        rvalid,
  input  logic        rready,
  output logic  [1:0] rresp,  // 00:ok, 01:exokay, 10:slverr, 11:decerr
  output logic [31:0] rdata,

  // DIP/LED Interface

  input  logic [15:0] vdip,
  output logic [15:0] vled

);

  `include "cl_common_defines.vh"      // CL Defines for all examples
  `include "cl_hello_world_defines.vh" // CL Defines for cl_hello_world

  //----------------------------------------------------------------------
  // AXI Lite Queues
  //----------------------------------------------------------------------

  // Write Address Channel Queue

  logic        waddr_q_deq_val;
  logic        waddr_q_deq_rdy;
  logic [31:0] waddr_q_deq_msg_addr;

  vc_Queue
  #(
    .p_type      (`VC_QUEUE_NORMAL),
    .p_msg_nbits (32),
    .p_num_msgs  (2)
  )
  waddr_q
  (
    .clk     (clk),
    .reset   (reset),

    .enq_val (awvalid),
    .enq_rdy (awready),
    .enq_msg (awaddr),

    .deq_val (waddr_q_deq_val),
    .deq_rdy (waddr_q_deq_rdy),
    .deq_msg (waddr_q_deq_msg_addr)
  );

  // Write Data Channel Queue

  logic        wdata_q_deq_val;
  logic        wdata_q_deq_rdy;
  logic [ 3:0] wdata_q_deq_msg_strb;
  logic [31:0] wdata_q_deq_msg_data;

  vc_Queue
  #(
    .p_type      (`VC_QUEUE_NORMAL),
    .p_msg_nbits (4+32),
    .p_num_msgs  (2)
  )
  wdata_q
  (
    .clk     (clk),
    .reset   (reset),

    .enq_val (wvalid),
    .enq_rdy (wready),
    .enq_msg ({wstrb,wdata}),

    .deq_val (wdata_q_deq_val),
    .deq_rdy (wdata_q_deq_rdy),
    .deq_msg ({wdata_q_deq_msg_strb,wdata_q_deq_msg_data})
  );

  // Write Response Queue

  logic        wresp_q_enq_val;
  logic        wresp_q_enq_rdy;
  logic  [1:0] wresp_q_enq_msg_status;

  vc_Queue
  #(
    .p_type      (`VC_QUEUE_NORMAL),
    .p_msg_nbits (2),
    .p_num_msgs  (2)
  )
  wresp_q
  (
    .clk     (clk),
    .reset   (reset),

    .enq_val (wresp_q_enq_val),
    .enq_rdy (wresp_q_enq_rdy),
    .enq_msg (wresp_q_enq_msg_status),

    .deq_val (bvalid),
    .deq_rdy (bready),
    .deq_msg (bresp)
  );

  // Read Address Channel Queue

  logic        raddr_q_deq_val;
  logic        raddr_q_deq_rdy;
  logic [31:0] raddr_q_deq_msg_addr;

  vc_Queue
  #(
    .p_type      (`VC_QUEUE_NORMAL),
    .p_msg_nbits (32),
    .p_num_msgs  (2)
  )
  raddr_q
  (
    .clk     (clk),
    .reset   (reset),

    .enq_val (arvalid),
    .enq_rdy (arready),
    .enq_msg (araddr),

    .deq_val (raddr_q_deq_val),
    .deq_rdy (raddr_q_deq_rdy),
    .deq_msg (raddr_q_deq_msg_addr)
  );

  // Read Response Queue

  logic        rresp_q_enq_val;
  logic        rresp_q_enq_rdy;
  logic [ 1:0] rresp_q_enq_msg_status;
  logic [31:0] rresp_q_enq_msg_data;

  vc_Queue
  #(
    .p_type      (`VC_QUEUE_NORMAL),
    .p_msg_nbits (2+32),
    .p_num_msgs  (2)
  )
  rresp_q
  (
    .clk     (clk),
    .reset   (reset),

    .enq_val (rresp_q_enq_val),
    .enq_rdy (rresp_q_enq_rdy),
    .enq_msg ({rresp_q_enq_msg_status,rresp_q_enq_msg_data}),

    .deq_val (rvalid),
    .deq_rdy (rready),
    .deq_msg ({rresp,rdata})
  );

  //----------------------------------------------------------------------
  // Hello World Register
  //----------------------------------------------------------------------

  logic        hello_world_reg_en;
  logic [31:0] hello_world_reg_in;
  logic [31:0] hello_world_reg_out;

  vc_EnResetReg
  #(
    .p_nbits       (32),
    .p_reset_value (0)
  )
  hello_world_reg
  (
    .clk   (clk),
    .reset (reset),
    .en    (hello_world_reg_en),
    .d     (hello_world_reg_in),
    .q     (hello_world_reg_out)
  );

  //----------------------------------------------------------------------
  // Write Transaction
  //----------------------------------------------------------------------
  // A write transaction occurs if both the waddr and wdata deq
  // interfaces are valid and the wresp enq interface is ready. During a
  // write transaction we will deq the waddr and wdata messages and enq a
  // wresp message. We also write the hello_world register assuming the
  // waddr is correct.

  assign wresp_q_enq_msg_status = 2'b00;
  assign hello_world_reg_in     = wdata_q_deq_msg_data;

  always @(*) begin

    waddr_q_deq_rdy    = 0;
    wdata_q_deq_rdy    = 0;
    wresp_q_enq_val    = 0;
    hello_world_reg_en = 0;

    if ( waddr_q_deq_val && wdata_q_deq_val && wresp_q_enq_rdy ) begin

      waddr_q_deq_rdy = 1;
      wdata_q_deq_rdy = 1;
      wresp_q_enq_val = 1;

      if ( waddr_q_deq_msg_addr == `HELLO_WORLD_REG_ADDR ) begin
        hello_world_reg_en = 1;
      end
    end

  end

  //----------------------------------------------------------------------
  // Read Transaction
  //----------------------------------------------------------------------
  // A read transaction occurs if the raddr deq interface is valid and
  // the rresp enq interface is ready. During a read transaction we will
  // deq the raddr message and enq a rresp message with the byte swapped
  // data from the hello_world register.

  assign rresp_q_enq_msg_status = 2'b00;

  always @(*) begin

    raddr_q_deq_rdy      = 0;
    rresp_q_enq_val      = 0;
    rresp_q_enq_msg_data = `UNIMPLEMENTED_REG_VALUE;

    if ( raddr_q_deq_val && rresp_q_enq_rdy ) begin

      raddr_q_deq_rdy = 1;
      rresp_q_enq_val = 1;

      if ( raddr_q_deq_msg_addr == `HELLO_WORLD_REG_ADDR ) begin
        rresp_q_enq_msg_data
          = { hello_world_reg_out[ 7: 0],
              hello_world_reg_out[15: 8],
              hello_world_reg_out[23:16],
              hello_world_reg_out[31:24] };
      end
      else if ( raddr_q_deq_msg_addr == `VLED_REG_ADDR ) begin
        rresp_q_enq_msg_data = { 16'b0, hello_world_reg_out[15:0] };
      end

    end

  end

  //----------------------------------------------------------------------
  // DIP/LED
  //----------------------------------------------------------------------
  // The first DIP switch chooses whether to output the lower 16-bits or
  // upper 16-bits of the hello_world register.

  assign vled = vdip[0] ? hello_world_reg_out[31:16]
              :           hello_world_reg_out[15:0];

endmodule

