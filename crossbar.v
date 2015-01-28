
/** @module : crossbar
 
 */
module crossbar #(parameter DATA_WIDTH = 32, IN_PORTS = 5, OUT_PORTS = 5, OUT_PORT_BITS = 3) (
    input clk,
    input reset,
	input ON,	

    input [(IN_PORTS * DATA_WIDTH) - 1:0]      in_data,
	input [(IN_PORTS * OUT_PORT_BITS) - 1:0]   req_ports, 
	input [IN_PORTS - 1:0]                     grants, 

	output  [(OUT_PORTS * DATA_WIDTH) - 1: 0]  out_data,
	// Indicates in data coming out of the crossbar is valid
	output  [OUT_PORTS - 1: 0]                 valid 	
		  
); 

/*
//reg  [(OUT_PORTS * DATA_WIDTH) - 1: 0]  out_data;
	// Indicates in data coming out of the crossbar is valid
//reg  [OUT_PORTS - 1: 0]                 valid;
	
wire    [(OUT_PORTS * DATA_WIDTH) - 1: 0] 	temp_out_data; 
wire	[DATA_WIDTH - 1: 0] 				t_temp_out_data [OUT_PORTS - 1:0];
  
wire		[OUT_PORTS - 1: 0]                temp_valid; 
wire 	[OUT_PORT_BITS - 1: 0]   p_req_ports [IN_PORTS - 1:0]; // to store temporary values 


integer i, t; 
genvar j;
generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : XB_PORTS
      		assign p_req_ports[j] = req_ports [(((j + 1) *OUT_PORT_BITS)-1) -: OUT_PORT_BITS]; 
  		end
		
	   for (j = 0; j < OUT_PORTS; j = j + 1) begin : XB_O_PORTS
      		assign temp_out_data [(((j + 1) *DATA_WIDTH)-1) -: DATA_WIDTH] = t_temp_out_data[j]; 
  	   end	
		
       for (j = 0; j < IN_PORTS; j = j + 1) begin : Outputs
			assign t_temp_out_data [p_req_ports[j]] = grants[j] ? (in_data[(((j + 1) *DATA_WIDTH)-1) -: DATA_WIDTH]) : 0;
		    assign temp_valid [p_req_ports[j]]      = grants[j];
	   end
endgenerate 
*/


wire    [(OUT_PORTS * DATA_WIDTH) - 1: 0] temp_out_data; 
reg		[DATA_WIDTH - 1: 0] t_temp_out_data [OUT_PORTS - 1:0];
  
reg		[OUT_PORTS - 1: 0]                temp_valid; 
wire 	[OUT_PORT_BITS - 1: 0]   p_req_ports [IN_PORTS - 1:0]; // to store temporary values 


integer i, t; 
genvar j;
generate
	   for (j = 0; j < IN_PORTS; j = j + 1) begin : XB_PORTS
      		assign p_req_ports[j] = req_ports [(((j + 1) *OUT_PORT_BITS)-1) -: OUT_PORT_BITS]; 
  		end
		
	   for (j = 0; j < OUT_PORTS; j = j + 1) begin : XB_O_PORTS
      		assign temp_out_data [(((j + 1) *DATA_WIDTH)-1) -: DATA_WIDTH] = t_temp_out_data[j]; 
  		end		
endgenerate 


//--------------Code Starts Here----------------------- 
always @ (posedge clk) begin
	if (reset) begin
		temp_valid    = 0; 
	end 
	else if (ON) begin
	//else begin           
		  temp_valid     = 0; 
   		for (i = 0; i < IN_PORTS; i = i + 1) begin
  			if (grants[i] && (p_req_ports[i] < OUT_PORTS)) begin
				  t_temp_out_data [p_req_ports[i]] = in_data[(((i + 1) *DATA_WIDTH)-1) -: DATA_WIDTH];
				  temp_valid [p_req_ports[i]]   = 1; 
  			end
  		end                               
	end

	else begin
		for (i = 0; i < IN_PORTS; i = i + 1) begin
				  t_temp_out_data [i] = 0;
				  temp_valid [i]   = 0; 

  		end   
	end
	
    //$display ("In_data:      %h ",  in_data);
    //$display ("Out_data:     %h ",  temp_out_data);
    //$display ("Valid Bits:   %b ",  temp_valid);
end

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
	assign valid       = temp_valid;
	assign out_data    = temp_out_data;

/*
always @ (posedge clk)
begin
	if (reset) begin
		valid       <= 0;
		out_data    <= 0;		
	end
	else begin
		valid       <= temp_valid;
		out_data    <= temp_out_data;
	end
end	
*/
	
endmodule





