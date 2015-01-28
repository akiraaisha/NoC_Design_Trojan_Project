`include "tie_fifo.v"
//FLIT_BITS = {EXTRA + TYPE + Y_ADDR + X_ADDR + APP_ID + DATA}\

`define BASIC_NI 

module network_interface_4 #(parameter 	DATA_WIDTH = 16, 
										FLIT_WIDTH = 20,
										APP_ID_BITS = 2,
							           	FIFO_0_DEPTH_BITS = 6,
										FIFO_1_DEPTH_BITS = 3,
										FIFO_2_DEPTH_BITS = 6,
										FIFO_3_DEPTH_BITS = 6) 
(
    input clk,
    input reset,
	input ON,
	input [1:0] DEMUX,
    input [FLIT_WIDTH-1:0] write_data,
    input wrtEn,
    input rdEn,
    
    output [DATA_WIDTH-1:0] read_data,
    output full,
    output empty,
	output active
); 


//==================================================================
`ifdef BASIC_NI

wire wrtEn_temp[0:1];
wire rdEn_temp[0:1];
wire full_temp[0:1];
wire empty_temp[0:1];
wire [DATA_WIDTH-1:0] read_data_temp [0:1];
//wire [DATA_WIDTH-1:0] read_data [0:1],
wire valid[0:1];
tie_fifo #(DATA_WIDTH,FIFO_0_DEPTH_BITS) ip_fifo_data (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[0], rdEn_temp[0], 1'b0, read_data_temp[0],full_temp[0],empty_temp[0]);
tie_fifo #(DATA_WIDTH,FIFO_1_DEPTH_BITS) ip_fifo_cred (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[1], rdEn_temp[1], 1'b0, read_data_temp[1],full_temp[1],empty_temp[1]);

assign wrtEn_temp[0] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b00) ? wrtEn : 0; 
assign wrtEn_temp[1] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b11) ? wrtEn : 0; 

assign rdEn_temp[0]     =   ( DEMUX == 2'b00) ? rdEn : 0;
assign rdEn_temp[1]     =   ( DEMUX == 2'b11) ? rdEn : 0;

assign read_data        =   ( DEMUX == 2'b00) ? read_data_temp[0] : ( DEMUX == 2'b11) ? read_data_temp[1]: 0;
assign empty 			= 	( DEMUX == 2'b00) ? empty_temp[0] : ( DEMUX == 2'b11) ? empty_temp[1]: 1;
assign full				=   ( full_temp[0] | full_temp[1]);

//assign active 			=	(~empty_temp[0]) | (~empty_temp[1]) | (wrtEn) | (rdEn);
assign active 			=	(~empty_temp[0]) | (~empty_temp[1]) | (wrtEn);

`endif

//==================================================================
`ifdef ADVANCE_NI

wire wrtEn_temp[0:3];
wire rdEn_temp[0:3];
wire valid_temp[0:3];
wire full_temp[0:3];
wire empty_temp[0:3];
wire [DATA_WIDTH-1:0] read_data_temp [0:3],

tie_fifo #(DATA_WIDTH,FIFO_0_DEPTH_BITS) ip_fifo_0 (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[0], rdEn_temp[0], 1'b0, read_data_temp[0], ,full_temp[0],empty_temp[0]);
tie_fifo #(DATA_WIDTH,FIFO_1_DEPTH_BITS) ip_fifo_1 (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[1], rdEn_temp[1], 1'b0, read_data_temp[1], ,full_temp[1],empty_temp[1]);
tie_fifo #(DATA_WIDTH,FIFO_2_DEPTH_BITS) ip_fifo_2 (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[2], rdEn_temp[2], 1'b0, read_data_temp[2], ,full_temp[2],empty_temp[2]);
tie_fifo #(DATA_WIDTH,FIFO_3_DEPTH_BITS) ip_fifo_2 (clk,reset,ON, write_data[DATA_WIDTH - 1:0], wrtEn_temp[3], rdEn_temp[3], 1'b0, read_data_temp[3], ,full_temp[3],empty_temp[3]);

assign wrtEn_temp[0] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b00) ? wrtEn : 0; 
assign wrtEn_temp[1] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b01) ? wrtEn : 0; 
assign wrtEn_temp[2] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b10) ? wrtEn : 0; 
assign wrtEn_temp[3] 	= 	((write_data[(APP_ID_BITS + DATA_WIDTH - 1) : (DATA_WIDTH)]) == 2'b11) ? wrtEn : 0; 

assign rdEn_temp[0]     =   ( DEMUX == 2'b00) ? rdEn : 0;
assign rdEn_temp[1]     =   ( DEMUX == 2'b01) ? rdEn : 0;
assign rdEn_temp[2]     =   ( DEMUX == 2'b10) ? rdEn : 0;
assign rdEn_temp[3]     =   ( DEMUX == 2'b11) ? rdEn : 0;

assign empty 			= 	( DEMUX == 2'b00) ? empty_temp[0] : 
							( DEMUX == 2'b01) ? empty_temp[1] : 
							( DEMUX == 2'b10) ? empty_temp[2] :
							( DEMUX == 2'b11) ? empty_temp[3] : 1;

assign full				=   ( full_temp[0] | full_temp[1] | full_temp[2] | full_temp[3]);

`endif

endmodule

