// TODO flit_type 
//FLIT_BITS = {EXTRA + SOURCE_BITS + TYPE + Y_ADDR + X_ADDR + APP_ID + DATA}
`include "crossbar.v"
`include "fifo.v"
`include "arbiter_2.v"

module router_2 #(parameter 	RT_ALG = 0, 	ID_BITS = 4,	
								FLIT_WIDTH = 32,	
								EXTRA_BITS = 2,
								SOURCE_BITS = 4,
								BUFFER_DEPTH_BITS = 1,  //CHANGED FROM 1 TO 4**MUBASHIR
								TYPE_BITS = 2,	ROW = 4, COLOUMN = 4, 
								APP_ID_BITS = 3, N_ROUTER = 4) 
(
  
	ON, clk, 
	reset,  
	router_ID,
	
	c_flits_in, c_valid_in, // /* Power */ c_waiting_in, 
	s_flits_in, s_valid_in, // /* Power */ s_waiting_in,
	
	c_empty_in, c_full_in,  /* power */ c_off_in,
	s_empty_in, s_full_in,  /* Power */ s_off_in,
	
	s_flits_out, s_valid_out, /* Power */ s_waiting_out, 
	c_flits_out, c_valid_out, /* Power */ c_waiting_out, 
	
	c_empty_out, c_full_out, // /* Power */ c_off_out,
	s_empty_out, s_full_out, // /* Power */ s_off_out,
	active /* Power */
 
);
	//define the log2 function
	function integer log2;
		input integer num;
		integer i, result;
		begin
			for (i = 0; 2 ** i < num; i = i + 1)
			  result = i + 1;
			log2 = result;
		end
	endfunction

	// Number of Neighbour routers /*TODO Check it again*/
	//localparam N_ROUTER = 4;
	
	// Number of Core I/O Ports
	localparam CORE_IN_PORTS   = 1; 
	localparam CORE_OUT_PORTS  = 1;  
	
	//Number of unique in ports. 
	localparam IN_PORTS =  (N_ROUTER + CORE_IN_PORTS);

	//Number of bits to represent input port number. 
  	localparam IN_PORT_BITS = log2(IN_PORTS); 
  
  	//Number of unique out ports. 
  	localparam OUT_PORTS =  (N_ROUTER + CORE_OUT_PORTS);
  
  	//Number of bits to represent output port number. 
  	localparam OUT_PORT_BITS = log2(OUT_PORTS);
	
	//Number of bits to represent coordinates. 
	localparam ROW_BITS 	= log2(ROW); 
  	localparam COLUMN_BITS 	= log2(COLOUMN);

    // Create Row Coloumn Address 
	function [ID_BITS:0] grid_id;
		input integer id; 
		integer i, j, count; 
		reg [ROW_BITS - 1:0] row; reg [COLUMN_BITS - 1:0] col; 
		begin
		    count = 0; row = 0; col = 0; 
			for(i= 0; i < ROW; i = i+1) begin
				for(j= 0; j < COLOUMN; j = j+1) begin
					if (count == id) begin
						row = i; 
						col = j; 
					end
					count = count +1; 
				end
			end  
			grid_id = {row, col}; 
		end
	endfunction	

	//---------------------------------------------------------------------------------------------//
	// I/O	
	input ON; 
 	input clk;    
  	input reset;
  	
	// Router ID 
  	input [(ID_BITS - 1): 0]    router_ID;
	
	// Incomming Flits
	input [(FLIT_WIDTH - 1): 0] c_flits_in;
  	input [0:0]c_valid_in; 
 	input [(FLIT_WIDTH * N_ROUTER) - 1: 0] s_flits_in;
  	input [N_ROUTER - 1 :0]s_valid_in;
	
	// Incomming Credits
  	input [0:0]c_empty_in; 
  	input [0:0]c_full_in;
  	input [N_ROUTER - 1 :0] s_empty_in; 
  	input [N_ROUTER - 1 :0] s_full_in;
	
	/* Power */
	input [0:0]				c_off_in;
	input [N_ROUTER - 1:0] 	s_off_in;

	// Outgoing Flits  
  	output [(FLIT_WIDTH * N_ROUTER) - 1: 0] s_flits_out; 
  	output [N_ROUTER - 1 :0] s_valid_out; 
  	output [(FLIT_WIDTH - 1): 0] c_flits_out; /*TODO*/ // Do we need to send Routing bits to core? 
  	output [0:0]c_valid_out; 

	/* Power */
	input [0:0]				c_waiting_out;
	input [N_ROUTER - 1:0] 	s_waiting_out;

    // Outgoing Credits
  	output [0:0]c_empty_out; 
  	output [0:0]c_full_out;
  	output [N_ROUTER - 1 :0] s_empty_out; 
  	output [N_ROUTER - 1 :0] s_full_out; 
 	
	output active;
	
	
	//---------------------------------------------------------------------------------------------//
	//wire [(ID_BITS - 1): 0]    router_ID;
	
	//---------------------------------------------------------------------------------------------//
	// Internal Wires 	

  	wire [FLIT_WIDTH - 1: 0] temp_s_flits_out [0: (N_ROUTER - 1)]; 
  	wire temp_s_valid_out [0: (N_ROUTER - 1)]; 
  	wire [FLIT_WIDTH - 1: 0] temp_c_flits_out; 
  	wire temp_c_valid_out[0:0];

	wire [FLIT_WIDTH - 1:0] in_flit [0:IN_PORTS-1]; 
  	wire WEn [0:IN_PORTS-1];
   
  	reg  REn [0:IN_PORTS-1];/*TODO Changing to reg type*/
  	wire [IN_PORTS-1: 0] PeekEn = 0; // Set to Zero
 
  	wire [FLIT_WIDTH - 1:0] out_flit [0:IN_PORTS-1];
  	wire valid [0:IN_PORTS-1];
    
    /*TODO  These buffers are for storing the flit in case of stalls in stage 2*/
	reg [FLIT_WIDTH - 1:0] out_flit_buff [0:IN_PORTS-1];
  	reg valid_buff [0:IN_PORTS-1];
  
  	wire empty [0:IN_PORTS-1];
  	wire full [0:IN_PORTS-1];
    
  	wire empty_in [0: (IN_PORTS - 1)];  
  	wire full_in [0: (IN_PORTS - 1)];  
 	
	/* Power */
	wire off_in    	 [0:IN_PORTS-1];
	//wire waiting_out [0:IN_PORTS-1];
	reg  waiting_out [0:IN_PORTS-1];

  	wire  [(IN_PORTS * OUT_PORT_BITS) - 1: 0] req_ports;  
  	wire  [IN_PORTS - 1: 0] requests;  	
  	wire  [IN_PORTS - 1: 0] grants;
	wire  [IN_PORTS - 1: 0] xb_grants; 
  
  	wire   [(IN_PORTS * FLIT_WIDTH) - 1: 0]    xb_in_data;       	
  	wire   [(IN_PORTS * OUT_PORT_BITS) - 1: 0] xb_req_ports;
  	wire  [(OUT_PORTS * FLIT_WIDTH) - 1: 0]   xb_out_data;
  	wire  [OUT_PORTS - 1: 0]  xb_valid;  
  
  	wire  [FLIT_WIDTH - 1: 0] in_data [0: (IN_PORTS - 1)];
  	wire  in_valid [0: (IN_PORTS - 1)]; 

  	wire  [FLIT_WIDTH - 1: 0] out_data [0: (OUT_PORTS - 1)];
  	wire	out_valid [0: (OUT_PORTS - 1)];

  	wire bubble [0:IN_PORTS-1];
  	wire stall  [0:IN_PORTS-1];
  	wire sw_stall [0:IN_PORTS-1];
	reg  sw_stall_buff [0:IN_PORTS-1];
	reg  stall_buff [0:IN_PORTS-1];
  	wire drained  [0:IN_PORTS-1];
 
  	wire full_stall [0:IN_PORTS-1];
  	reg  [OUT_PORT_BITS - 1:0] last_port [0:IN_PORTS-1];
  	
	/* Power */
	wire off_stall [0:IN_PORTS-1];
  
  	wire [ID_BITS - 1: 0] router_coord = grid_id(router_ID); 
  	wire [(COLUMN_BITS - 1): 0] cur_x = router_coord[(COLUMN_BITS - 1): 0]; 
  	wire [(ROW_BITS - 1): 0]    cur_y = router_coord[((ROW_BITS + COLUMN_BITS) - 1)-: ROW_BITS];   
  	wire [(COLUMN_BITS - 1): 0] dest_x[0:IN_PORTS-1]; 
  	wire [(ROW_BITS - 1): 0]    dest_y[0:IN_PORTS-1];
  	wire [((ROW_BITS + COLUMN_BITS) - 1): 0]  destination [0:IN_PORTS-1];   
  
  
  	wire [OUT_PORT_BITS - 1:0]  port_info [0:OUT_PORTS-1];
  	//wire cal_route [0:OUT_PORTS-1];

  	wire allocate   [0:OUT_PORTS-1];
  	wire no_allocate [0:OUT_PORTS-1];
  	wire deallocate [0:OUT_PORTS-1];
  	

	/// For Xbar
	reg  [(IN_PORTS * OUT_PORT_BITS) - 1: 0] req_ports_xbar;
	reg  [IN_PORTS - 1: 0]  grants_xbar;
	reg  [FLIT_WIDTH - 1:0] flit_xbar [0:IN_PORTS-1];
	
	////////////////////////////////////////////////////
 
  	wire                       flit_valid   [0:IN_PORTS-1]; 
  	wire [FLIT_WIDTH - 1:0]    flit         [0:IN_PORTS-1];
  	//wire [FLOW_BITS - 1:0]     flit_id      [0:IN_PORTS-1]; 
  	//wire [TYPE_BITS - 1:0]     flit_type    [0:IN_PORTS-1];
  	wire [OUT_PORT_BITS - 1:0] route        [0:OUT_PORTS-1]; 

	//---------------------------------------------------------------------------------------------// 
	// Types of each flit (Specially for WH_RT)  
	localparam HEAD = 'b10; 
  	localparam BODY = 'b00;
  	localparam TAIL = 'b01;
  	localparam ALL  = 'b11;
	
	
	
	// If flit a header ? (WH_RT)	
	/*
	function [0:0] header;
		input[TYPE_BITS - 1:0]   flit_type; 
		begin
			header = ((flit_type == HEAD) | (flit_type == ALL)); 
		end
	endfunction 
	*/
	
	localparam FLOW_BITS 	= EXTRA_BITS + SOURCE_BITS + TYPE_BITS + COLUMN_BITS + ROW_BITS;
	localparam DATA_WIDTH   = FLIT_WIDTH - FLOW_BITS;

	localparam DOR_XY = 0,  DOR_YX = 1, TABLE = 2; 	// RT_AL  -> Routing Algorithm
	localparam FLIT_RT = 0, WH_RT = 1; 				// FLIT_T -> Routing decision for each flit
    												// WH_RT  -> Standard Wormhole Routing
  	
/* Power */
assign active = (flit_valid[0]|flit_valid[1]|flit_valid[2]|flit_valid[3]|flit_valid[4]) | (|c_valid_in) | (|s_valid_in) | (|c_valid_out) | (|s_valid_out);

integer  j, index; 
  genvar i;

generate
		// Instantiate Input buffers for each input port
 	for (i=0; i < IN_PORTS; i=i+1) begin : INPUT_PORTS
			fifo #(FLIT_WIDTH, BUFFER_DEPTH_BITS, 2) IP (
			  clk, reset, ON,
			  in_flit[i],WEn[i], 
			  REn[i], PeekEn[i],
			  out_flit[i],valid[i], 
			  full[i], empty[i]
			);
	end
	    // Drive Output Credits for this Core's Input Buffer
	for (i = 0; i < CORE_IN_PORTS; i=i+1) begin : CE_OUT
      	assign c_empty_out[i] = empty[i]; 
      	assign c_full_out [i] = full[i];
		assign c_waiting_out[i] = waiting_out[i]; /* Power */
  	end 
		// Drive Output Credits for this Router's Input Buffers
	for (i = 0; i < (N_ROUTER); i=i+1) begin : SE_OUT
      	assign s_empty_out[i] = empty[(i + CORE_IN_PORTS)]; 
      	assign s_full_out [i] = full[(i + CORE_IN_PORTS)];
		assign s_waiting_out[i] = waiting_out[(i + CORE_IN_PORTS)]; /* Power */
  	end
		// Get Credits from Neighbour Router Input Buffers
	for (i = 0; i < CORE_IN_PORTS; i=i+1) begin : CE_IN
      	assign empty_in[i] = c_empty_in[i]; 
      	assign full_in [i] = c_full_in[i];
		assign off_in  [i] = c_off_in; /* Power */
  	end 
		// Get Credits from Core output Buffer
	for (i = 0; i < (N_ROUTER); i=i+1) begin : SE_IN
      	assign empty_in[(i + CORE_IN_PORTS)] = s_empty_in[i]; 
      	assign full_in [(i + CORE_IN_PORTS)] = s_full_in[i];
		assign off_in  [(i + CORE_IN_PORTS)] = s_off_in[i]; /* Power */
  	end
		// Drive output flits for Core  
	for (i = 0; i < CORE_OUT_PORTS; i=i+1) begin : CF_OUT
	  	assign c_flits_out = temp_c_flits_out; // TODO 
	  	assign c_valid_out[i] = temp_c_valid_out[i];
	end   
		// Drive output flits for Neighbour Routers  
	for (i = 0; i < N_ROUTER; i=i+1) begin : SF_OUT
	   	assign s_flits_out[(((i + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH] = temp_s_flits_out[i];
	   	assign s_valid_out[i] = temp_s_valid_out[i]; 
	end	
    	
	// With no output buffer 
	// /*TODO*/ -> Perhaps we can register the output of the xbar
	for (i = 0; i < OUT_PORTS; i =i + 1) begin : CN1
		assign out_data[i]   = xb_out_data[(((i + 1)* FLIT_WIDTH)-1) -: FLIT_WIDTH];
		assign out_valid[i]  = xb_valid[i];
	end

	for (i = 0; i < CORE_OUT_PORTS; i=i+1) begin : CN2
		assign temp_c_flits_out[FLIT_WIDTH - 1 : 0] = out_data[i]; 
		assign temp_c_valid_out[i] = out_valid[i];
	end 

	for (i = CORE_OUT_PORTS; i < OUT_PORTS; i=i+1) begin : CN3
		assign temp_s_flits_out[i - CORE_OUT_PORTS] = out_data[i];
		assign temp_s_valid_out[i - CORE_OUT_PORTS] = out_valid[i]; 
	end

	// Creating Busses from Compound Incomming Data
	for (i= 0; i< CORE_IN_PORTS; i=i+1) begin : CN4
		assign in_data[i]  = c_flits_in[(((i+ 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH];
		assign in_valid[i] = c_valid_in[i]; 
	end

	for (i= CORE_IN_PORTS; i< IN_PORTS; i=i+1) begin : CN5 
		assign in_data[i]  = s_flits_in[((((i- CORE_IN_PORTS) + 1) *(FLIT_WIDTH))-1) -: FLIT_WIDTH];
		assign in_valid[i] = s_valid_in[i- CORE_IN_PORTS];
	end 

	// 1) buffer write (BW) and for head flits route computation (RC)	 
	for(i= 0; i < IN_PORTS; i = i+1) begin : CN6
		assign in_flit[i]     = in_data[i];
		assign WEn[i]         = in_valid[i]; 
		
		assign bubble[i]      = (empty[i] & (~WEn[i]))? 1 : 0; // Input buffer is empty AND there is no incomming flit  
		assign stall[i]       = (full_stall[i] | sw_stall[i] | off_stall[i]);  /* Power */
		// TODO-Output buffer full OR Failure to win output buffer
		//assign REn[i]         = (reset | stall[i] | bubble[i])? 0 : 1; // TODO Removing from here /Keep reading until Stall or Bubble 

		// Data for all the sub-stages		
		// out_flit[] is the output from buffer
		assign flit[i]        = (stall_buff[i])?out_flit_buff[i]:out_flit[i]; 
		assign flit_valid[i]  = (stall_buff[i])?valid_buff[i]:valid[i]; //TODO
		//assign flit_valid[i]  = ((sw_stall_buff[i] & valid_buff[i]) | (~sw_stall_buff[i] & valid[i]));
		//assign flit_id [i]    = flit[i][(FLIT_WIDTH -1) -: FLOW_BITS];
		//assign flit_type[i]   = flit[i][(FLIT_WIDTH - EXTRA_BITS -1) -: TYPE_BITS];
		
		assign destination[i] = reset? 0: 
			   flit[i][(FLIT_WIDTH - EXTRA_BITS - SOURCE_BITS - TYPE_BITS -1) -: (ROW_BITS + COLUMN_BITS)];		
		
		
		//#######################################******************#################################################*/

		//###################################################################################
		assign dest_x[i]      = destination[i][(COLUMN_BITS - 1): 0]; 
		assign dest_y[i]      = destination[i][((ROW_BITS + COLUMN_BITS) - 1) -: ROW_BITS];
		//###################################################################################
		
		// Generating Rout Using XY <-> YX DOR 
		assign route[i] =(RT_ALG == DOR_XY)? (cur_x == dest_x[i])? (cur_y > dest_y[i])? 
						 4 : (cur_y < dest_y[i])? 2 : 0 : (cur_x > dest_x[i]) ? 1 : 3
						 :(RT_ALG == DOR_YX)? (cur_y == dest_y[i])? (cur_x > dest_x[i])? 
						 1 : (cur_x < dest_x[i])? 3 : 0 : (cur_y > dest_y[i]) ? 4 : 2
						 : 0; 
						
		//Other assignments 
		//assign cal_route[i] = (flit_valid[i] & header(flit_type[i]) & (RT_ALG != TABLE)); 					  
		//assign port_info[i] = cal_route[i]? route[i] : Routing_table[flit_id[i]];  
		/*TODO*/ // For now, we do not have lookup table based routing
		assign port_info[i] = route[i];
		assign sw_stall[i]  = (requests[i] & ~grants[i])? 1: 0;
		assign full_stall[i]= (reset)? 0 : (requests[i] & full_in[port_info[i]])? 1: 0; // TODO Error: We to have see if the reqeusted port is full
		assign off_stall[i] = (reset)? 0 : (requests[i] & off_in[port_info[i]])? 1: 0;  /* Power */
		//assign drained[i]   = (((SG2_flit_vc[i] == u) & SG2_valid[i] & header(SG2_flit_type[i])) |
		//							 (SG2S_valid[i][u] &  header(SG2S_flit_type[i][u]))|
		//							 ((SG3_flit_vc[i] == u) & SG3_valid[i] & header(SG3_flit_type[i])) |
		//							 (SG3S_valid[i][u] & header(SG3S_flit_type[i][u])));  
	end 
	
	// 2) Arbitration for output ports	 	
	for (i = 0; i < IN_PORTS; i=i+1) begin: ARB_INPUTS
		//assign requests[i] = ((flit_valid[i]) & (~full_stall[i]))? 1: 0; //TODO Changed
		assign requests[i] = (flit_valid[i])? 1: 0;
		//assign requests[i] = flit_valid[i];								  
		assign req_ports[(((i + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS] = port_info[i];
	end
	// 3) ST - Switch Transversal	
	for (i = 0; i < IN_PORTS; i=i+1) begin: XBAR
		//assign xb_grants[i] = stall[i]? 0 : grants[i];
		assign xb_grants[i] = grants_xbar[i];
		assign xb_in_data [(((i + 1)* FLIT_WIDTH)-1) -: FLIT_WIDTH]         = flit_xbar[i]; 
		assign xb_req_ports[(((i + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS] = req_ports_xbar[(((i + 1) * OUT_PORT_BITS)- 1)-: OUT_PORT_BITS];	/*TODO*/
	end 		
endgenerate      

  crossbar #(FLIT_WIDTH, IN_PORTS, OUT_PORTS, OUT_PORT_BITS) XBar (  
	clk, reset,ON, xb_in_data , xb_req_ports, xb_grants, xb_out_data, xb_valid  
  );
 
  arbiter_matrix #(IN_PORTS,OUT_PORT_BITS) ARB (
     clk, reset,ON, requests, req_ports, grants   
  );    



always @(posedge clk) /* Power */
begin
	if (reset) begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			waiting_out [index] = 0;
  		end 
	end 
	else if (ON) begin
	//else begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			waiting_out [index] = 0;
  		end 

		for (index = 0; index < IN_PORTS; index = index + 1) begin
			if (off_stall[index]) begin
				waiting_out[port_info[index]]  = 1;
			end
  		end 
	end
end


always @(posedge clk) // TODO
begin
	if (reset) begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			grants_xbar    [index]  <= 0;
  			flit_xbar      [index]  <= 0;
  		end 
		req_ports_xbar <= 0;
	end 
	else if (ON) begin
	//else begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			grants_xbar    [index]  <= stall[index]? 0:grants[index];
  			flit_xbar      [index]  <= flit[index];
  		end 
		req_ports_xbar <= req_ports;
	end
end


always @(posedge clk) // TODO
begin
	if (reset) begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			out_flit_buff  [index]  <= 0;
  			valid_buff     [index]  <= 0;
  		end 
	end 
	else if (ON) begin
	//else begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			out_flit_buff  [index]  <= flit[index];
  			valid_buff     [index]  <= flit_valid[index];
  		end 
	end
end

always @(posedge clk)
begin
	if (reset) begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			sw_stall_buff[index] <= 0;
			stall_buff[index] <= 0;
  		end 
	end 
	else if (ON) begin
	//else begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			sw_stall_buff[index] <= sw_stall[index];
			stall_buff[index] 	 <= stall[index];
  		end 
	end
end

always @(posedge clk)
begin
	if (reset) begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			REn[index] <= 1;
  		end 
	end 
	else if (ON) begin
	//else begin
		for (index = 0; index < IN_PORTS; index = index + 1) begin
  			REn[index] <= (stall[index] | bubble[index])? 0 : 1;
  		end 
	end
end

always @ (posedge clk)
begin

end

endmodule
