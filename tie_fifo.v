
/** @module : fifo
 */
// You can write and read the same data from the fifo during the same 
// clock cycle. 

module tie_fifo #(parameter DATA_WIDTH = 32, Q_DEPTH_BITS = 6) (
    input clk,
    input reset,
	input ON,
    input [DATA_WIDTH-1:0] write_data,
    input wrtEn,
    input rdEn,
    input peek,
    
    output [DATA_WIDTH-1:0] read_data,
    //output valid,
    output full,
    output empty
); 

    localparam Q_DEPTH    = 1 << Q_DEPTH_BITS; 
    localparam BUFF_DEPTH = Q_DEPTH - 2;//TODO/
    
    reg  [Q_DEPTH_BITS-1:0]   front; 
    reg  [Q_DEPTH_BITS-1:0]   rear;
    reg  [DATA_WIDTH - 1: 0]  queue [0:Q_DEPTH-1];
    reg  [Q_DEPTH_BITS:0]     current_size;
	wire bare   = (current_size == 0); 
	wire filled = (current_size == Q_DEPTH); 
	integer i; 

//--------------Code Starts Here----------------------- 
always @ (posedge clk) begin
  if (reset) begin
  		front        <= 0; 
  		rear         <= 0; 
  		current_size <= 0; 
  end 
  else if (ON) begin 
	//else begin 
			if(bare & wrtEn & rdEn) begin 
				queue [rear]  <= queue [rear];
				rear          <= rear;
				front         <= front;
				current_size  <= 0; 
			end 
			else begin 
				queue [rear]  <= (wrtEn & ~filled)? write_data : queue [rear];
				rear          <= (wrtEn & ~filled)? (rear == (Q_DEPTH -1))? 0 : 
								 (rear + 1) : rear;
				front         <= (rdEn & ~bare)? (front == (Q_DEPTH -1))? 0 : 
								 (front + 1) : front;
				current_size  <= (wrtEn & ~rdEn & ~filled)? (current_size + 1) : 
								 (~wrtEn & rdEn & ~bare)? 
								 (current_size -1): current_size; 
			end 
	  /*		
      if (wrtEn & filled) begin
           $display ("ERROR: Trying to enqueue data: %h  on a full Q!",  write_data);
           $display ("INFO:  Q depth %d and current Q size %d",Q_DEPTH, current_size);
		   $display ("INFO:  Current head %d and current rear %d",front, rear);
		   for (i = 0; i < Q_DEPTH; i=i+1) begin
				$display ("INFO: Index [%d] data [%h]",i, queue[i]);
		   end 
      end
     // if (rdEn & bare & ~wrtEn) $display ("Warning: Trying to dequeue an empty Q!");
      if (peek & bare & ~wrtEn) $display ("Warning: Peeking at an empty Q!");
	*/
  end
end

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
assign  read_data   = (wrtEn & (rdEn|peek) & bare)? write_data : queue [front];
//assign  valid       = (((wrtEn & (rdEn|peek) & bare) | ((rdEn|peek) & ~bare))& ~reset)? 1 : 0;
//assign  full        = (~reset & (filled | (wrtEn & ~rdEn & (current_size >= BUFF_DEPTH))));
assign  full        = (~reset & (filled | (current_size >= BUFF_DEPTH)));
//assign  empty       = (reset | bare |(~wrtEn & rdEn & (current_size == 1))); /*TODO for silly Xtensa Interface*/
assign  empty       = (reset | (bare & ~wrtEn) );

     
endmodule
