//========================================================================
// test_nullx
//========================================================================

module test_nullx();

  import tb_type_defines_pkg::*;

  parameter [5:0] AXI_ID = 6'h0;

  //----------------------------------------------------------------------
  // test_write
  //----------------------------------------------------------------------
  // Use OCL interface to write given data to given address.

  task test_write
  (
    input logic [ 4:0] addr,
    input logic [31:0] data
  );
  begin
    $display(" [ -note- ] write: addr=%x, data=%x", addr, data );
    tb.poke_ocl( 0, { 59'h0, addr }, data );
  end
  endtask

  //----------------------------------------------------------------------
  // test_read
  //----------------------------------------------------------------------
  // Use OCL interface to read data from given address. Verify that the
  // read data matches the given data.

  logic [31:0] read_data;

  task test_read
  (
    input logic [ 4:0] addr,
    input logic [31:0] data
  );
  begin
    $display(" [ -note- ] read : addr=%x", addr );
    tb.peek_ocl( 0, { 59'h0, addr }, read_data );
    if ( read_data == data ) begin
      $display(" [ passed ] read: actual=%x, expected=%x", read_data, data );
    end
    else begin
      $display(" [ FAILED ] read: actual=%x, expected=%x", read_data, data );
    end
  end
  endtask

  //----------------------------------------------------------------------
  // test_led
  //----------------------------------------------------------------------
  // Use OCL interface to set the DIP switches and read the LEDs. Verify
  // that the LEDs correctly reflect the write/read count.

  logic [15:0] led;

  task test_led
  (
    input logic [15:0] write_count,
    input logic [15:0] read_count
  );
  begin

    $display(" [ -note- ] set DIP to 0, check write count via LED" );
    tb.set_virtual_dip_switch( 0, 16'b0000_0000_0000_0000 );
    #100;
    led = tb.get_virtual_led( 0 );
    if ( led == write_count ) begin
      $display(" [ passed ] LED write count: actual=%x, expected=%x", led, write_count );
    end
    else begin
      $display(" [ FAILED ] LED write count: actual=%x, expected=%x", led, write_count );
    end

    $display(" [ -note- ] set DIP to 1, check read count via LED" );
    tb.set_virtual_dip_switch( 0, 16'b0000_0000_0000_0001 );
    #100;
    led = tb.get_virtual_led( 0 );
    if ( led == read_count ) begin
      $display(" [ passed ] LED read count: actual=%x, expected=%x", led, read_count );
    end
    else begin
      $display(" [ FAILED ] LED read count: actual=%x, expected=%x", led, read_count );
    end

  end
  endtask

  //----------------------------------------------------------------------
  // run tests
  //----------------------------------------------------------------------

  integer i;
  initial begin
    $dumpfile("test_nullx.vcd");
    $dumpvars( 0, test_nullx, tb );

    tb.power_up();

    // basic test to write/read reg 0

    test_write( 5'd0, 32'hdeadbeef );
    test_read ( 5'd0, 32'hdeadbeef );

    // test write/read each register

    for ( i = 0; i < 32; i = i+1 ) begin
      test_write( i, i );
      test_read ( i, i );
    end

    // test read each register

    for ( i = 0; i < 32; i = i+1 ) begin
      test_read ( i, i );
    end

    tb.kernel_reset();
    tb.power_down();
    $finish;
  end

endmodule

