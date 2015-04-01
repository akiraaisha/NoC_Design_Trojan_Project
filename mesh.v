
/* Basic FLIT FORMAT
FLIT_BITS = {EXTRA + TYPE + Y_ADDR + X_ADDR + APP_ID + DATA}*/


//////////////////////////////////////////////////////// Include Files///////////////////////////
`include "rc_arb_xbar.v"
`include "queue.v"
`include "network_interface_4.v"
`include "PowerManager.v"
//`include "/home/hbokhari/CODES_PAPER_BENCHMARKS/2x2_Mesh_test/verilog/tie_fifo.v"
////////////////////////////////////////////////////////////////////////////////////////////////

//`define COLLECT_DATA 
`define SWITCH_EXP
`timescale 1ns/1ps


module mesh (); 

//************************************************ Mesh Parameters ************************************

	localparam N_ROUTER   = 4;
	localparam R_ID  	  = 4; 		// Center router in 3x3 mesh
	localparam RT_ALG     = 0 ; 	// XY-DOR
	localparam ROW        = 4;		//Modified original value = 8
	localparam COLOUMN    = 4;		//Modified original value = 8
	localparam ID_BITS    = 4;		//Modified original value = 6
	localparam EXTRA_BITS = 4;		//Modified original value = 0 Used as source ID
	localparam TYPE_BITS  = 0;		//Modified original value = 0
	localparam APP_ID_BITS = 2;
   localparam DEPTH_BITS = 3;
	localparam DATA_WIDTH = 32;
	localparam FLIT_WIDTH = EXTRA_BITS  + TYPE_BITS + ID_BITS + APP_ID_BITS + DATA_WIDTH;
	
	localparam SWITCHES =  ROW * COLOUMN;
  	localparam CORES = SWITCHES;
	localparam SWITCH_TO_SWITCH = 1 ;
	localparam VC_BITS = 0;
//////////////////////////////////////////////////////////////////////////////////////////////////////	
	

//************************************************* Power Parameters **********************************
	localparam SLOTS = 20;
	localparam POWER_TICK_RESOLUTION = 1000;
	localparam WAKE_UP_LATENCY = 20;
	localparam ACTIVITY_DETECT = 15;
//////////////////////////////////////////////////////////////////////////////////////////////////////	
	

//*********************************************** Synthetic Traffic Parameters **************************
	localparam UNIFORM = 0, BIT_COMP = 1, TRANS = 2, SHUFFLE = 3; 
	localparam TRAFFIC = BIT_COMP;
/////////////////////////////////////////////////////////////////////////////////////////////////////////




/*TODO*/
   wire [FLIT_WIDTH - DATA_WIDTH - 1: 0] DUMMY_WIRES [0:SWITCHES-1];
	wire [1:0] NoC_DEMUX_WIRES [0:SWITCHES-1]; //App ID (demonstrated as demux)
	
//*************************************************** Power Wires ****************************************
	wire active[0: SWITCHES-1];					//Activate wire
	wire R_active[0: SWITCHES-1];					//Router Activation
	wire NI_active[0: SWITCHES-1];				//Network Interface Activation 
	wire [15:0]Iteration_no_4_wire;
	wire [1 :0]Iter_flag[0: SWITCHES-1];
//////////////////////////////////////////////////////////////////////////////////////////////////////////


	
	wire [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] 			s_flits_in [0: SWITCHES-1];
	wire [(SWITCH_TO_SWITCH *4) - 1: 0]  								s_valid_in [0: SWITCHES-1]; 
	  
	wire [(FLIT_WIDTH * (SWITCH_TO_SWITCH *4)) - 1: 0] 			s_flits_out [0: SWITCHES-1]; 
	wire [(SWITCH_TO_SWITCH *4) - 1: 0] 								s_valid_out [0: SWITCHES-1]; 
	wire [(SWITCH_TO_SWITCH *4) - 1: 0] 								s_waiting_out [0: SWITCHES-1];   /* Power Controlling Logic*/ 

	wire [(((1 << VC_BITS) * (SWITCH_TO_SWITCH *4)) - 1): 0] 	s_empty_in  [0: SWITCHES-1]; 
	wire [(((1 << VC_BITS) * (SWITCH_TO_SWITCH *4)) - 1): 0]	   s_full_in   [0: SWITCHES-1]; 
	wire [(((1 << VC_BITS) * (SWITCH_TO_SWITCH *4)) - 1): 0]  	s_off_in    [0: SWITCHES-1]; 		/* Power Controlling Logic*/ 

	wire [(((1 << VC_BITS) * (SWITCH_TO_SWITCH *4)) - 1): 0] 	s_empty_out [0: SWITCHES-1];
	wire [(((1 << VC_BITS) * (SWITCH_TO_SWITCH *4)) - 1): 0] 	s_full_out  [0: SWITCHES-1];  
	  
	wire [(FLIT_WIDTH * SWITCH_TO_SWITCH) - 1: 0]   				single_s_flits_in [0: (SWITCHES*4)-1]; 
	wire [SWITCH_TO_SWITCH - 1: 0] 										single_s_valid_in [0: (SWITCHES*4)-1];  
	wire [(FLIT_WIDTH * SWITCH_TO_SWITCH) - 1: 0] 					single_s_flits_out[0: (SWITCHES*4)-1]; 
	wire [SWITCH_TO_SWITCH - 1: 0] 										single_s_valid_out[0: (SWITCHES*4)-1];  
	wire [SWITCH_TO_SWITCH - 1: 0]									 	single_s_waiting_out[0: (SWITCHES*4)-1];  /* Power Controlling Logic */
	  
	wire [(((1 << VC_BITS) * SWITCH_TO_SWITCH) - 1): 0] 			single_s_empty_in  [0: (SWITCHES*4)-1]; 
	wire [(((1 << VC_BITS) * SWITCH_TO_SWITCH) - 1): 0] 			single_s_full_in   [0: (SWITCHES*4)-1];
	wire [(((1 << VC_BITS) * SWITCH_TO_SWITCH) - 1): 0] 			single_s_empty_out [0: (SWITCHES*4)-1]; 
	wire [(((1 << VC_BITS) * SWITCH_TO_SWITCH) - 1): 0] 			single_s_full_out  [0: (SWITCHES*4)-1];
	wire [(((1 << VC_BITS) * SWITCH_TO_SWITCH) - 1): 0] 			single_s_off_in    [0: (SWITCHES*4)-1];  /* Power Controlling Logic*/

	//---------------------------------------------------------------------------- 
	//output from DUT
	//----------------------------------------------------------------------------	
	// Outgoing Flits  
  	wire [(FLIT_WIDTH - 1): 0] 		c_flits_out   [0 : SWITCHES - 1]; 		/*TODO*/ // Do we need to send Routing bits to core? 
  	wire [0:0]								c_valid_out   [0 : SWITCHES - 1]; 
	wire [0:0]								c_waiting_out [0 : SWITCHES - 1];		/* Power */
    // Outgoing Credits
  	wire [0:0]								c_empty_out [0 : SWITCHES - 1]; 
  	wire [0:0]								c_full_out  [0 : SWITCHES - 1];
  	
	//----------------------------------------------------------------------------
	//input to DUT
	//----------------------------------------------------------------------------	
    //reg ON;     
	wire ON [0 : SWITCHES - 1];
  	reg reset;
  	
	// Router ID 
  	wire [(ID_BITS - 1): 0] 			router_ID[0 : SWITCHES - 1];
	
	// Incomming Flits
	wire  [(FLIT_WIDTH - 1): 0] 		c_flits_in [0 : SWITCHES - 1];
  	wire  [0:0]								c_valid_in [0 : SWITCHES - 1]; 
	// Incomming Credits
  	wire  [0:0]								c_empty_in [0 : SWITCHES - 1]; 
  	wire  [0:0]								c_full_in  [0 : SWITCHES - 1];
	wire  [0:0]								c_off_in   [0 : SWITCHES - 1]; /* Power*/
  
	wire  [1:0] 							demux_wires [0 : SWITCHES - 1];
	/* Power */
	// These wires shall be i/o to/from the per router Power Controller
	wire 	  									signal_off    			[0 : SWITCHES - 1]; // signal current power 
															// state of the router (0 -> ON, 1 -> OFF)

	wire 										request_to_on 			[0 : SWITCHES - 1]; // requests coming from 
															// neighbor routers for switching on
	wire [3:0]								request_to_on_single 	[0 : SWITCHES - 1]; 
	wire        							request_to_on_from_core [0 : SWITCHES - 1];

	wire 										pwr_gate	[0 : SWITCHES - 1] ;
	wire 										clk_gate	[0 : SWITCHES - 1] ;

	wire 										PM_prog	[0 : SWITCHES - 1] ;

	/* More I/O Stuff*/
	wire [31 : 0]  						data_from_NI [0 : SWITCHES - 1];
	reg 		   							rd_NI        [0 : SWITCHES - 1]; 
	wire 		  								empty_NI     [0 : SWITCHES - 1]; 
  
	reg  [(FLIT_WIDTH - 1): 0]  		data_to_NoC  [0 : SWITCHES - 1];
	reg  		   							valid_to_NoC [0 : SWITCHES - 1];
	wire  		   						full_from_NoC[0 : SWITCHES - 1];

	/* Traffic Pattern Stuff*/
	wire [(ID_BITS - 1): 0] 			recv_address [0 : SWITCHES - 1];
	/* Power */
	reg  	  									signal_off_sim    		[0 : SWITCHES - 1];
	
//**************************************************** Clock Signals **********************************************
	reg CLK = 0;
	always #0.5 CLK = ~CLK;

	reg CLK_13 = 0;
	always #0.667 CLK_13 = ~CLK_13;

	reg CLK_2 = 0;
	always @(posedge CLK)
		CLK_2 <= ~CLK_2;

	reg CLK_4 = 0;
	always @(posedge CLK_2)
		CLK_4 <= ~CLK_4;

	wire CLK_SYS = CLK_13;
	//wire CLK_SYS = CLK_2;
	//wire CLK_SYS = CLK;
	//wire CLK_SYS = CLK_4;
	//integer ticks = 0;	
	reg [63:0] ticks = 0;
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	/* Synthetic Traffic */
	localparam NORMAL = 0;
	localparam BURST  = 1;

	localparam BURST_ON 	= 500;
	localparam BURST_OFF	= 500;

	localparam BURST_MODE   = NORMAL;
	
	localparam INJ_VECTOR_LENGHT = 400;
	localparam INJ_RATE   = 180;
	localparam START_SIM = 10000;
	//localparam REAL_INJ_RATE = 320/80;
	reg [INJ_VECTOR_LENGHT - 1 : 0 ] node_vectors [0 : SWITCHES - 1];
	

	integer m,n;
	integer vector_index;
	// Flit Reservoir
	localparam FLIT_RES_SIZE = 16384;
	reg [31:0] inj_data_fifo [0 : SWITCHES - 1][0 : FLIT_RES_SIZE - 1]; // we can save upto 256 bytes
	reg [ 12:0] rd_pointer [0 : SWITCHES - 1];
	reg [ 12:0] wr_pointer [0 : SWITCHES - 1];
	
	// For Switch Experiment

	// Slave States
	localparam  SLAVE_NORMAL  = 0;
   localparam  SLAVE_STOPPED = 1;

	// Master States
	localparam  MASTER_WAITING_FOR_COMMAND  = 3'b000;
   localparam  MATSER_SEND_STOP_PACKETS    = 3'b001;
	localparam  MATSER_WAIT_FOR_FLUSH       = 3'b010;
	localparam  MATSER_WAIT_FOR_FLUSH_2     = 3'b011;
	localparam  MATSER_SEND_SWITCH_PACKETS  = 3'b100;
	localparam  MATSER_SEND_ENABLE_PACKETS  = 3'b101;

	reg         slave_PM_state  [0 : SWITCHES - 1];
	reg [2:0]   master_PM_state ;

	reg [(FLIT_WIDTH - 1): 0] master_PM_data_flit  = 0;
	reg                       master_PM_flit_valid = 0;

	reg NOC_MIGRATE = 0;
	reg [(ID_BITS - 1): 0] slave_ID = (SWITCHES - 1);
	
	`ifdef SWITCH_EXP
	initial begin
		#10000 NOC_MIGRATE = 0;
	end
	`endif

	`ifdef SWITCH_EXP
	reg flush_state [0: COLOUMN - 1][0: ROW -1];
	integer xx,yy;
	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			for (xx = 0; xx < COLOUMN; xx= xx + 1) begin
				for (yy = 0; yy < ROW; yy= yy + 1) begin
					flush_state[xx][yy] = 1'b0;
				end
			end
		end

		else begin
			for (xx = 0; xx < COLOUMN; xx = xx + 1) begin
				for (yy = 0; yy < ROW; yy = yy + 1) begin
					flush_state[xx][yy] = ((yy == 0) && (xx != (COLOUMN - 1))) ? (flush_state[xx + 1][yy] | flush_state[xx][yy + 1] | R_active[(xx * COLOUMN) + yy]):
										  ((yy == 0) && (xx == (COLOUMN - 1))) ? (flush_state[xx][yy + 1] | R_active[(xx * COLOUMN) + yy]):
										  ((yy == (ROW - 1))) ? ( R_active[(xx * COLOUMN) + yy]): 
										  ((yy != 0) && (yy != (ROW - 1)))? (flush_state[xx][yy + 1] | R_active[(xx * COLOUMN) + yy]) : flush_state[xx][yy] ;
																				  
				end
			end
		
		end
	end
	
	`endif

	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			master_PM_state = MASTER_WAITING_FOR_COMMAND;
		end
		else begin
			case (master_PM_state)
				MASTER_WAITING_FOR_COMMAND: begin
					if (NOC_MIGRATE)
						master_PM_state = MATSER_SEND_STOP_PACKETS;
					else
						master_PM_state = MASTER_WAITING_FOR_COMMAND;
					slave_ID = (SWITCHES - 1);
					master_PM_flit_valid = 0;
				end
				MATSER_SEND_STOP_PACKETS: begin
					if (slave_ID != 0) begin
						if (c_valid_in[0]) begin
							slave_ID = slave_ID - 1;
						end
						master_PM_data_flit  = {slave_ID,2'b00,32'b11111111_11111111_11111111_1111111}; 
						master_PM_flit_valid = 1;
						master_PM_state = MATSER_SEND_STOP_PACKETS;
					end
					else begin
						master_PM_flit_valid = 0;
						master_PM_state = MATSER_WAIT_FOR_FLUSH;
						slave_ID = (SWITCHES - 1);
					end
				end
				MATSER_WAIT_FOR_FLUSH: begin
					if (flush_state[0][0])
						master_PM_state = MATSER_WAIT_FOR_FLUSH;
					else
						master_PM_state = MATSER_SEND_SWITCH_PACKETS;
				end
				MATSER_SEND_SWITCH_PACKETS:begin
					if (slave_ID != 0) begin
						if (c_valid_in[0]) begin
							slave_ID = slave_ID - 1;
						end
						master_PM_data_flit  = {slave_ID,2'b00,32'b11111111_11111111_11111111_1111111}; 
						master_PM_flit_valid = 1;
						master_PM_state = MATSER_SEND_SWITCH_PACKETS;
					end
					else begin
						master_PM_flit_valid = 0;
						master_PM_state = MATSER_WAIT_FOR_FLUSH_2;
						slave_ID = (SWITCHES - 1);
					end
				end
				MATSER_WAIT_FOR_FLUSH_2: begin
					if (flush_state[0][0])
						master_PM_state = MATSER_WAIT_FOR_FLUSH_2;
					else
						master_PM_state = MATSER_SEND_ENABLE_PACKETS;
				end
				MATSER_SEND_ENABLE_PACKETS:begin
					if (slave_ID != 0) begin
						if (c_valid_in[0]) begin
							slave_ID = slave_ID - 1;
						end
						master_PM_data_flit  = {slave_ID,2'b00,32'b00000000_00000000_00000000_0000000}; 
						master_PM_flit_valid = 1;
						master_PM_state = MATSER_SEND_ENABLE_PACKETS;
					end
					else begin
						master_PM_flit_valid = 0;
						master_PM_state = MASTER_WAITING_FOR_COMMAND;
						slave_ID = (SWITCHES - 1);
					end
				end
			endcase	
		end
	end	

	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				slave_PM_state[m]  <= SLAVE_NORMAL;
			end
		end
		else begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				slave_PM_state[m] 	<= (c_valid_out[m] && ticks >= START_SIM && (c_flits_out[m][DATA_WIDTH - 1 : 0]) == 32'b11111111_11111111_11111111_1111111)? SLAVE_STOPPED:
								  	   (c_valid_out[m] && ticks >= START_SIM && (c_flits_out[m][DATA_WIDTH - 1 : 0]) == 32'b00000000_00000000_00000000_0000000)? SLAVE_NORMAL:
								   	    slave_PM_state[m];
			end
		end
	end	

	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				rd_pointer[m]  <= 0;
				wr_pointer[m]  <= 0;
			end
		end
		else begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				if (node_vectors[m][vector_index]) begin
					inj_data_fifo[m][wr_pointer[m]] <= ticks[31:0];
					wr_pointer[m] <= wr_pointer[m] + 1;
				end
				if (c_valid_in[m]) begin
					rd_pointer[m] <= rd_pointer[m] + 1;
				end
			end
		end
	end	

	// Random traffic pattern generator (single vector)
	function [INJ_VECTOR_LENGHT - 1 : 0 ] random_vector;
	  input integer inj_rate;
	  integer i, ones;
	  reg [INJ_VECTOR_LENGHT - 1 : 0 ] node_vector;
	  
	  begin
		$display ("Injection Rate %d ", inj_rate); 
		for ( ones = 0 ; ones < inj_rate ;) begin
			ones = 0;
			//$display ("Ones %d ", {$random} % INJ_VECTOR_LENGHT );
			node_vector[({$random} % INJ_VECTOR_LENGHT)] = 1'b1;
			for (i = 0; i < INJ_VECTOR_LENGHT; i= i + 1) begin
				if (node_vector[i] == 1'b1) begin
					ones = ones + 1;
				end
			end
			
			$display ("Vector %b ", node_vector);
			$display ("Ones %d ", ones ); 
		end
		random_vector = node_vector; 
	  end
	endfunction

	

	
	//always @ (posedge CLK)
	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			vector_index = 0;
		end
		else if (vector_index == (INJ_VECTOR_LENGHT - 1 )) begin
			vector_index = 0;
		end
		else begin
			vector_index = vector_index + 1;
		end
	end

	
	integer h, ones;
	reg [INJ_VECTOR_LENGHT - 1 : 0 ] node_vector;
	
	initial
	begin
		for (m = 0; m < SWITCHES; m = m + 1) begin
			node_vector = 0;
			for ( ones = 0 ; ones < INJ_RATE ;) begin
				ones = 0;
				node_vector[({$random} % INJ_VECTOR_LENGHT)] = 1'b1;
				for (h = 0; h < INJ_VECTOR_LENGHT; h= h + 1) begin
					if (node_vector[h] == 1'b1) begin
						ones = ones + 1;
					end
				end
			//$display ("Vector %b ", node_vector);
			//$display ("Ones %d ", ones ); 
			end
			node_vectors[m]  = node_vector;
		end
	end
		
	/*
	always @ (posedge CLK)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				node_vectors[m]  = random_vector(INJ_RATE);
			end
		end
	end
	*/
	integer burst_measure;
	always @ (posedge CLK)
	begin
		if (reset) begin
			burst_measure = 0;
		end
		else begin
			if(burst_measure < (BURST_ON + BURST_ON))
				burst_measure = burst_measure + 1 ;
			else
				burst_measure = 0;	
		end
	end

	//always @ (posedge CLK)
	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				data_to_NoC[m]  <= 0;
				valid_to_NoC[m] <= 0;
				rd_NI[m] 		<= 1'b1; // always receive data
			end
		end

		else begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				//data_to_NoC[m]  <= {recv_address[m],2'b00,32'b00001111000011110000111100001111 };
				//data_to_NoC[m]  <= {recv_address[m],2'b00,ticks[31:0]};
				
				`ifdef SWITCH_EXP
				if ( m == 0) begin
					if ((NOC_MIGRATE == 0) && (slave_PM_state[m] == SLAVE_NORMAL)) begin
						data_to_NoC[m]  <= {m,recv_address[m],2'b00,inj_data_fifo[m][rd_pointer[m]]};
					end
					else begin
						data_to_NoC[m]  <= master_PM_data_flit;
					end
				end
				else begin
					data_to_NoC[m]  <= {m,recv_address[m],2'b00,inj_data_fifo[m][rd_pointer[m]]};//***
				end
				`else
				data_to_NoC[m]  <= {m,recv_address[m],2'b00,inj_data_fifo[m][rd_pointer[m]]};//****
				`endif
				//valid_to_NoC[m] <= 1;
				//valid_to_NoC[m] <= ~ valid_to_NoC[m];
				//valid_to_NoC[m] <= node_vectors[m][vector_index];
				`ifdef SWITCH_EXP
				if (m == 0) begin
					if (NOC_MIGRATE == 0 && (slave_PM_state[m] == SLAVE_NORMAL)) begin
						valid_to_NoC[m] <= (rd_pointer[m] < wr_pointer[m]) && (slave_PM_state[m] == SLAVE_NORMAL);
					end
					else begin
						valid_to_NoC[m] <= master_PM_flit_valid;
					end
				end
				else
					valid_to_NoC[m] <= (rd_pointer[m] < wr_pointer[m]) && (slave_PM_state[m] == SLAVE_NORMAL);
				`else
				valid_to_NoC[m] <= (rd_pointer[m] < wr_pointer[m]);
				`endif
				//valid_to_NoC[m] <=  (BURST_MODE == NORMAL) ? node_vectors[m][vector_index] :
				//					((BURST_MODE == BURST) && (burst_measure < BURST_ON))? node_vectors[m][vector_index]:1'b0;
				rd_NI[m] 		<= 1'b1; // always receive data
			end
		end
	end

	


	//------------------------------------------------------------------------------
	// Statistics From Simulation
	//------------------------------------------------------------------------------
	integer packets_received [0 : SWITCHES - 1];
	integer latencies [0 : SWITCHES - 1];
	reg sim_stop;
	always @ (posedge CLK)
	begin
		if (reset) begin
			sim_stop <= 0;
		end
		else begin
			if (ticks == 18000) begin
				sim_stop <= 1;
			end
		end
	end

	
	//always @ (negedge CLK)
	always @ (posedge CLK_SYS)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				packets_received[m]  <= 0;
				latencies[m] 		 <= 0;
			end
		end

		else begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				packets_received[m]  <= (c_valid_out[m] && ticks >= START_SIM)? (packets_received[m] + 1) : packets_received[m];
				latencies[m] 		 <= (c_valid_out[m] && ticks >= START_SIM)? (latencies[m] + (ticks[31:0] - (c_flits_out[m][DATA_WIDTH - 1 : 0]))) : latencies[m];
			end
		end
	end


	/* Power Activity*/

	reg [63:0] packets_tran  [0: SWITCHES-1];
	always @ (negedge CLK_SYS)
	begin
		if (reset) begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				packets_tran[m]  = 0;
			end
		end

		else begin
			for (m = 0; m < SWITCHES; m= m + 1) begin
				if (ticks >= START_SIM) begin
					if (c_valid_in[m])
						packets_tran[m] = packets_tran[m] + 1;
					case (s_valid_in[m])
						4'b0000 : packets_tran[m] = packets_tran[m] + 0;
						4'b0001 : packets_tran[m] = packets_tran[m] + 1;
						4'b0010 : packets_tran[m] = packets_tran[m] + 1;
						4'b0011 : packets_tran[m] = packets_tran[m] + 2;
						4'b0100 : packets_tran[m] = packets_tran[m] + 1;
						4'b0101 : packets_tran[m] = packets_tran[m] + 2;
						4'b0110 : packets_tran[m] = packets_tran[m] + 2;
						4'b0111 : packets_tran[m] = packets_tran[m] + 3;
						4'b1000 : packets_tran[m] = packets_tran[m] + 1;
						4'b1001 : packets_tran[m] = packets_tran[m] + 2;
						4'b1010 : packets_tran[m] = packets_tran[m] + 2;
						4'b1011 : packets_tran[m] = packets_tran[m] + 3;
						4'b1100 : packets_tran[m] = packets_tran[m] + 2;
						4'b1101 : packets_tran[m] = packets_tran[m] + 3;
						4'b1110 : packets_tran[m] = packets_tran[m] + 3;
						4'b1111 : packets_tran[m] = packets_tran[m] + 4;
					endcase	
				end
			end
		end
	end


	reg [63:0] aggr_packets = 0;
	reg [63:0] aggr_latencies = 0;
	reg [63:0] aggr_clk_gate_cycles = 0;
	reg [63:0] aggr_packets_trans   = 0;
	

	
	/* Power */
	reg [63:0] total_cycles;
	reg [63:0] active_cycles       [0: SWITCHES-1];
	//reg [63:0] on_cycles     	   [0: SWITCHES-1];
	reg [63:0] clk_gate_cycles     [0: SWITCHES-1];
	reg [63:0] pwr_gate_cycles     [0: SWITCHES-1];
	reg [63:0] power_ups           [0: SWITCHES-1];
	localparam WARM_UP_CYCLES = 10;

	always @ (posedge sim_stop)
	begin
		for (m = 0; m < SWITCHES; m= m + 1) begin
			//$display ("---------------------------------- Dummy Core %d ----------------------------------",router_ID[m] );  
			//$display ("Packets [%d]\t\t| Latency [%d] \t\t| Avg. Packet Latency [%d]", packets_received[m], latencies[m],latencies[m] / packets_received[m]  );
			if (m == (SWITCHES - 1)) begin
				for (n = 0; n < SWITCHES; n= n + 1) begin
					aggr_packets         = aggr_packets + packets_received[n];
					aggr_latencies       = aggr_latencies + latencies[n];
					aggr_clk_gate_cycles = aggr_clk_gate_cycles + clk_gate_cycles[n];
					aggr_packets_trans   = aggr_packets_trans + packets_tran[n];
				end
				$display ("---------------------------------- Statistics  ----------------------------------");  
				$display ("Total Packets [%d]\t| Total Latency [%d] \t| Avg. Packet Latency [%d]", aggr_packets, aggr_latencies,aggr_latencies / aggr_packets );
				$display ("Total Clk Gate Cycles [%d] , Average Clk Gate Cycle[%d] ", aggr_clk_gate_cycles, aggr_clk_gate_cycles / SWITCHES );
				$display ("Total Hops Trans [%d] , Average Hops Trans[%d] ", aggr_packets_trans, aggr_packets_trans / SWITCHES );
			end
		end
	end


	
	genvar i,row,col;
	
	
	//------------------------------------------------------------------------------
	// Packet Dest for Synthetic Traffic
	//------------------------------------------------------------------------------



	//define shuffle function
	function integer suffle;
	  input integer num;
	  integer i, temp, result;
	  begin
	    temp = ((ROW * COLOUMN) -1) / 2; 
		if (num > temp)
			result = (((num - temp) -1) <<1) + 1; 
		else 
			result = num << 1; 
		suffle = result;
	  end
	endfunction

	generate // /* Interfacing */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Traffic_recv
				assign recv_address[i] = (TRAFFIC == UNIFORM )? (vector_index):
										 (TRAFFIC == BIT_COMP)? (~router_ID[i]):
		                                 (TRAFFIC == TRANS   )? {router_ID[i][((ID_BITS/2) - 1):0], router_ID[i][(ID_BITS - 1) : ((ID_BITS)/2)]}:
										 (TRAFFIC == SHUFFLE )? suffle(router_ID[i]): ((ROW * COLOUMN) -1) / 2;
		end
	endgenerate

	//------------------------------------------------------------------------------
	// Connect Input Output ports
	//------------------------------------------------------------------------------
	generate // /* Interfacing */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Interface
			assign c_flits_in[i] 		= data_to_NoC[i];
			assign c_valid_in[i] 		= valid_to_NoC[i] & (~ c_full_out[i])  & (~signal_off[i]) & (~PM_prog[i]);
			assign full_from_NoC[i] 	= c_full_out[i] | signal_off[i];
			assign c_empty_in[i]   		= 1; /*TODO*/
			assign DUMMY_WIRES[i]	  	= c_flits_out[i][FLIT_WIDTH - 1 : DATA_WIDTH];   /*TODO*/
			assign NoC_DEMUX_WIRES[i] 	= 2'b00; 
			assign Iter_flag[i] 		= 2'b00;
			assign request_to_on_from_core[i] = valid_to_NoC[i] & signal_off[i]; /* Power */
		end
	endgenerate

	generate // /* Demux Wires */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  demux_wires_assign
			assign demux_wires[i] =  2'b00;
		end
	endgenerate

	generate // /* Connect NI and PM */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  NI_PM_Con
	 
		network_interface_4 #( 	DATA_WIDTH, 
						  	FLIT_WIDTH,
							APP_ID_BITS,
							6,
							3,
							6,
							6) NI_0 (/*CLK*/CLK_SYS,reset,ON[i], demux_wires[i], c_flits_out[i], c_valid_out[i], rd_NI[i], data_from_NI[i] ,c_full_in[i], empty_NI[i], NI_active[i]);
	
		power_manager #(DATA_WIDTH , 
						SLOTS ,
						POWER_TICK_RESOLUTION,
						WAKE_UP_LATENCY,
						ACTIVITY_DETECT) PM_0 (/*CLK*/CLK_SYS,reset,Iter_flag[i],c_flits_in[i][DATA_WIDTH-1 :0],PM_prog[i],request_to_on[i],active[i],clk_gate[i],pwr_gate[i],signal_off[i]);
		end
	endgenerate
	generate // /* Power */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Power_req
			assign request_to_on[i] =  (| request_to_on_single[i]) | request_to_on_from_core[i];
		end
	 endgenerate

	generate // /* Power */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Power_c
			assign c_off_in[i]   = 0;
			//assign signal_off[i] = signal_off_sim[i];
			//assign s_off_in[i] = 1;
		end
	 endgenerate
	
	generate // /* Power */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Power_ON_signal
			assign ON[i]     = ~(pwr_gate[i] | clk_gate [i]);
			assign active[i] = R_active[i] | NI_active[i] | (rd_pointer[i] < wr_pointer[i]);
			//assign ON[i]   = 1;
			//assign signal_off[i] = signal_off_sim[i];
			//assign s_off_in[i] = 1;
		end
	 endgenerate

	generate // /* Power */
		for (i = 0; i < SWITCHES; i= i + 1) begin :  Power_c_2
			assign PM_prog[i] = ((c_flits_in[i][((APP_ID_BITS + DATA_WIDTH)-1) : DATA_WIDTH]) == 2) ? 1 : 0;
		end
	 endgenerate

	generate /* Power */
	for (i = 0; i < SWITCHES; i= i + 1) begin :  OFF_IN_WAITING_OUT
 		 assign  s_off_in[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH] = single_s_off_in[(i*4)];
 		 assign  s_off_in[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_off_in[((i*4)+1)]; 
 		 assign  s_off_in[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_off_in[((i*4)+2)] ;
 		 assign  s_off_in[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_off_in[((i*4)+3)] ;
 		 

 		 assign  single_s_waiting_out[(i*4)] =  s_waiting_out[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_waiting_out[((i*4)+1)] =  s_waiting_out[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_waiting_out[((i*4)+2)] =  s_waiting_out[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_waiting_out[((i*4)+3)] =  s_waiting_out[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];	
 		  	    
	end
  endgenerate  

	generate /* Power */
		for (row = 0; row < ROW; row = row + 1) begin 
			for (col = 0; col < COLOUMN; col = col + 1) begin
					
				assign single_s_off_in[((COLOUMN*row + col)*4) + 0] = (col == 0) ? 0 : signal_off[(COLOUMN*row + col) - 1] ;
				assign single_s_off_in[((COLOUMN*row + col)*4) + 1] = (row == 0) ? 0 : signal_off[(COLOUMN*(row - 1) + col)] ;
				assign single_s_off_in[((COLOUMN*row + col)*4) + 2] = (col == (COLOUMN - 1)) ? 0 : signal_off[(COLOUMN*row + col) + 1];
				assign single_s_off_in[((COLOUMN*row + col)*4) + 3] = (row == (ROW - 1)) ? 0 : signal_off[(COLOUMN*(row + 1) + col)];

				assign request_to_on_single[(COLOUMN*row + col)][0] = (col == 0) ? 0 : single_s_waiting_out[(((COLOUMN*row + (col-1) )*4)+2)];
				assign request_to_on_single[(COLOUMN*row + col)][1] = (row == 0) ? 0 : single_s_waiting_out[(((COLOUMN*(row-1) + col)*4)+3)];
				assign request_to_on_single[(COLOUMN*row + col)][2] = (col == (COLOUMN - 1)) ? 0 : single_s_waiting_out[(((COLOUMN*row + (col+1))*4)+0)];
				assign request_to_on_single[(COLOUMN*row + col)][3] = (row == (ROW - 1)) ? 0 : single_s_waiting_out[(((COLOUMN*(row+1) + col)*4)+1)];
					/* Write the Power script here*/ 
					 // single_s_off_in[0]
			end	
		end
	endgenerate
	//------------------------------------------------------------------------------
	// Router Together
	//------------------------------------------------------------------------------
  generate
	for (i = 0; i < SWITCHES; i= i + 1) begin :  S_IN_OUT
 		 assign  s_flits_in[i][((FLIT_WIDTH * SWITCH_TO_SWITCH)-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[(i*4)] ;
 		 assign  s_valid_in[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[(i*4)];
 		 assign  s_flits_in[i][((2*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*4)+1)];
 		 assign  s_valid_in[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*4)+1)]; 
 		 assign  s_flits_in[i][((3*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*4)+2)] ;
 		 assign  s_valid_in[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*4)+2)] ;
 		 assign  s_flits_in[i][((4*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)] = single_s_flits_in[((i*4)+3)];
 		 assign  s_valid_in[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH] = single_s_valid_in[((i*4)+3)] ;
 		 
 		 assign  single_s_flits_out[(i*4)] =  s_flits_out[i][((FLIT_WIDTH * SWITCH_TO_SWITCH)-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[(i*4)] =  s_valid_out[i][(SWITCH_TO_SWITCH-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*4)+1)] =  s_flits_out[i][((2*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*4)+1)] =  s_valid_out[i][((2*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*4)+2)] =  s_flits_out[i][((3*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*4)+2)] =  s_valid_out[i][((3*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];
 		 assign  single_s_flits_out[((i*4)+3)] =  s_flits_out[i][((4*(FLIT_WIDTH * SWITCH_TO_SWITCH))-1) -: (FLIT_WIDTH * SWITCH_TO_SWITCH)];
 		 assign  single_s_valid_out[((i*4)+3)] =  s_valid_out[i][((4*SWITCH_TO_SWITCH)-1) -: SWITCH_TO_SWITCH];	
 		 
  		 assign  s_empty_in[i][(((1 << VC_BITS) * SWITCH_TO_SWITCH)-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_empty_in[(i*4)] ;
 		 assign  s_empty_in[i][((2*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*4)+1)];
 		 assign  s_empty_in[i][((3*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*4)+2)] ;
 		 assign  s_empty_in[i][((4*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_empty_in[((i*4)+3)];

  		 assign  s_full_in[i][(((1 << VC_BITS) * SWITCH_TO_SWITCH)-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_full_in[(i*4)] ;
 		 assign  s_full_in[i][((2*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_full_in[((i*4)+1)];
 		 assign  s_full_in[i][((3*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_full_in[((i*4)+2)] ;
 		 assign  s_full_in[i][((4*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)] = single_s_full_in[((i*4)+3)];
 		  		 
 		 assign  single_s_empty_out[(i*4)]      =  s_empty_out[i][(((1 << VC_BITS) * SWITCH_TO_SWITCH)-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*4)+1)]  =  s_empty_out[i][((2*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*4)+2)]  =  s_empty_out[i][((3*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_empty_out[((i*4)+3)]  =  s_empty_out[i][((4*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];  
 		 
 		 assign  single_s_full_out[(i*4)]      =  s_full_out[i][(((1 << VC_BITS) * SWITCH_TO_SWITCH)-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*4)+1)]  =  s_full_out[i][((2*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*4)+2)]  =  s_full_out[i][((3*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];
 		 assign  single_s_full_out[((i*4)+3)]  =  s_full_out[i][((4*((1 << VC_BITS) * SWITCH_TO_SWITCH))-1) -: ((1 << VC_BITS) * SWITCH_TO_SWITCH)];  
 		  	    
	end
  endgenerate  

 generate
	
	//`ifdef SWITCH_EXP
  	//assign  single_s_flits_in[0] = master_PM_data_flit;
 	//assign  single_s_valid_in[0] = master_PM_flit_valid;
	//`else
	assign  single_s_flits_in[0] = 0;
 	assign  single_s_valid_in[0] = 0;
	//`endif
  	assign  single_s_empty_in[0] = 0;
 	assign  single_s_full_in[0]  = 0;

	//assign  single_s_off_in[0]  = 0; /* Power */


// TODO
		 
		 assign  single_s_valid_in[(SWITCHES * 4) - 2] =  0; 	 
  		
 	for (i = 1; i < SWITCHES ; i= i + 1) begin :  SS_IN
 		 assign  single_s_flits_in[(i*4)] =  (i % COLOUMN)? single_s_flits_out[(((i-1)*4)+ 2)] : 0;
 		 assign  single_s_valid_in[(i*4)] =  (i % COLOUMN)? single_s_valid_out[(((i-1)*4)+ 2)] : 0;
  		 assign  single_s_empty_in[(i*4)] =  (i % COLOUMN)? single_s_empty_out[(((i-1)*4)+ 2)] : 0;
 		 assign  single_s_full_in[(i*4)]  =  (i % COLOUMN)?  single_s_full_out[(((i-1)*4)+ 2)] : 0;
    end 
 
 	for (i = 0; i < SWITCHES - COLOUMN ; i= i + 1) begin :  SS_IN_2
 		 assign  single_s_flits_in[((i*4)+1)] =  single_s_flits_out[(((i+COLOUMN)*4)+ 3)];
 		 assign  single_s_valid_in[((i*4)+1)] =  single_s_valid_out[(((i+COLOUMN)*4)+ 3)];  
 		 assign  single_s_empty_in[((i*4)+1)] =  single_s_empty_out[(((i+COLOUMN)*4)+ 3)];
 		 assign  single_s_full_in[((i*4)+1)]  =  single_s_full_out[(((i+COLOUMN)*4)+ 3)]; 	    
	end	
	for (i = SWITCHES - COLOUMN; i < SWITCHES ; i= i + 1) begin :  SS_IN_3 
 		 assign  single_s_flits_in[((i*4)+1)] =  0;
 		 assign  single_s_valid_in[((i*4)+1)] =  0;  
  		 assign  single_s_empty_in[((i*4)+1)] =  0;
 		 assign  single_s_full_in[((i*4)+1)]  =  0;  	    
	end	
	
	for (i = 0; i < SWITCHES - 1 ; i= i + 1) begin :  SS_IN_4
 		 assign  single_s_flits_in[((i*4)+2)] =  ((i+1) % COLOUMN)? single_s_flits_out[((i+1)*4)] : 0;
 		 assign  single_s_valid_in[((i*4)+2)] =  ((i+1) % COLOUMN)? single_s_valid_out[((i+1)*4)] : 0;	
  		 assign  single_s_empty_in[((i*4)+2)] =  ((i+1) % COLOUMN)? single_s_empty_out[((i+1)*4)] : 0;
 		 assign  single_s_full_in[((i*4)+2)] =  ((i+1) % COLOUMN)? single_s_full_out[((i+1)*4)] : 0;   	    
	end

	for (i = 0; i < COLOUMN ; i= i + 1) begin :  SS_IN_5 
 		 assign  single_s_flits_in[((i*4)+3)] = 0;
 		 assign  single_s_valid_in[((i*4)+3)] = 0; 	 
  		 assign  single_s_empty_in[((i*4)+3)] = 0;
 		 assign  single_s_full_in[((i*4)+3)] = 0; 	   
	end	
	for (i = COLOUMN; i < SWITCHES ; i= i + 1) begin :  SS_IN_6 
 		 assign  single_s_flits_in[((i*4)+3)] = single_s_flits_out[(((i-COLOUMN)*4)+ 1)];
 		 assign  single_s_valid_in[((i*4)+3)] = single_s_valid_out[(((i-COLOUMN)*4)+ 1)];  	
  		 assign  single_s_empty_in[((i*4)+3)] = single_s_empty_out[(((i-COLOUMN)*4)+ 1)];
 		 assign  single_s_full_in[((i*4)+3)]  = single_s_full_out[(((i-COLOUMN)*4)+ 1)];     
	end		
  endgenerate   


    // --------------------------------------------------------------------------------------
	// Connect the DUT																		|
	// --------------------------------------------------------------------------------------
	generate
	for (i = 0; i < SWITCHES ; i= i + 1) begin : MESH_NODE
	    	assign router_ID[i] = i;
			router_2 #(				RT_ALG ,ID_BITS,	
									FLIT_WIDTH, 
									EXTRA_BITS ,
									DEPTH_BITS,
									TYPE_BITS, 
									ROW, 
									COLOUMN, 
									APP_ID_BITS,
									N_ROUTER)   
									router_under_test(
													  	ON[i], /*CLK*/ CLK_SYS, 
														reset,  
														router_ID[i],
												
														c_flits_in[i], c_valid_in[i], 
														s_flits_in[i], s_valid_in[i],
	
														c_empty_in[i], c_full_in[i], /* power */ c_off_in[i],
														s_empty_in[i], s_full_in[i], /* power */ s_off_in[i],
	
														s_flits_out[i], s_valid_out[i], /* power */ s_waiting_out[i], 
														c_flits_out[i], c_valid_out[i], /* power */ c_waiting_out[i], 
	
														c_empty_out[i], c_full_out[i], 
														s_empty_out[i], s_full_out[i],
														R_active[i]);
	//------------------------------------------------------------------------------------------
  	end
	endgenerate
	// Clock generator
	//
		
	//initial begin
	//  reset <= 1; 
	//  #10 reset <= 0;
	  //#40 c_full_in <= 1; 
	//end

	//
	
/////////////////////////
/* Power Performance */

/*
localparam WARM_UP_CYCLES = 10;

reg [63:0] total_cycles;
reg [63:0] active_cycles       [0: SWITCHES-1];
//reg [63:0] on_cycles     	   [0: SWITCHES-1];
reg [63:0] clk_gate_cycles     [0: SWITCHES-1];
reg [63:0] pwr_gate_cycles     [0: SWITCHES-1];
reg [63:0] power_ups           [0: SWITCHES-1];
*/
integer j;

always @ (posedge CLK)
begin
		if (reset)
			total_cycles <= 0;
		else 
			total_cycles <= (ticks < WARM_UP_CYCLES) ? 0 : (total_cycles + 1);
end

always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				active_cycles[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				active_cycles[j] <= (ticks < WARM_UP_CYCLES) ? 0:
							 				 (active[j])? (active_cycles[j] + 1):active_cycles[j];
								 
			end
		end
	end

always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				clk_gate_cycles[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				clk_gate_cycles[j] <= (ticks < WARM_UP_CYCLES) ? 0:
							 				 (clk_gate[j])? (clk_gate_cycles[j] + 1):clk_gate_cycles[j];
								 
			end
		end
	end

always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				pwr_gate_cycles[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				pwr_gate_cycles[j] <= (ticks < WARM_UP_CYCLES) ? 0:
							 				 (pwr_gate[j])? (pwr_gate_cycles[j] + 1):pwr_gate_cycles[j];
								 
			end
		end
	end

initial begin
	for (j = 0; j < SWITCHES; j= j + 1) begin
				power_ups[j] <= 0;
	end
end
/*
always @ (negedge pwr_gate[0])
	power_ups[0] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[0] + 1);

always @ (negedge pwr_gate[1])
	power_ups[1] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[1] + 1);

always @ (negedge pwr_gate[2])
	power_ups[2] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[2] + 1);

always @ (negedge pwr_gate[3])
	power_ups[3] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[3] + 1);

always @ (negedge pwr_gate[4])
	power_ups[4] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[4] + 1);

always @ (negedge pwr_gate[5])
	power_ups[5] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[5] + 1);

always @ (negedge pwr_gate[6])
	power_ups[6] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[6] + 1);

always @ (negedge pwr_gate[7])
	power_ups[7] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[7] + 1);

always @ (negedge pwr_gate[8])
	power_ups[8] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[8] + 1);

always @ (negedge pwr_gate[9])
	power_ups[9] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[9] + 1);

always @ (negedge pwr_gate[10])
	power_ups[10] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[10] + 1);

always @ (negedge pwr_gate[11])
	power_ups[11] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[11] + 1);

always @ (negedge pwr_gate[12])
	power_ups[12] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[12] + 1);

always @ (negedge pwr_gate[13])
	power_ups[13] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[13] + 1);

always @ (negedge pwr_gate[14])
	power_ups[14] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[14] + 1);

always @ (negedge pwr_gate[15])
	power_ups[15] = (ticks < WARM_UP_CYCLES) ? 0: (power_ups[15] + 1);

*/

/////////


///////////////////////////////////////////////////////////////////////

`ifdef COLLECT_DATA
 
	localparam power_tick_resolution = POWER_TICK_RESOLUTION;
	localparam logging_limit = 50000000;
	//localparam SLOTS = 8;
	reg [15:0] power_ticks [0: SWITCHES-1];
	reg [7:0]  power_slot  [0: SWITCHES-1];
	reg [1:0]  power_mem   [0: SWITCHES-1][0:63];
 	
	
	reg router_activity_detect[0: SWITCHES-1];
	reg router_activity_perm[0: SWITCHES-1];
	//integer j,k;	
	integer k;
	integer router_file[0: SWITCHES-1];
	integer file;
	
	initial begin
	router_file[0] = $fopen("router_0.csv","w");
	router_file[1] = $fopen("router_1.csv","w");
	router_file[2] = $fopen("router_2.csv","w");
	router_file[3] = $fopen("router_3.csv","w");
	router_file[4] = $fopen("router_4.csv","w");
	router_file[5] = $fopen("router_5.csv","w");
	router_file[6] = $fopen("router_6.csv","w");
	router_file[7] = $fopen("router_7.csv","w");
	router_file[8] = $fopen("router_8.csv","w");
	router_file[9] = $fopen("router_9.csv","w");
	router_file[10] = $fopen("router_10.csv","w");
	router_file[11] = $fopen("router_11.csv","w");
	router_file[12] = $fopen("router_12.csv","w");
	router_file[13] = $fopen("router_13.csv","w");
	router_file[14] = $fopen("router_14.csv","w");
	router_file[15] = $fopen("router_15.csv","w");
	end

	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				power_ticks[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				power_ticks[j]<=(Iter_flag[j] == 0) ? 0:
							 	(power_ticks[j] == power_tick_resolution - 1)? 0:
								power_ticks[j] + 1;				 
			end
		end
	end
	
	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				power_slot[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				power_slot[j]<=(Iter_flag[j] == 0) ? 0:
							 	(power_ticks[j] == power_tick_resolution - 1)? (power_slot[j] + 1):
								power_slot[j];
								 
			end
		end
	end

	always @ (posedge CLK)
	begin
	
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_detect[j] <= 0;
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_detect[j] <= (Iter_flag[j] == 0) ? 0:
							 				 (power_ticks[j] == power_tick_resolution - 1)? 0: 
											  router_activity_detect[j]? 1 : active[j];
								 
			end
		end

	end

	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				for (k = 0; k < 128; k= k + 1) begin // TODO
					power_mem[j][k] <= 3;
				end
			end
		end

		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				if (power_ticks[j] == 0) begin
					for (k = 0; k < 128; k= k + 1) begin // TODO
						power_mem[j][k] <= 3;
					end
				end
				
				else if(router_activity_detect[j])begin
						power_mem[j][power_slot[j]] <= 1 ;
				end
				
				else
					power_mem[j][power_slot[j]] <= 0  ;			 
			end
		end
	end

/*
	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				signal_off_sim[j] = 0;
			end
		end
		else if (ticks == 500000) begin
				for (j = 0; j < SWITCHES; j= j + 1) begin
					//signal_off_sim[j] = (j == 7) ? 1 : 0;
					//signal_off_sim[j] = (j == 7) ? 1 : 0;
					signal_off_sim[j] = (j == 7) ? 0 : 0;
				end		
			end
		else begin
				for (j = 0; j < SWITCHES; j= j + 1) begin
					signal_off_sim[j] = signal_off_sim[j];
				end		
		end
	end	
*/
/////////////////////////////////////////////////////////////////////////////////

/*
	always @ (posedge Iter_flag[0][0])
		$fwrite(router_file[0],"2,");

	always @ (posedge Iter_flag[1][0])
		$fwrite(router_file[1],"2,");

	always @ (posedge Iter_flag[2][0])
		$fwrite(router_file[2],"2,");

	always @ (posedge Iter_flag[3][0])
		$fwrite(router_file[3],"2,");
	
	always @ (posedge Iter_flag[4][0])
		$fwrite(router_file[4],"2,");

	always @ (posedge Iter_flag[5][0])
		$fwrite(router_file[5],"2,");
	
	always @ (posedge Iter_flag[6][0]) begin
		$fwrite(router_file[6],"2,");
		$fwrite(router_file[6],power_slot[6]);
		$fwrite(router_file[6],",");
	end

	always @ (posedge Iter_flag[7][0])
		$fwrite(router_file[7],"2,");

	always @ (posedge Iter_flag[8][0])
		$fwrite(router_file[8],"2,");



	///////////////////////////////////////
	always @ (negedge Iter_flag[0][0]) begin
		//case (power_mem[0][power_slot[0]])
		case (router_activity_detect[0])
			0: $fwrite(router_file[0],"0,");
			1: $fwrite(router_file[0],"1,");
			default: ;
		endcase
	end
		
	always @ (negedge Iter_flag[1][0]) begin
		//case (power_mem[1][power_slot[1]])
		case (router_activity_detect[1])
			0: $fwrite(router_file[1],"0,");
			1: $fwrite(router_file[1],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[2][0]) begin
		//case (power_mem[2][power_slot[2]])
		case (router_activity_detect[2])
			0: $fwrite(router_file[2],"0,");
			1: $fwrite(router_file[2],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[3][0]) begin
		//case (power_mem[3][power_slot[3]])
		case (router_activity_detect[3])
			0: $fwrite(router_file[3],"0,");
			1: $fwrite(router_file[3],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[4][0]) begin
		//case (power_mem[4][power_slot[4]])
		case (router_activity_detect[4])
			0: $fwrite(router_file[4],"0,");
			1: $fwrite(router_file[4],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[5][0]) begin
		//case (power_mem[5][power_slot[5]])
		case (router_activity_detect[5])
			0: $fwrite(router_file[5],"0,");
			1: $fwrite(router_file[5],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[6][0]) begin
		//case (power_mem[6][power_slot[6]])
		case (router_activity_detect[6])
			0: 	begin
				$fwrite(router_file[6],"0,");
				$fwrite(router_file[6],power_slot[6]);
				$fwrite(router_file[6],",");
				$fwrite(router_file[6],"999,");
				end
			1: 	begin
				$fwrite(router_file[6],"1,");
				$fwrite(router_file[6],power_slot[6]);
				$fwrite(router_file[6],",");
				$fwrite(router_file[6],"999,");
				end
			default: ;
		endcase
	end
	
	always @ (negedge Iter_flag[7][0]) begin
		//case (power_mem[7][power_slot[7]])
		case (router_activity_detect[7])
			0: $fwrite(router_file[7],"0,");
			1: $fwrite(router_file[7],"1,");
			default: ;
		endcase
	end

	always @ (negedge Iter_flag[8][0]) begin
		//case (power_mem[8][power_slot[8]])
		case (router_activity_detect[8])
			0: $fwrite(router_file[8],"0,");
			1: $fwrite(router_file[8],"1,");
			default: ;
		endcase
	end

*/

///////////////////////////////////////////////////////////////////

	always @ (posedge CLK)
	begin
		if(ticks == logging_limit) begin
	
			$fclose(router_file[0]);
			$fclose(router_file[1]);
			$fclose(router_file[2]);
			$fclose(router_file[3]);
			$fclose(router_file[4]);
			$fclose(router_file[5]);
			$fclose(router_file[6]);
			$fclose(router_file[7]);
			$fclose(router_file[8]);
			$fclose(router_file[9]);
			$fclose(router_file[10]);
			$fclose(router_file[11]);
			$fclose(router_file[12]);
			$fclose(router_file[13]);
			$fclose(router_file[14]);
			$fclose(router_file[15]);
	
		end
		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				if ((power_ticks[j] == power_tick_resolution - 1) & (~reset)) begin
					//if(Iter_flag[j]) begin
						file = router_file[j];
						//if (power_mem[j][power_slot[j]] == 1) begin
						if (router_activity_detect[j]) begin
							case (j)
								0 : begin
									$fwrite(router_file[0],"1,");
									$fwrite(router_file[0],power_slot[j]);
									$fwrite(router_file[0],",");
									end
								1 : begin
									$fwrite(router_file[1],"1,");
									$fwrite(router_file[1],power_slot[j]);
									$fwrite(router_file[1],",");
									end
								2 : begin
									$fwrite(router_file[2],"1,");
									$fwrite(router_file[2],power_slot[j]);
									$fwrite(router_file[2],",");
									end
								3 : begin
									$fwrite(router_file[3],"1,");
									$fwrite(router_file[3],power_slot[j]);
									$fwrite(router_file[3],",");
									end
								4 : begin
									$fwrite(router_file[4],"1,");
									$fwrite(router_file[4],power_slot[j]);
									$fwrite(router_file[4],",");
									end
								5 : begin
									$fwrite(router_file[5],"1,");
									$fwrite(router_file[5],power_slot[j]);
									$fwrite(router_file[5],",");
									end
								6 : begin
									$fwrite(router_file[6],"1,");
									$fwrite(router_file[6],power_slot[j]);
									$fwrite(router_file[6],",");
									end
								7 : begin
									$fwrite(router_file[7],"1,");
									$fwrite(router_file[7],power_slot[j]);
									$fwrite(router_file[7],",");
									end
								8 : begin
									$fwrite(router_file[8],"1,");
									$fwrite(router_file[8],power_slot[j]);
									$fwrite(router_file[8],",");
									end
								9 : begin
									$fwrite(router_file[9],"1,");
									$fwrite(router_file[9],power_slot[j]);
									$fwrite(router_file[9],",");
									end
								10: begin
									$fwrite(router_file[10],"1,");
									$fwrite(router_file[10],power_slot[j]);
									$fwrite(router_file[10],",");
									end
								11: begin
									$fwrite(router_file[11],"1,");
									$fwrite(router_file[11],power_slot[j]);
									$fwrite(router_file[11],",");
									end
								12: begin
									$fwrite(router_file[12],"1,");
									$fwrite(router_file[12],power_slot[j]);
									$fwrite(router_file[12],",");
									end
								13: begin
									$fwrite(router_file[13],"1,");
									$fwrite(router_file[13],power_slot[j]);
									$fwrite(router_file[13],",");
									end
								14: begin
									$fwrite(router_file[14],"1,");
									$fwrite(router_file[14],power_slot[j]);
									$fwrite(router_file[14],",");
									end
								15: begin
									$fwrite(router_file[15],"1,");
									$fwrite(router_file[15],power_slot[j]);
									$fwrite(router_file[15],",");
									end
									
							endcase
						end
						//else if (power_mem[j][power_slot[j]] == 0) begin
						else if (router_activity_detect[j] == 0) begin
							case (j)
								0 : begin
									$fwrite(router_file[0],"0,");
									$fwrite(router_file[0],power_slot[j]);
									$fwrite(router_file[0],",");
									end
								1 : begin
									$fwrite(router_file[1],"0,");
									$fwrite(router_file[1],power_slot[j]);
									$fwrite(router_file[1],",");
									end
								2 : begin
									$fwrite(router_file[2],"0,");
									$fwrite(router_file[2],power_slot[j]);
									$fwrite(router_file[2],",");
									end
								3 : begin
									$fwrite(router_file[3],"0,");
									$fwrite(router_file[3],power_slot[j]);
									$fwrite(router_file[3],",");
									end
								4 : begin
									$fwrite(router_file[4],"0,");
									$fwrite(router_file[4],power_slot[j]);
									$fwrite(router_file[4],",");
									end
								5 : begin
									$fwrite(router_file[5],"0,");
									$fwrite(router_file[5],power_slot[j]);
									$fwrite(router_file[5],",");
									end
								6 : begin
									$fwrite(router_file[6],"0,");
									$fwrite(router_file[6],power_slot[j]);
									$fwrite(router_file[6],",");
									end
								7 : begin
									$fwrite(router_file[7],"0,");
									$fwrite(router_file[7],power_slot[j]);
									$fwrite(router_file[7],",");
									end
								8 : begin
									$fwrite(router_file[8],"0,");
									$fwrite(router_file[8],power_slot[j]);
									$fwrite(router_file[8],",");
									end
								9 : begin
									$fwrite(router_file[9],"0,");
									$fwrite(router_file[9],power_slot[j]);
									$fwrite(router_file[9],",");
									end
								10: begin
									$fwrite(router_file[10],"0,");
									$fwrite(router_file[10],power_slot[j]);
									$fwrite(router_file[10],",");
									end
								11: begin
									$fwrite(router_file[11],"0,");
									$fwrite(router_file[11],power_slot[j]);
									$fwrite(router_file[11],",");
									end
								12: begin
									$fwrite(router_file[12],"0,");
									$fwrite(router_file[12],power_slot[j]);
									$fwrite(router_file[12],",");
									end
								13: begin
									$fwrite(router_file[13],"0,");
									$fwrite(router_file[13],power_slot[j]);
									$fwrite(router_file[13],",");
									end
								14: begin
									$fwrite(router_file[14],"0,");
									$fwrite(router_file[14],power_slot[j]);
									$fwrite(router_file[14],",");
									end
								15: begin
									$fwrite(router_file[15],"0,");
									$fwrite(router_file[15],power_slot[j]);
									$fwrite(router_file[15],",");
									end
							endcase
					    end
						
				end
				else if ((power_ticks[j] < power_tick_resolution - 1) 
						& (power_ticks[j] != 0)	 
						& (~reset) & (Iter_flag[j] == 0))begin
						file = router_file[j];
						//if (power_mem[j][power_slot[j]] == 1) begin
						if (router_activity_detect[j]) begin
							case (j)
								0 : begin
									$fwrite(router_file[0],"1,");
									$fwrite(router_file[0],power_slot[j]);
									$fwrite(router_file[0],",");
									$fwrite(router_file[0],"999");
									$fwrite(router_file[0],",");
									end
								1 : begin
									$fwrite(router_file[1],"1,");
									$fwrite(router_file[1],power_slot[j]);
									$fwrite(router_file[1],",");
									$fwrite(router_file[1],"999");
									$fwrite(router_file[1],",");
									end
								2 : begin
									$fwrite(router_file[2],"1,");
									$fwrite(router_file[2],power_slot[j]);
									$fwrite(router_file[2],",");
									$fwrite(router_file[2],"999");
									$fwrite(router_file[2],",");
									end
								3 : begin
									$fwrite(router_file[3],"1,");
									$fwrite(router_file[3],power_slot[j]);
									$fwrite(router_file[3],",");
									$fwrite(router_file[3],"999");
									$fwrite(router_file[3],",");
									end
								4 : begin
									$fwrite(router_file[4],"1,");
									$fwrite(router_file[4],power_slot[j]);
									$fwrite(router_file[4],",");
									$fwrite(router_file[4],"999");
									$fwrite(router_file[4],",");
									end
								5 : begin
									$fwrite(router_file[5],"1,");
									$fwrite(router_file[5],power_slot[j]);
									$fwrite(router_file[5],",");
									$fwrite(router_file[5],"999");
									$fwrite(router_file[5],",");
									end
								6 : begin
									$fwrite(router_file[6],"1,");
									$fwrite(router_file[6],power_slot[j]);
									$fwrite(router_file[6],",");
									$fwrite(router_file[6],"999");
									$fwrite(router_file[6],",");
									end
								7 : begin
									$fwrite(router_file[7],"1,");
									$fwrite(router_file[7],power_slot[j]);
									$fwrite(router_file[7],",");
									$fwrite(router_file[7],"999");
									$fwrite(router_file[7],",");
									end
								8 : begin
									$fwrite(router_file[8],"1,");
									$fwrite(router_file[8],power_slot[j]);
									$fwrite(router_file[8],",");
									$fwrite(router_file[8],"999");
									$fwrite(router_file[8],",");
									end
								9 : begin
									$fwrite(router_file[9],"1,");
									$fwrite(router_file[9],power_slot[j]);
									$fwrite(router_file[9],",");
									$fwrite(router_file[9],"999");
									$fwrite(router_file[9],",");
									end
								10: begin
									$fwrite(router_file[10],"1,");
									$fwrite(router_file[10],power_slot[j]);
									$fwrite(router_file[10],",");
									$fwrite(router_file[10],"999");
									$fwrite(router_file[10],",");
									end
								11 : begin
									$fwrite(router_file[11],"1,");
									$fwrite(router_file[11],power_slot[j]);
									$fwrite(router_file[11],",");
									$fwrite(router_file[11],"999");
									$fwrite(router_file[11],",");
									end
								12 : begin
									$fwrite(router_file[12],"1,");
									$fwrite(router_file[12],power_slot[j]);
									$fwrite(router_file[12],",");
									$fwrite(router_file[12],"999");
									$fwrite(router_file[12],",");
									end
								13 : begin
									$fwrite(router_file[13],"1,");
									$fwrite(router_file[13],power_slot[j]);
									$fwrite(router_file[13],",");
									$fwrite(router_file[13],"999");
									$fwrite(router_file[13],",");
									end
								14 : begin
									$fwrite(router_file[14],"1,");
									$fwrite(router_file[14],power_slot[j]);
									$fwrite(router_file[14],",");
									$fwrite(router_file[14],"999");
									$fwrite(router_file[14],",");
									end
								15 : begin
									$fwrite(router_file[15],"1,");
									$fwrite(router_file[15],power_slot[j]);
									$fwrite(router_file[15],",");
									$fwrite(router_file[15],"999");
									$fwrite(router_file[15],",");
									end

							endcase
						end
						//else if (power_mem[j][power_slot[j]] == 0) begin
						else if (router_activity_detect[j] == 0) begin
							case (j)
								0 : begin
									$fwrite(router_file[0],"0,");
									$fwrite(router_file[0],power_slot[j]);
									$fwrite(router_file[0],",");
									$fwrite(router_file[0],"999");
									$fwrite(router_file[0],",");
									end
								1 : begin
									$fwrite(router_file[1],"0,");
									$fwrite(router_file[1],power_slot[j]);
									$fwrite(router_file[1],",");
									$fwrite(router_file[1],"999");
									$fwrite(router_file[1],",");
									end
								2 : begin
									$fwrite(router_file[2],"0,");
									$fwrite(router_file[2],power_slot[j]);
									$fwrite(router_file[2],",");
									$fwrite(router_file[2],"999");
									$fwrite(router_file[2],",");
									end
								3 : begin
									$fwrite(router_file[3],"0,");
									$fwrite(router_file[3],power_slot[j]);
									$fwrite(router_file[3],",");
									$fwrite(router_file[3],"999");
									$fwrite(router_file[3],",");
									end
								4 : begin
									$fwrite(router_file[4],"0,");
									$fwrite(router_file[4],power_slot[j]);
									$fwrite(router_file[4],",");
									$fwrite(router_file[4],"999");
									$fwrite(router_file[4],",");
									end
								5 : begin
									$fwrite(router_file[5],"0,");
									$fwrite(router_file[5],power_slot[j]);
									$fwrite(router_file[5],",");
									$fwrite(router_file[5],"999");
									$fwrite(router_file[5],",");
									end
								6 : begin
									$fwrite(router_file[6],"0,");
									$fwrite(router_file[6],power_slot[j]);
									$fwrite(router_file[6],",");
									$fwrite(router_file[6],"999");
									$fwrite(router_file[6],",");
									end
								7 : begin
									$fwrite(router_file[7],"0,");
									$fwrite(router_file[7],power_slot[j]);
									$fwrite(router_file[7],",");
									$fwrite(router_file[7],"999");
									$fwrite(router_file[7],",");
									end
								8 : begin
									$fwrite(router_file[8],"0,");
									$fwrite(router_file[8],power_slot[j]);
									$fwrite(router_file[8],",");
									$fwrite(router_file[8],"999");
									$fwrite(router_file[8],",");
									end
								9 : begin
									$fwrite(router_file[9],"0,");
									$fwrite(router_file[9],power_slot[j]);
									$fwrite(router_file[9],",");
									$fwrite(router_file[9],"999");
									$fwrite(router_file[9],",");
									end
								10: begin
									$fwrite(router_file[10],"0,");
									$fwrite(router_file[10],power_slot[j]);
									$fwrite(router_file[10],",");
									$fwrite(router_file[10],"999");
									$fwrite(router_file[10],",");
									end
								11: begin
									$fwrite(router_file[11],"0,");
									$fwrite(router_file[11],power_slot[j]);
									$fwrite(router_file[11],",");
									$fwrite(router_file[11],"999");
									$fwrite(router_file[11],",");
									end
								12: begin
									$fwrite(router_file[12],"0,");
									$fwrite(router_file[12],power_slot[j]);
									$fwrite(router_file[12],",");
									$fwrite(router_file[12],"999");
									$fwrite(router_file[12],",");
									end
								13: begin
									$fwrite(router_file[13],"0,");
									$fwrite(router_file[13],power_slot[j]);
									$fwrite(router_file[13],",");
									$fwrite(router_file[13],"999");
									$fwrite(router_file[13],",");
									end
								14: begin
									$fwrite(router_file[14],"0,");
									$fwrite(router_file[14],power_slot[j]);
									$fwrite(router_file[14],",");
									$fwrite(router_file[14],"999");
									$fwrite(router_file[14],",");
									end
								15: begin
									$fwrite(router_file[15],"0,");
									$fwrite(router_file[15],power_slot[j]);
									$fwrite(router_file[15],",");
									$fwrite(router_file[15],"999");
									$fwrite(router_file[15],",");
									end
							endcase
					    end
		
				end
			end
		end
			
	end

`endif
////////////////////////////////////////////////////



/*
	reg [15:0] power_ticks;
	localparam power_tick_resolution = 2000;
	localparam logging_limit = 500000;
	
	reg router_activity_detect[0: SWITCHES-1];
	reg router_activity_perm[0: SWITCHES-1];
	integer j;	



	//integer router_0;
	//integer router_1;
	//integer router_2;
	//integer router_3;
	//integer router_4;
	//integer router_5;
	//integer router_6;
	//integer router_7;
	//integer router_8;

	integer router_file[0:8];
	integer file;
	
	initial begin
	router_file[0] = $fopen("router_0.csv","w");
	router_file[1] = $fopen("router_1.csv","w");
	router_file[2] = $fopen("router_2.csv","w");
	router_file[3] = $fopen("router_3.csv","w");
	router_file[4] = $fopen("router_4.csv","w");
	router_file[5] = $fopen("router_5.csv","w");
	router_file[6] = $fopen("router_6.csv","w");
	router_file[7] = $fopen("router_7.csv","w");
	router_file[8] = $fopen("router_8.csv","w");
	end
	
	
	always @ (posedge Iter_flag[0][0])
		$fwrite(router_file[0],"2,");

	always @ (posedge Iter_flag[1][0])
		$fwrite(router_file[1],"2,");

	always @ (posedge Iter_flag[2][0])
		$fwrite(router_file[2],"2,");

	always @ (posedge Iter_flag[3][0])
		$fwrite(router_file[3],"2,");
	
	always @ (posedge Iter_flag[4][0])
		$fwrite(router_file[4],"2,");

	always @ (posedge Iter_flag[5][0])
		$fwrite(router_file[5],"2,");
	
	always @ (posedge Iter_flag[6][0])
		$fwrite(router_file[6],"2,");
	
	always @ (posedge Iter_flag[7][0])
		$fwrite(router_file[7],"2,");

	always @ (posedge Iter_flag[8][0])
		$fwrite(router_file[8],"2,");
	

	always @ (negedge CLK)
	begin
		if(ticks == logging_limit) begin
	
			$fclose(router_file[0]);
			$fclose(router_file[1]);
			$fclose(router_file[2]);
			$fclose(router_file[3]);
			$fclose(router_file[4]);
			$fclose(router_file[5]);
			$fclose(router_file[6]);
			$fclose(router_file[7]);
			$fclose(router_file[8]);
	
	
		end
		else begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				if ((power_ticks == power_tick_resolution - 1) & (~reset)) begin
					//if(Iter_flag[j]) begin
						file = router_file[j];
						if (router_activity_detect[j] ) begin
						//if (router_activity_perm[j]) begin
							case (j)
								0 : $fwrite(router_file[0],"1,");
								1 : $fwrite(router_file[1],"1,");
								2 : $fwrite(router_file[2],"1,");
								3 : $fwrite(router_file[3],"1,");
								4 : $fwrite(router_file[4],"1,");
								5 : $fwrite(router_file[5],"1,");
								6 : $fwrite(router_file[6],"1,");
								7 : $fwrite(router_file[7],"1,");
								8 : $fwrite(router_file[8],"1,");
							endcase
						end
						else begin
							case (j)
								0 : $fwrite(router_file[0],"0,");
								1 : $fwrite(router_file[1],"0,");
								2 : $fwrite(router_file[2],"0,");
								3 : $fwrite(router_file[3],"0,");
								4 : $fwrite(router_file[4],"0,");
								5 : $fwrite(router_file[5],"0,");
								6 : $fwrite(router_file[6],"0,");
								7 : $fwrite(router_file[7],"0,");
								8 : $fwrite(router_file[8],"0,");
							endcase
					    end
						
				end
			end
		end
			
	end

	always @ (posedge CLK)
	begin
	
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_detect[j] = 0;
			end
		end

		if (power_ticks == power_tick_resolution - 1) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_detect[j] = 0;
			end
		end
	
		else begin		
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_detect[j] = router_activity_detect[j]? 1 : active[j];
			end
		end

	end

	always @ (posedge CLK)
	begin
		if (reset) begin
			power_ticks <= 0;
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_perm[j] = 0;
			end
		end
		else if (power_ticks == power_tick_resolution - 1) begin
			power_ticks <= 0;
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_perm[j] = router_activity_detect[j];
			end		
		end
		//else if (power_ticks == power_tick_resolution ) begin
		//	power_ticks <= 0;
		//end

		else
			power_ticks <= power_ticks + 1;
	end	
	

	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_perm[j] = 0;
			end
		end
		else if (power_ticks == power_tick_resolution - 1) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				router_activity_perm[j] = router_activity_detect[j];
			end		
		end
	end	


	always @ (posedge CLK)
	begin
		if (reset) begin
			for (j = 0; j < SWITCHES; j= j + 1) begin
				signal_off_sim[j] = 0;
			end
		end
		else if (ticks == 500000) begin
				for (j = 0; j < SWITCHES; j= j + 1) begin
					//signal_off_sim[j] = (j == 7) ? 1 : 0;
					//signal_off_sim[j] = (j == 7) ? 1 : 0;
					signal_off_sim[j] = (j == 7) ? 0 : 0;
				end		
			end
		else begin
				for (j = 0; j < SWITCHES; j= j + 1) begin
					signal_off_sim[j] = signal_off_sim[j];
				end		
		end
	end	


*/

	always @ (posedge CLK) 
	begin
		ticks <= ticks + 1;
		if ((ticks >= 0)  && (ticks < 6 ))
			reset <= 1;
		else 
			reset <= 0;
	end

	////////**********************************************************************************////////////
	///////						Displaying Flits			(Mubashir)											///////////
	///////**********************************************************************************////////////
	integer handle1, handle2, handle3, handle4, handle5, handle6; 


	
	initial begin
	handle1 = $fopen("c_flits_out.csv","w");
	handle2 = $fopen("c_flits_in.csv","w");
	handle3 = $fopen("s_flits_in.csv","w");
	handle4 = $fopen("s_flits_out.csv","w");
	handle5 = $fopen("single_s_flits_out.csv","w");
	handle6 = $fopen("single_sflits_in.csv","w");
	
	end


	integer a,ports;	
	integer counter ;
	always @ (posedge CLK)
	begin
	 //if (reset)
	//	flit_counter <= 0;
	 //else begin	 
	 
	 
	 /////////////////////////////////////////////////////////////////////////////////Working portion
		for ( a = 0; a < SWITCHES ; a = a + 1) begin	
			if(c_valid_out [a]) begin 
				$fwrite (handle1, "%b \t %d \t %d \n" ,c_flits_out[a],a,ticks);
				//$fwrite (handle1, "%b \t %d \t%d \n" ,c_flits_out[a],a,ticks);
				//$display ("Data Out [%b] @ Node [%d] @Time [%d]", c_flits_out[a],a,ticks);
				//flit_counter <= flit_counter + 1;
			end
			if (c_valid_in [a]) begin
				//$fwrite (handle2, "%b \t %d \t%d \n" ,c_flits_in[a],a,ticks);
				$fwrite (handle2, "%b  \t %d \t %d \n", c_flits_in[a],a,ticks);
			end
			if(s_valid_in [a]) begin 
				$fwrite (handle3, "%b \t %d \t%d   \n" ,s_flits_in[a],a,ticks);
			end
			if(s_valid_out [a]) begin 
				$fwrite (handle4, " %b \t %d \t %d  \n" ,s_flits_out[a],a,ticks);
			end
			for (ports=0; ports <5; ports = ports +1)begin
				if(single_s_valid_out [a]) begin 
					$fwrite (handle5, "%b \t %d \t %d \t  %d  \n" ,single_s_flits_out[ports],a,ports,ticks); //Single flits for all ports
				end
				if(single_s_valid_in [a]) begin 
					$fwrite (handle6, " %b \t %d \t %d \t %d  \n" ,single_s_flits_in[ports],a,ports,ticks);
				end
			end
			
		end
	///////////////Single_s_flits declaration ""wire[(FLIT_WIDTH * SWITCH_TO_SWITCH) - 1: 0] single_s_flits_in [0: (SWITCHES*4)-1]""
	
		
   end
	//////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////// End of Modified Code(Mubashir) ////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////


	
	
endmodule
