//========================================================================
// cl_hello_world_new.sv
//========================================================================
// Cleaned up version of the hello world provided in the Amazon FPGA HDK.

module cl_hello_world
(
  // The ports are all included here:
  // hdk/common/shell_v071417d3/design/interfaces/cl_ports.vh
  `include "cl_ports.vh"
);

  `include "cl_common_defines.vh"      // CL Defines for all examples
  `include "cl_id_defines.vh"          // Defines for ID0 and ID1 (PCI ID's)

  // I guess I would change this?
  `include "cl_hello_world_defines.vh" // CL Defines for cl_hello_world

  logic rst_main_n_sync;

  //----------------------------------------------------------------------
  // Start with Tie-Off of Unused Interfaces
  //----------------------------------------------------------------------
  // the developer should use the next set of `include to properly
  // tie-off any unused interface The list is put in the top of the
  // module to avoid cases where developer may forget to remove it from
  // the end of the file.

  `include "unused_flr_template.inc"
  `include "unused_ddr_a_b_d_template.inc"
  `include "unused_ddr_c_template.inc"
  `include "unused_pcim_template.inc"
  `include "unused_dma_pcis_template.inc"
  `include "unused_cl_sda_template.inc"
  `include "unused_sh_bar1_template.inc"
  `include "unused_apppf_irq_template.inc"

  //----------------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------------

  logic        arvalid_q;
  logic [31:0] araddr_q;
  logic [31:0] hello_world_q_byte_swapped;
  logic [15:0] vled_q;
  logic [15:0] pre_cl_sh_status_vled;
  logic [15:0] sh_cl_status_vdip_q;
  logic [15:0] sh_cl_status_vdip_q2;
  logic [31:0] hello_world_q;

  //----------------------------------------------------------------------
  // ID Values (cl_hello_world_defines.vh)
  //----------------------------------------------------------------------

  assign cl_sh_id0[31:0] = `CL_SH_ID0;
  assign cl_sh_id1[31:0] = `CL_SH_ID1;

  //----------------------------------------------------------------------
  // Reset Synchronization
  //----------------------------------------------------------------------

  logic pre_sync_rst_n;

  always_ff @( negedge rst_main_n or posedge clk_main_a0 )
  begin
    if ( !rst_main_n ) begin
      pre_sync_rst_n  <= 0;
      rst_main_n_sync <= 0;
    end
    else begin
      pre_sync_rst_n  <= 1;
      rst_main_n_sync <= pre_sync_rst_n;
    end
  end

  //----------------------------------------------------------------------
  // PCIe OCL AXI-L (SH to CL) Timing Flops
  //----------------------------------------------------------------------

  // Write address
  logic        sh_ocl_awvalid_q;
  logic [31:0] sh_ocl_awaddr_q;
  logic        ocl_sh_awready_q;

  // Write data
  logic        sh_ocl_wvalid_q;
  logic [31:0] sh_ocl_wdata_q;
  logic [ 3:0] sh_ocl_wstrb_q;
  logic        ocl_sh_wready_q;

  // Write response
  logic        ocl_sh_bvalid_q;
  logic [ 1:0] ocl_sh_bresp_q;
  logic        sh_ocl_bready_q;

  // Read address
  logic        sh_ocl_arvalid_q;
  logic [31:0] sh_ocl_araddr_q;
  logic        ocl_sh_arready_q;

  // Read data/response
  logic        ocl_sh_rvalid_q;
  logic [31:0] ocl_sh_rdata_q;
  logic [ 1:0] ocl_sh_rresp_q;
  logic        sh_ocl_rready_q;

  axi_register_slice_light AXIL_OCL_REG_SLC
  (
    .aclk          (clk_main_a0),
    .aresetn       (rst_main_n_sync),
    .s_axi_awaddr  (sh_ocl_awaddr),
    .s_axi_awprot  (2'h0),
    .s_axi_awvalid (sh_ocl_awvalid),
    .s_axi_awready (ocl_sh_awready),
    .s_axi_wdata   (sh_ocl_wdata),
    .s_axi_wstrb   (sh_ocl_wstrb),
    .s_axi_wvalid  (sh_ocl_wvalid),
    .s_axi_wready  (ocl_sh_wready),
    .s_axi_bresp   (ocl_sh_bresp),
    .s_axi_bvalid  (ocl_sh_bvalid),
    .s_axi_bready  (sh_ocl_bready),
    .s_axi_araddr  (sh_ocl_araddr),
    .s_axi_arvalid (sh_ocl_arvalid),
    .s_axi_arready (ocl_sh_arready),
    .s_axi_rdata   (ocl_sh_rdata),
    .s_axi_rresp   (ocl_sh_rresp),
    .s_axi_rvalid  (ocl_sh_rvalid),
    .s_axi_rready  (sh_ocl_rready),
    .m_axi_awaddr  (sh_ocl_awaddr_q),
    .m_axi_awprot  (),
    .m_axi_awvalid (sh_ocl_awvalid_q),
    .m_axi_awready (ocl_sh_awready_q),
    .m_axi_wdata   (sh_ocl_wdata_q),
    .m_axi_wstrb   (sh_ocl_wstrb_q),
    .m_axi_wvalid  (sh_ocl_wvalid_q),
    .m_axi_wready  (ocl_sh_wready_q),
    .m_axi_bresp   (ocl_sh_bresp_q),
    .m_axi_bvalid  (ocl_sh_bvalid_q),
    .m_axi_bready  (sh_ocl_bready_q),
    .m_axi_araddr  (sh_ocl_araddr_q),
    .m_axi_arvalid (sh_ocl_arvalid_q),
    .m_axi_arready (ocl_sh_arready_q),
    .m_axi_rdata   (ocl_sh_rdata_q),
    .m_axi_rresp   (ocl_sh_rresp_q),
    .m_axi_rvalid  (ocl_sh_rvalid_q),
    .m_axi_rready  (sh_ocl_rready_q)
  );

  //----------------------------------------------------------------------
  // PCIe OCL AXI-L Slave Accesses (accesses from PCIe AppPF BAR0)
  //----------------------------------------------------------------------
  // Only supports single-beat accesses.

  // I think this is the basic I/O interface used for hello world. It is
  // an AXI-Lite interface. -cbatten

  // Write Address Channel (host -> FPGA)

  logic        awvalid;
  logic        awready;
  logic [31:0] awaddr;

  assign awvalid          = sh_ocl_awvalid_q;
  assign ocl_sh_awready_q = awready;
  assign awaddr[31:0]     = sh_ocl_awaddr_q;

  // Write Data Channel (host -> FPGA)

  logic        wvalid;
  logic        wready;
  logic [31:0] wdata;
  logic [3:0]  wstrb;

  assign wvalid           = sh_ocl_wvalid_q;
  assign ocl_sh_wready_q  = wready;
  assign wdata[31:0]      = sh_ocl_wdata_q;
  assign wstrb[3:0]       = sh_ocl_wstrb_q;

  // Write Response Channel (FPGA -> host)

  logic        bvalid;
  logic        bready;
  logic [1:0]  bresp;

  assign ocl_sh_bvalid_q  = bvalid;
  assign bready           = sh_ocl_bready_q;
  assign ocl_sh_bresp_q   = bresp[1:0];

  // Read Address Channel (host -> FPGA)

  logic        arvalid;
  logic        arready;
  logic [31:0] araddr;

  assign arvalid          = sh_ocl_arvalid_q;
  assign ocl_sh_arready_q = arready;
  assign araddr[31:0]     = sh_ocl_araddr_q;

  // Read Data Channel (FPGA -> host)

  logic        rvalid;
  logic        rready;
  logic [1:0]  rresp;
  logic [31:0] rdata;

  assign ocl_sh_rvalid_q  = rvalid;
  assign rready           = sh_ocl_rready_q;
  assign ocl_sh_rresp_q   = rresp[1:0];
  assign ocl_sh_rdata_q   = rdata;

  // Write Request

  logic        wr_active;
  logic [31:0] wr_addr;

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin
      wr_active <= 0;
      wr_addr   <= 0;
    end
    else begin
      wr_active <=   wr_active && bvalid  && bready ? 1'b0
                 :  ~wr_active && awvalid           ? 1'b1
                 :                                    wr_active;

      wr_addr   <= awvalid && ~wr_active ? awaddr : wr_addr;
    end
  end

  assign awready = ~wr_active;
  assign wready  =  wr_active && wvalid;

  // Write Response

  always_ff @( posedge clk_main_a0 )
  begin
    if (!rst_main_n_sync)
      bvalid <= 0;
    else
      bvalid <=  bvalid && bready ? 1'b0
              : ~bvalid && wready ? 1'b1
              :                     bvalid;
  end

  assign bresp = 0;

  // Read Request

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin
      arvalid_q <= 0;
      araddr_q  <= 0;
    end
    else begin
      arvalid_q <= arvalid;
      araddr_q  <= arvalid ? araddr : araddr_q;
    end
  end

  assign arready = !arvalid_q && !rvalid;

  // Read Response

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin
      rvalid <= 0;
      rdata  <= 0;
      rresp  <= 0;
    end
    else if (rvalid && rready) begin
      rvalid <= 0;
      rdata  <= 0;
      rresp  <= 0;
    end
    else if (arvalid_q) begin
      rvalid <= 1;
      rdata  <= (araddr_q == `HELLO_WORLD_REG_ADDR) ? hello_world_q_byte_swapped[31:0]
              : (araddr_q == `VLED_REG_ADDR       ) ? {16'b0,vled_q[15:0]            }
              :                                       `UNIMPLEMENTED_REG_VALUE;
      rresp  <= 0;
    end
  end

  //----------------------------------------------------------------------
  // Hello World Register
  //----------------------------------------------------------------------
  // When read it, returns the byte-flipped value.

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin                    // Reset
      hello_world_q[31:0] <= 32'h0000_0000;
    end
    else if (wready & (wr_addr == `HELLO_WORLD_REG_ADDR)) begin
      hello_world_q[31:0] <= wdata[31:0];
    end
    else begin                                     // Hold Value
      hello_world_q[31:0] <= hello_world_q[31:0];
    end
  end

  assign hello_world_q_byte_swapped[31:0]
    = { hello_world_q[7:0],
        hello_world_q[15:8],
        hello_world_q[23:16],
        hello_world_q[31:24] };

  //----------------------------------------------------------------------
  // Virtual LED Register
  //----------------------------------------------------------------------
  // Flop/synchronize interface signals

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin                    // Reset
      sh_cl_status_vdip_q[15:0]  <= 16'h0000;
      sh_cl_status_vdip_q2[15:0] <= 16'h0000;
      cl_sh_status_vled[15:0]    <= 16'h0000;
    end
    else begin
      sh_cl_status_vdip_q[15:0]  <= sh_cl_status_vdip[15:0];
      sh_cl_status_vdip_q2[15:0] <= sh_cl_status_vdip_q[15:0];
      cl_sh_status_vled[15:0]    <= pre_cl_sh_status_vled[15:0];
    end
  end

  // The register contains 16 read-only bits corresponding to 16 LED's.
  // For this example, the virtual LED register shadows the hello_world
  // register. The same LED values can be read from the CL to Shell
  // interface by using the linux FPGA tool: $ fpga-get-virtual-led -S 0

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync) begin                    // Reset
      vled_q[15:0] <= 16'h0000;
    end
    else begin
      vled_q[15:0] <= hello_world_q[15:0];
    end
  end

  // The Virtual LED outputs will be masked with the Virtual DIP switches.
  assign pre_cl_sh_status_vled[15:0]
    = vled_q[15:0] & sh_cl_status_vdip_q2[15:0];

  //----------------------------------------------------------------------
  // Tie-Off Unused Global Signals
  //----------------------------------------------------------------------
  // The functionality for these signals is TBD so they can can be
  // tied-off.

  assign cl_sh_status0[31:0] = 32'h0;
  assign cl_sh_status1[31:0] = 32'h0;

  //----------------------------------------------------------------------
  // Debug bridge, used if need Virtual JTAG
  //----------------------------------------------------------------------

  `ifndef DISABLE_VJTAG_DEBUG

  // Flop for timing global clock counter

  logic[63:0] sh_cl_glcount0_q;

  always_ff @( posedge clk_main_a0 ) begin
    if (!rst_main_n_sync)
      sh_cl_glcount0_q <= 0;
    else
      sh_cl_glcount0_q <= sh_cl_glcount0;
  end

  // Integrated Logic Analyzers (ILA)

  ila_0 CL_ILA_0
  (
    .clk    (clk_main_a0),
    .probe0 (sh_ocl_awvalid_q),
    .probe1 (sh_ocl_awaddr_q ),
    .probe2 (ocl_sh_awready_q),
    .probe3 (sh_ocl_arvalid_q),
    .probe4 (sh_ocl_araddr_q ),
    .probe5 (ocl_sh_arready_q)
  );

  ila_0 CL_ILA_1
  (
    .clk    (clk_main_a0),
    .probe0 (ocl_sh_bvalid_q),
    .probe1 (sh_cl_glcount0_q),
    .probe2 (sh_ocl_bready_q),
    .probe3 (ocl_sh_rvalid_q),
    .probe4 ({32'b0,ocl_sh_rdata_q[31:0]}),
    .probe5 (sh_ocl_rready_q)
  );

  // Debug Bridge

  cl_debug_bridge CL_DEBUG_BRIDGE
  (
    .clk                (clk_main_a0),
    .S_BSCAN_drck       (drck),
    .S_BSCAN_shift      (shift),
    .S_BSCAN_tdi        (tdi),
    .S_BSCAN_update     (update),
    .S_BSCAN_sel        (sel),
    .S_BSCAN_tdo        (tdo),
    .S_BSCAN_tms        (tms),
    .S_BSCAN_tck        (tck),
    .S_BSCAN_runtest    (runtest),
    .S_BSCAN_reset      (reset),
    .S_BSCAN_capture    (capture),
    .S_BSCAN_bscanid_en (bscanid_en)
  );

  //----------------------------------------------------------------------
  // VIO Example - Needs Virtual JTAG
  //----------------------------------------------------------------------
  // Counter running at 125MHz

  logic        vo_cnt_enable;
  logic        vo_cnt_load;
  logic        vo_cnt_clear;
  logic        vo_cnt_oneshot;
  logic [7:0]  vo_tick_value;
  logic [15:0] vo_cnt_load_value;
  logic [15:0] vo_cnt_watermark;

  logic        vo_cnt_enable_q     = 0;
  logic        vo_cnt_load_q       = 0;
  logic        vo_cnt_clear_q      = 0;
  logic        vo_cnt_oneshot_q    = 0;
  logic [7:0]  vo_tick_value_q     = 0;
  logic [15:0] vo_cnt_load_value_q = 0;
  logic [15:0] vo_cnt_watermark_q  = 0;

  logic        vi_tick;
  logic        vi_cnt_ge_watermark;
  logic [7:0]  vi_tick_cnt = 0;
  logic [15:0] vi_cnt = 0;

  // Tick counter and main counter

  always @( posedge clk_main_a0 ) begin

    vo_cnt_enable_q     <= vo_cnt_enable;
    vo_cnt_load_q       <= vo_cnt_load;
    vo_cnt_clear_q      <= vo_cnt_clear;
    vo_cnt_oneshot_q    <= vo_cnt_oneshot;
    vo_tick_value_q     <= vo_tick_value;
    vo_cnt_load_value_q <= vo_cnt_load_value;
    vo_cnt_watermark_q  <= vo_cnt_watermark;

    vi_tick_cnt
      =  vo_cnt_clear_q                  ? 0
      : ~vo_cnt_enable_q                 ? vi_tick_cnt
      : (vi_tick_cnt >= vo_tick_value_q) ? 0
      :                                    vi_tick_cnt + 1;

    vi_cnt
      = vo_cnt_clear_q                                                                  ? 0
      : vo_cnt_load_q                                                                   ? vo_cnt_load_value_q
      : ~vo_cnt_enable_q                                                                ? vi_cnt
      : (vi_tick_cnt >= vo_tick_value_q) && (~vo_cnt_oneshot_q || (vi_cnt <= 16'hFFFF)) ? vi_cnt + 1
      :                                                                                   vi_cnt;

    vi_tick = (vi_tick_cnt >= vo_tick_value_q);

    vi_cnt_ge_watermark = (vi_cnt >= vo_cnt_watermark_q);

  end

  vio_0 CL_VIO_0
  (
    .clk        (clk_main_a0),
    .probe_in0  (vi_tick),
    .probe_in1  (vi_cnt_ge_watermark),
    .probe_in2  (vi_tick_cnt),
    .probe_in3  (vi_cnt),
    .probe_out0 (vo_cnt_enable),
    .probe_out1 (vo_cnt_load),
    .probe_out2 (vo_cnt_clear),
    .probe_out3 (vo_cnt_oneshot),
    .probe_out4 (vo_tick_value),
    .probe_out5 (vo_cnt_load_value),
    .probe_out6 (vo_cnt_watermark)
  );

  ila_vio_counter CL_VIO_ILA
  (
    .clk        (clk_main_a0),
    .probe0     (vi_tick),
    .probe1     (vi_cnt_ge_watermark),
    .probe2     (vi_tick_cnt),
    .probe3     (vi_cnt),
    .probe4     (vo_cnt_enable_q),
    .probe5     (vo_cnt_load_q),
    .probe6     (vo_cnt_clear_q),
    .probe7     (vo_cnt_oneshot_q),
    .probe8     (vo_tick_value_q),
    .probe9     (vo_cnt_load_value_q),
    .probe10    (vo_cnt_watermark_q)
  );

  `endif //  `ifndef DISABLE_VJTAG_DEBUG

endmodule

