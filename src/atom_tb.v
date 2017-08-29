`timescale 1ns / 1ns

module opc6tb();

   parameter   CHARROM_INIT_FILE = "../mem/charrom.mem";
   parameter   VID_RAM_INIT_FILE = "../mem/vid_ram.mem";

   // This is used to simulate the ARM downloaded the initial set of ROM images
   parameter   BOOT_INIT_FILE    = "../mem/boot_c000_ffff.mem";

   parameter   BOOT_START_ADDR   = 'h0C000;
   parameter   BOOT_END_ADDR     = 'h0FFFF;

   reg [7:0]   boot [ 0 : BOOT_END_ADDR - BOOT_START_ADDR ];

   reg [17:0]  mem [ 0:262143 ];

   reg         clk;
   reg         reset_b;
   wire [17:0] addr;
   wire [7:0]  data;
   wire [7:0]  data_in;
   reg [7:0]   data_out;
   wire        ramwe_b;
   wire        ramoe_b;
   wire        ramcs_b;
   wire [2:0]  r;
   wire [2:0]  g;
   wire [1:0]  b;
   wire        hsync;
   wire        vsync;

   wire        r_msb  = r[2];
   wire        g_msb  = g[2];
   wire        b_msb  = b[1];

   reg         arm_ss;
   reg         arm_sclk;
   reg         arm_mosi;

   reg         ps2_clk;
   reg         ps2_data;
   reg         cas_in;

   integer     i, j;

atom
  #(
    .CHARROM_INIT_FILE (CHARROM_INIT_FILE),
    .VID_RAM_INIT_FILE (VID_RAM_INIT_FILE),
    .BOOT_START_ADDR(BOOT_START_ADDR),
    .BOOT_END_ADDR(BOOT_END_ADDR)
    )
   DUT
     (
      .clk100(clk),
      .sw4(reset_b),

      .arm_ss(arm_ss),
      .arm_sclk(arm_sclk),
      .arm_mosi(arm_mosi),

      .cas_in(cas_in),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),

      .RAMWE_b(ramwe_b),
      .RAMOE_b(ramoe_b),
      .RAMCS_b(ramcs_b),
      .ADR(addr),
      .DAT(data),

      .r(r),
      .g(g),
      .b(b),
      .hsync(hsync),
      .vsync(vsync)
      );

   initial begin
      $dumpvars;
      // needed or the simulation hits an ambiguous branch
      mem[16'h00DE] = 8'h00;
      mem[16'h00DF] = 8'h00;
      mem[16'h00E0] = 8'h00;
      mem[16'h00E6] = 8'h00;

      // initialize 10MHz clock
      clk = 1'b0;
      // external reset should not be required, so don't simulate it
      reset_b  = 1'b1;
      // initialize other miscellaneous inputs
      cas_in <= 1'b0;
      ps2_clk <= 1'b1;
      ps2_data <= 1'b1;

      // load the boot image at 20MHz (should take 6ms for 16KB)
      $readmemh(BOOT_INIT_FILE, boot);
      arm_ss   = 1'b1;
      arm_sclk = 1'b1;
      arm_mosi = 1'b1;
      // start the boot spi transfer by lowering ss
      #1000 arm_ss = 1'b0;
      // wait ~1us longer (as this is what the arm does)
      #1000;
      // start sending the data (MSB first)
      // data changes on falling edge of clock and is samples on rising edges
      for (i = 0; i <= BOOT_END_ADDR - BOOT_START_ADDR; i = i + 1)
        for (j = 7; j >= 0; j = j - 1)
          begin
             #25 arm_sclk = 1'b0;
             arm_mosi = boot[i][j];
             #25 arm_sclk = 1'b1;
          end
      #1000 arm_ss = 1'b1;

      #50000000 $finish; // 50ms, enough for a few video frames
   end

   always
     #5 clk = !clk;

   assign data_in = data;
   assign data = (!ramcs_b && !ramoe_b && ramwe_b) ? data_out : 8'hZZ;

   always @(posedge ramwe_b)
     if (ramcs_b == 1'b0)
       mem[addr] <= data_in;

   always @(addr)
     data_out <= mem[addr];

endmodule
