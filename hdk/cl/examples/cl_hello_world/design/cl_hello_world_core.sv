//========================================================================
// cl_hello_world_core
//========================================================================

module HelloWorldCore
(
  input  logic clk,
  input  logic reset,

  // --- AXI Lite Interface ----------------------------------------------

  // Write Address Channel (host -> FPGA)

  input  logic        awvalid,
  output logic        awready,
  input  logic [31:0] awaddr,

  // Write Data Channel (host -> FPGA)

  input  logic        wvalid,
  output logic        wready,
  input  logic [31:0] wdata,
  input  logic  [3:0] wstrb,

  // Write Response Channel (FPGA -> host)

  output logic        bvalid,
  input  logic        bready,
  output logic  [1:0] bresp,

  // Read Address Channel (host -> FPGA)

  input  logic        arvalid,
  output logic        arready,
  input  logic [31:0] araddr,

  // Read Data Channel (FPGA -> host)

  output logic        rvalid,
  input  logic        rready,
  output logic  [1:0] rresp,
  output logic [31:0] rdata,

  // --- DIP/LED Interface -----------------------------------------------

  input  logic [15:0] vdip,
  output logic [15:0] vled

);




endmodule

