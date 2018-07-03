//========================================================================
// TwoElementNormalQueue
//========================================================================

module TwoElementNormalQueue
#(
  parameter p_msg_nbits = 1
)
(
  input  logic                   clk,
  input  logic                   reset,

  input  logic                   enq_val,
  output logic                   enq_rdy,
  input  logic [p_msg_nbits-1:0] enq_msg,

  output logic                   deq_val,
  input  logic                   deq_rdy,
  output logic [p_msg_nbits-1:0] deq_msg
);

  logic [p_msg_nbits-1:0] entry0;
  logic [p_msg_nbits-1:0] entry1;

  logic [1:0]             full;
  logic                   head_ptr;

  // The enqueue interface is ready if there is at least one empty entry

  assign enq_rdy = ~full[0] | ~full[1];

  // The dequeue interface is valid if there is at least one valid entry

  assign enq_rdy = ~full[0] | ~full[1];

endmodule

