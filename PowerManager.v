
//`define NATIVE_PM
`define NO_PM
module power_manager    #(parameter 	DATA_WIDTH = 32, 
										SLOTS = 20,
										POWER_TICK_RESOLUTION = 2000,
										WAKE_UP_LATENCY = 200,
										ACTIVITY_DETECT = 50) 
(
    input clk,
    input reset,
	input [1:0] Iter_flag,
    input [DATA_WIDTH-1:0] prog_data,
	input prog_en,
    input request_to_on,
	input active,
    
    output clk_gate,
    output pwr_gate,
    output signal_off
); 

reg [2:0] power_states [0 : SLOTS - 1];
reg [7:0] pointer;
reg [11:0] tick_counter;

integer j;

localparam ON_STATE = 3'b000; // 0
localparam PWR_GATE_STATE = 3'b011; // 3
localparam CLK_GATE_STATE = 3'b010; //2
localparam WAKE_UP_STATE = 3'b001;//1
localparam CLK_GATE_BUT_ON_STATE = 3'b111; //7
localparam PWR_GATE_BUT_ON_STATE = 3'b101;
reg [2:0] c_state;
reg [2:0] n_state;


localparam CLK_GATE_WAIT = 2;
localparam PWR_GATE_WAIT = 5000;
localparam PWR_GATE_WAIT_MED  = 150;
localparam PWR_GATE_WAIT_LONG = 10000;

reg [CLK_GATE_WAIT - 1 : 0] short_idle_detect;
reg [PWR_GATE_WAIT_LONG - 1 : 0] long_idle_detect;
wire we_can_clk_gate;
wire we_can_pwr_gate;
wire we_can_pwr_gate_med;
wire we_can_pwr_gate_long;
always @ (posedge clk)
begin
	if (reset) begin
		short_idle_detect <= 1;
	end
	else begin
		short_idle_detect <= 	((active | request_to_on) == 0) ? {short_idle_detect[CLK_GATE_WAIT - 2 : 0] , 1'b0} :
								{short_idle_detect[CLK_GATE_WAIT - 2 : 0] , 1'b1}; 
	end
end

always @ (posedge clk)
begin
	if (reset) begin
		long_idle_detect <= 1;
	end
	else begin
		
		`ifdef NATIVE_PM

		long_idle_detect <= 	(((c_state == WAKE_UP_STATE)| active | request_to_on) == 0) ? {long_idle_detect[PWR_GATE_WAIT_LONG - 2 : 0] , 1'b0} :
								{long_idle_detect[PWR_GATE_WAIT_LONG - 2 : 0] , 1'b1}; 

		`else
		long_idle_detect <= 	((active | request_to_on) == 0) ? {long_idle_detect[PWR_GATE_WAIT_LONG - 2 : 0] , 1'b0} :
								{long_idle_detect[PWR_GATE_WAIT_LONG - 2 : 0] , 1'b1}; 
			
		`endif
	end
end

assign we_can_clk_gate       = ~(| short_idle_detect);
assign we_can_pwr_gate       = ~(| long_idle_detect[PWR_GATE_WAIT - 1 :0]);
assign we_can_pwr_gate_med   = ~(| long_idle_detect[PWR_GATE_WAIT_MED - 1 :0]);
assign we_can_pwr_gate_long  = ~(| long_idle_detect);



always @ (posedge clk)
begin
	if (reset) begin
		pointer <= 0;
	end
	else begin
		pointer <= 	(Iter_flag == 0) ? 0:
					(pointer >= (SLOTS)) ? 0:// TODO // 
					((tick_counter >= POWER_TICK_RESOLUTION - 1) && (pointer < SLOTS - 1))?
					//(tick_counter >= POWER_TICK_RESOLUTION - 1)?
					(pointer + 1) : pointer;				 
	end
end

/*
reg router_activity_detect;
reg [6:0] active_ticks;

always @ (posedge CLK)
begin
	if (reset) begin
		active_ticks <= 0;
	end
	else begin
		active_ticks <= (Iter_flag == 0) ? 0:
						(active_ticks == ACTIVITY_DETECT - 1)? 0:
						active_ticks + 1;				 
	end
end


always @ (posedge CLK)
begin	
	if (reset) begin
		router_activity_detect <= 0;
	end

	else begin
		router_activity_detect <= 	(Iter_flag == 0) ? 0:
						 			(active_ticks == ACTIVITY_DETECT - 1)? 0: 
									router_activity_detect ? 1 : active;
								 
	end

end
*/

reg [7:0] wake_up_counter;

always @(posedge clk)
begin
	if (reset)
		wake_up_counter <= 0;
	else
		case (c_state)

			WAKE_UP_STATE: begin
				if (wake_up_counter <= (WAKE_UP_LATENCY - 1))
						wake_up_counter <= wake_up_counter + 1;
			end
			PWR_GATE_BUT_ON_STATE: begin
				if (wake_up_counter <= (WAKE_UP_LATENCY - 1))
						wake_up_counter <= wake_up_counter + 1;
			end
			default:
				wake_up_counter <= 0;

		endcase
end


always @(posedge clk)
begin
	if (reset) begin
		for (j = 0; j < SLOTS; j = j + 1) begin
				power_states[j] <= ON_STATE;
		end
	end
	else if (prog_en) begin
		power_states[prog_data[15:0]] <= prog_data[31:16];
	end
	
end


always @(posedge clk)
begin
	if (reset | (Iter_flag == 0)) begin
		tick_counter <= 0;
	end
	else if (tick_counter == POWER_TICK_RESOLUTION - 1) begin
		tick_counter <= 0;
	end
	else begin
		tick_counter <= tick_counter + 1;
	end
end

`ifdef NATIVE_PM
always @(posedge clk)
begin
	if(reset) begin
		c_state <= ON_STATE;
	end	
	else begin
		c_state <= n_state;
	end
end

/*
always @ (*)
begin
	case (c_state)

		ON_STATE : begin
			if ((Iter_flag == 0) || request_to_on || active || (~we_can_pwr_gate) || ( ~we_can_clk_gate)) // TODO
				n_state = ON_STATE;
			else if ((power_states[pointer] == PWR_GATE_STATE) && (~we_can_pwr_gate)) // TODO
				n_state = ON_STATE;
			else
				n_state = power_states[pointer];
		end
		
		PWR_GATE_STATE : begin
			if ((request_to_on) | (Iter_flag == 0)|(power_states[pointer] != PWR_GATE_STATE))  
				//n_state = PWR_GATE_BUT_ON_STATE;
				n_state = WAKE_UP_STATE;
			else
				n_state = power_states[pointer];
		end

		CLK_GATE_STATE : begin
			if (Iter_flag == 0)
				n_state = ON_STATE;
			else
				n_state = power_states[pointer];
		end

		WAKE_UP_STATE : begin
			n_state = ((wake_up_counter >= WAKE_UP_LATENCY - 1) ) ? ON_STATE
							: WAKE_UP_STATE;
		end
	
		
		default:
			n_state = ON_STATE;

	endcase
end
*/
always @ (*)
begin
	case (c_state)

		ON_STATE : begin
			if (we_can_clk_gate)
				n_state = CLK_GATE_STATE;
			/*
			else if (we_can_pwr_gate && (power_states[pointer] == PWR_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_med && (power_states[pointer] == CLK_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_long && (power_states[pointer] == ON_STATE))
				n_state = PWR_GATE_STATE;
			*/
			else if (we_can_pwr_gate_long && ((power_states[pointer] == ON_STATE) || (power_states[pointer] == CLK_GATE_STATE) || (power_states[pointer] == PWR_GATE_STATE)) )
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_med && ((power_states[pointer] == CLK_GATE_STATE) || (power_states[pointer] == PWR_GATE_STATE)) )
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate && (power_states[pointer] == PWR_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else
				n_state = ON_STATE;
		end
		
		PWR_GATE_STATE : begin
			if (request_to_on) 
				n_state = WAKE_UP_STATE;
			//else if (power_states[pointer] == ON_STATE)
			//	n_state = WAKE_UP_STATE;
			else
				n_state = PWR_GATE_STATE;
		end

		CLK_GATE_STATE : begin
			if (request_to_on)
				n_state = ON_STATE;
			
			/*
			else if (we_can_pwr_gate && (power_states[pointer] == PWR_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_med && (power_states[pointer] == CLK_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_long && (power_states[pointer] == ON_STATE))
				n_state = PWR_GATE_STATE;
			*/
			else if (we_can_pwr_gate_long && ((power_states[pointer] == ON_STATE) || (power_states[pointer] == CLK_GATE_STATE) || (power_states[pointer] == PWR_GATE_STATE)) )
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate_med && ((power_states[pointer] == CLK_GATE_STATE) || (power_states[pointer] == PWR_GATE_STATE)) )
				n_state = PWR_GATE_STATE;
			else if (we_can_pwr_gate && (power_states[pointer] == PWR_GATE_STATE))
				n_state = PWR_GATE_STATE;
			else
				n_state = CLK_GATE_STATE;
		end

		WAKE_UP_STATE : begin
			n_state = ((wake_up_counter >= WAKE_UP_LATENCY - 1) ) ? ON_STATE
							: WAKE_UP_STATE;
			end
		
		default:
			n_state = ON_STATE;

	endcase
end

assign clk_gate = (c_state == CLK_GATE_STATE) & (~active) & (we_can_clk_gate);
                                                                                                                                                                             
assign pwr_gate = ((c_state == PWR_GATE_STATE) & (~active) & (we_can_pwr_gate) ) ? 1 : 0;

//assign clk_gate = (((c_state == CLK_GATE_STATE) && (~active)) || ((c_state == ON_STATE) & we_can_clk_gate & (~active) )) 
															  //|| ((c_state == CLK_GATE_BUT_ON_STATE) & we_can_clk_gate & (~active) )//);
															  //|| ((c_state == PWR_GATE_BUT_ON_STATE) & we_can_clk_gate & (~active)));

//assign pwr_gate = (c_state == PWR_GATE_STATE) && (~active) && (we_can_pwr_gate);

//assign pwr_gate = 0;

//assign pwr_gate = ((c_state == PWR_GATE_STATE) & (~active) & (we_can_pwr_gate) ) ? 1 : 0;
//assign pwr_gate = (c_state == PWR_GATE_STATE) && (we_can_pwr_gate);
//assign pwr_gate = (c_state == PWR_GATE_STATE) && (~active);
//assign signal_off = clk_gate | pwr_gate | (c_state == WAKE_UP_STATE)|((c_state == PWR_GATE_BUT_ON_STATE) && (wake_up_counter < WAKE_UP_LATENCY-1));
assign signal_off = clk_gate || pwr_gate || (c_state == WAKE_UP_STATE);

`elsif NO_PM


assign clk_gate = 0;
assign pwr_gate = 0;
assign signal_off = 0;


`else
always @(posedge clk)
begin
	if(reset) begin
		c_state <= ON_STATE;
	end	
	else begin
		c_state <= n_state;
	end
end


always @ (*)
begin
	case (c_state)

		ON_STATE : begin
			if (we_can_clk_gate)
				n_state = CLK_GATE_STATE;
			else if (we_can_pwr_gate)
				n_state = PWR_GATE_STATE;
			else
				n_state = ON_STATE;
		end
		
		PWR_GATE_STATE : begin
			if (request_to_on) 
				n_state = WAKE_UP_STATE;
			else
				n_state = PWR_GATE_STATE;
		end

		CLK_GATE_STATE : begin
			if (request_to_on)
				n_state = ON_STATE;
			else if (we_can_pwr_gate)
				n_state = PWR_GATE_STATE;
			else
				n_state = CLK_GATE_STATE;
		end

		WAKE_UP_STATE : begin
			n_state = ((wake_up_counter >= WAKE_UP_LATENCY - 1) ) ? ON_STATE
							: WAKE_UP_STATE;
			end
		
		default:
			n_state = ON_STATE;

	endcase
end



                                                                                                             
assign clk_gate = (c_state == CLK_GATE_STATE) & (~active) & (we_can_clk_gate);
//assign clk_gate = 0;                                                                                                                                                                               
assign pwr_gate = ((c_state == PWR_GATE_STATE) & (~active) & (we_can_pwr_gate) ) ? 1 : 0;
//assign pwr_gate = 0;
assign signal_off = clk_gate | pwr_gate | (c_state == WAKE_UP_STATE);

`endif
//assign pwr_gate = ((c_state == PWR_GATE_STATE) & (~active) ) ? 1 : 0;
/*
assign signal_off = ((c_state == CLK_GATE_STATE) | 
					 (c_state == PWR_GATE_STATE) |
					 (c_state == WAKE_UP_STATE)  |
					 ((c_state == PWR_GATE_BUT_ON_STATE) && (wake_up_counter < WAKE_UP_LATENCY-1)) )? 1 :0;
*/		

endmodule
