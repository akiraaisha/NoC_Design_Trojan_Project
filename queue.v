// Customer ID=4869; Build=0x3007c; Copyright (c) 2006-2008 by Tensilica Inc.  ALL RIGHTS RESERVED.
// These coded instructions, statements, and computer programs are the
// copyrighted works and confidential proprietary information of
// Tensilica Inc.  They may be adapted and modified by bona fide
// purchasers for internal use, but neither the original nor any adapted
// or modified version may be disclosed or distributed to third parties
// in any manner, medium, or form, in whole or in part, without the prior
// written consent of Tensilica Inc.

// `timescale 1ns / 1ps
 
`define DISPLAY_IO


module queue(CLK, TIE_NoC_OUT_0_PushReq, TIE_NoC_OUT_0, TIE_NoC_OUT_0_Full, TIE_NoC_IN_1_PopReq, TIE_NoC_IN_1, TIE_NoC_IN_1_Empty);

  input                         CLK;

  input                         TIE_NoC_OUT_0_PushReq;
  input         [31:0]          TIE_NoC_OUT_0;
  output                        TIE_NoC_OUT_0_Full;

  input                         TIE_NoC_IN_1_PopReq;   
  output        [31:0]          TIE_NoC_IN_1;
  output                        TIE_NoC_IN_1_Empty;

  reg                           TIE_NoC_OUT_0_Full  = 1'b0;
  reg           [1:0]           wp              = 1'b0;
  reg           [1:0]           rp              = 1'b0;

  reg           [31:0]          store[3:0];


  initial begin
    if($test$plusargs("dumpvars")) begin
      $dumpvars();
    end
  end

  initial begin
    store[0]    <= 0;
  end

  assign TIE_NoC_IN_1       = store[rp];
  assign TIE_NoC_IN_1_Empty = (wp == rp) && !TIE_NoC_OUT_0_Full;

`ifdef DISPLAY_IO
  always @(TIE_NoC_IN_1) begin
      $display("%t TIE_NoC_IN_1  = 0x%h", $time, TIE_NoC_IN_1);
  end
`endif

  always @(posedge CLK) begin
    if ((TIE_NoC_OUT_0_PushReq && !TIE_NoC_OUT_0_Full) && (TIE_NoC_IN_1_PopReq && !TIE_NoC_IN_1_Empty)) begin
`ifdef DISPLAY_IO
      $display("%t TIE_NoC_OUT_0 = 0x%h", $time, TIE_NoC_OUT_0);
`endif
      store[wp]         <= #1 TIE_NoC_OUT_0;
      wp                <= #1 wp + 1;
      rp                <= #1 rp + 1;
      TIE_NoC_OUT_0_Full    <= #1 TIE_NoC_OUT_0_Full;
    end
    else if (TIE_NoC_OUT_0_PushReq && !TIE_NoC_OUT_0_Full) begin
`ifdef DISPLAY_IO
      $display("%t TIE_NoC_OUT_0 = 0x%h", $time, TIE_NoC_OUT_0);
`endif
      store[wp]         <= #1 TIE_NoC_OUT_0;
      wp                <= #1 wp + 1;
      rp                <= #1 rp;
      TIE_NoC_OUT_0_Full    <= #1 ((((wp + 1) % 4) == rp) ? 1'b1 : 1'b0);
    end
    else if (TIE_NoC_IN_1_PopReq && !TIE_NoC_IN_1_Empty) begin
      wp                <= #1 wp;
      rp                <= #1 rp + 1;
      TIE_NoC_OUT_0_Full    <= #1 1'b0;
    end
    else begin
      wp                <= #1 wp;
      rp                <= #1 rp;
      TIE_NoC_OUT_0_Full    <= #1 TIE_NoC_OUT_0_Full;
    end
  end


endmodule

