
//FLIT_BITS = {EXTRA + TYPE + Y_ADDR + X_ADDR + APP_ID + DATA}
//----------------------------------------------------
// Parameterized Matrix arbiter.					 
//----------------------------------------------------


module arbiter_matrix #(parameter IN_PORTS = 5, OUT_PORT_BITS = 3) (
    input  clk,
    input  reset,
	input  ON,
 	input  [IN_PORTS - 1:0]                   requests, 
	input  [(IN_PORTS * OUT_PORT_BITS) - 1:0] req_ports, 
	output [IN_PORTS - 1:0]                   grants
);



parameter OUT_PORTS = IN_PORTS;

wire   [OUT_PORT_BITS - 1: 0]   port_priority [IN_PORTS - 1:0]; // to store temporary values 
wire   [IN_PORTS - 1: 0]        temp_grants_new;
wire   [OUT_PORT_BITS - 1: 0]   p_req_ports [IN_PORTS - 1:0]; // to store temporary values 

///////////////////////////////////////////////////////////////
// Matrix for Prior
///////////////////////////////////////////////////////////////
reg  	pri			[0 : (OUT_PORTS - 1)][0 : (IN_PORTS - 1)][0 : (IN_PORTS - 1)]; // A Matrix for each output port
wire 	pri_temp	[0 : (OUT_PORTS - 1)][0 : (IN_PORTS - 1)][0 : (IN_PORTS - 1)];
///////////////////////////////////////////////////////////////
wire 	update_matrix [0: (IN_PORTS - 1)] ; // for each input for see if there was a request and that
									   // request was actually fulfilled

//wire    matrix_and    [0 : (OUT_PORTS - 1)][0 : (IN_PORTS - 1)][0 : (IN_PORTS - 1)];
wire    [0 : (IN_PORTS - 1)] matrix_and  	   [0 : (OUT_PORTS - 1)][0 : (IN_PORTS - 1)];
wire    [0 : (IN_PORTS - 1)] matrix_and_trans  [0 : (OUT_PORTS - 1)][0 : (IN_PORTS - 1)];
wire 	disable_req   [0 : (OUT_PORTS - 1)][0: (IN_PORTS - 1)] ; // 



integer i,k,out,l; 
genvar j;
genvar a,b,c;

generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : ARB_PORTS
      		assign p_req_ports[j] = req_ports [(((j + 1) *OUT_PORT_BITS)-1) -: OUT_PORT_BITS]; 
  	   end
endgenerate 


//#############################################################
// Update matrix in case of a granted request
//#############################################################
generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : Mat_Update
      		assign update_matrix[j] =  (requests[j] & temp_grants_new[j]);
  	   end
endgenerate 
//#############################################################



//#############################################################
// Creating anded matrix .. refer to NoC books for VLSI structure
//#############################################################
generate
		for (a = 0; a < OUT_PORTS; a = a + 1)  begin// for each input port 
			for (b = 0; b < IN_PORTS; b = b + 1)  begin // i = Col
				for (c = 0; c < IN_PORTS; c = c + 1) begin // k = Row
					assign matrix_and[a][b][c] = (b == c)? 0 :(requests[b] && (p_req_ports[b] == a)) ? pri[a][b][c] : 0; //TODO req[c] -> req[b]
				end
			end		
		end
endgenerate
//##############################################################


//##############################################################
// Creating transpose of anded matrix 
//#############################################################
generate
		for (a = 0; a < OUT_PORTS; a = a + 1)  begin// for each input port 
			for (b = 0; b < IN_PORTS; b = b + 1)  begin // i = Col
				for (c = 0; c < IN_PORTS; c = c + 1) begin // k = Row
					assign matrix_and_trans[a][b][c] = matrix_and[a][c][b];
				end	
			end		
		end
endgenerate
//##############################################################


//##############################################################
// Disable requests in case of higher pri requests 
//#############################################################
generate
		for (a = 0; a < OUT_PORTS; a = a + 1)  begin// for each input port 
			for (b = 0; b < IN_PORTS; b = b + 1)  begin // i = Col
				assign disable_req[a][b] = |(matrix_and_trans[a][b]);
			end		
		end
endgenerate
//##############################################################



//#############################################################
// grants if there is a request and it is not blocked
//#############################################################
generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : Grants
      		assign temp_grants_new[j] =  (requests[j] & ~disable_req[p_req_ports [j]][j]);
  	   end
endgenerate 
//#############################################################





//#####################################################
// Managing Matrix
//#####################################################
always @ (posedge clk)
begin
    if (reset)begin
		for (out = 0; out < OUT_PORTS; out = out + 1)
			for (i = 0; i < IN_PORTS; i = i + 1)
				for (k = 0; k < IN_PORTS; k = k + 1) begin
					if ( i > k)
						pri[out][i][k] = 1;
					else
						pri[out][i][k] = 0;
				end
	end
		
	else if (ON) begin
	//else begin
		for (l = 0; l < IN_PORTS; l = l + 1) // for each input port 
			for (i = 0; i < IN_PORTS; i = i + 1) // i = Col
				for (k = 0; k < IN_PORTS; k = k + 1) begin // k = Row
					if (update_matrix[l]) begin
						pri[p_req_ports[l]][l][k] = 0;
						pri[p_req_ports[l]][i][l] = 1;
						end
					//else
					//	pri[i][k] = pri[i][k]; 
				end
	end
end
//######################################################




//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
	assign grants   = temp_grants_new;
	 
endmodule



