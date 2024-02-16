// 
//  While working on the next generation SoC you were asked to design a 64-bit event counter 
//  which would be interfaced with a 32-bit bus controlled via a microcontroller. 
//	The 64-bit counter is incremented whenever a trigger input is seen. 
//	Given that the counter is read by a 32-bit bus, a full 64-bit read of the counter needs two 32-bit accesses. 
//	It is important that these two accesses should be single-copy atomic.
//  
//  Design the 64-bit counter module and the appropriate interfacing mechanism to 
//	ensure single-copy atomic counter read operations. 
//	All the flops should be positive edge triggered with asynchronous resets (if any).
//  
//  Interface Definition
//  trig_i    : Trigger input to increment the counter
//  req_i     : A read request to the counter
//  atomic_i  : Marks whether the current request is the first part of the two 32-bit accesses to read
//              the 64-bit counter. Use this input to save the current value of the upper 32-bit of
//              the counter in-order to ensure single-copy atomic operation
//  ack_o     : Acknowledge output from the counter
//  count_o   : 32-bit counter value given as output to the controller
//  Interface Requirements
//  The counter value is read by a 32-bit wide bus but the output should be single-copy atomic. 
//	The interface is a simple request and acknowledge interface with the following strict requirements:
//  
//  * Request can be a pulse or can get back to back multiple requests
//  * The acknowledge output must be given one cycle after the request is asserted
//  * The controller will always send two requests in order to read the full 64-bit counter
//  * The first request will always have the atomic_i input asserted
//  * The second request will not have the atomic_i input asserted
//
//	Please note that the testbench preloads the counter for this problem to test interesting scenarios.
//

	/*
	DESIGN THINKING:
	
	QUESTIONS:
	
	* What is the meaning of single-copy atomic here?
	* Will trigger be a single cycle or a multi cycle event?
	* If multi cycle trigger is detected, should I keep incrementing the counter?
	* What happens when trigger and request are simultaneously asserted?
	* In case of back to back multiple multiple requests, is there at least 
	  a single cycle gap b/w them? I don't think so because In events to APB, there's a point:
	  
	  ** Back to back APB transactions aren't supported by interface 
	     hence there should a cycle gap before the next APB transaction is generated
	
	* If req_i stays high even after 2 cycles and atomic_i gets asserted at cycle
	  3 (1, 2, 3), will we consider this as the next read request?
	  
	* What happens when multiple REQs and multiple Triggers appear simultaneously?
	  
	  ** What happens when code is in FIRST state and trigger appears?
	  ** What happens when code is in SECOND state and trigger appears?
	  ** Does the output FSM require an IDLE state?
	  ** If you create an FSM, what is value of output going to be in each state?
	  
	* What happens if 4 REQs come consecutively? Will the ack_o be asserted for 
	  four cycles with a cycle of delay?
	
	* How do I capture the 64 bit value at (REQ && atomic_i) and store it so that 
	  it can be used after a cycle?
	  
	* How the testbench is going to preload the counter, which is inside the design? 
	  I can use this feature to create good testbenches of my own.
	  
	* How to conditionally load the preloaded count value in my own register?
	
	* How the design should respond when REQ is only for 1 cycle?
	
	* How the design should respond when REQ is for more than 2 cycle but atomic_i 
	  appears somewhere in between?
	  
	* How the design should respond when atomic_i is HIGH for 2 or more than 2 cycles?
	
	* How do I negate the one cycle delay because of counter_32_low & counter_32_upp
	
	Givens and Observations:
	
	* REQ will at least be 2 consecutive cycles wide. 
	* The count_o value is 0x0 even after the REQ has de-asserted. Which means that the 
	  output remembers the last value driven, eg: UPPER HALF of the 64-bit value unless 
	  the new REQ appears. 
	
	* It seems that the count wire is loaded from the TB.
	
	* Need to observe and reason about the exact rising of mismatch signal. 
	  I think it is related to the 1 cycle and 3 cycle request with mispositioning of 
	  atomic_i.
	
	* Focus on ack_exp and count_exp signals, these are the expected outputs.
	
	* ack_o is simply a delayed version of REQ signal, no conditionals are required to 
	  handle it.
	
	Assumptions:
	
	* If multiple REQ come without a cycle gap, will have to use atomic_i to differentiate
	  b/w 2 consecutive REQs. Assertion of atomic_i will mark as the next consecutive REQ
	
	CAVEATS:
	
	* Marks whether the current request is the first part of the two 32-bit accesses to read
	  the 64-bit counter. (VVIMP) Use this input to save the current value of the upper 32-bit of
	  the counter in-order to ensure single-copy atomic operation.
	  
	* count_o value at cycle T13.
	
	* Request can be a pulse or can get back to back multiple requests
	
    * The acknowledge output must be given one cycle after the request is asserted
   -- Irrespective of WHETHER the atomic_i IS asserted or NOT, ack_o is just a delayed 
      version of REQ
    * The controller will always send two requests in order to read the full 64-bit counter
   -- But it DOES NOT necessarily means that the two REQs will be consecutive
    * The first request will always have the atomic_i input asserted
   -- Only the REQ that has atomic_i asrted, will be considered FIRST
      And corresponding DATA be sent
    * The second request will not have the atomic_i input asserted
   -- only the REQ that does not have atomic_i asrsted, will be considered SECOND
      And corresponding DATA be sent

	EDGE CASES:
	* When the count value crosses the LOWER 32 bits and updates the value in UPPER 32 bits.
	* Need to know at what interval, will the above situation will occur?
	
	FSM SPEC:
	
	FIRST: (acts as IDLE)
	* When no REQ, be in the IDLE state. 
	* IF (REQ_i && atomic_i) go to FIRST state. count_o be NBA assigned the LOWER HALF value.
      ack_o be NBA assigned HIGH
	* ELSE remain in IDLE state. count_o retains whatever was the previous value.
	  ack_o be NBA assigned LOW
	
	SECOND: 
	* By default, REQ_i will be HIGH, and the atomic_i will be LOW. No need to check it.
	* count_o be NBA assigned the UPPER HALF value. 
	* ack_o be NBA assigned HIGH or you can latch out the previous value (HIGH)
	* FSM will be here only for one cycle.
	* Go back to IDLE without sticking here around. 
	
	
	*/






module atomic_counters (
  input  wire            clk,
  input  wire            reset,
  input  wire            trig_i,
  input  wire            req_i,
  input  wire            atomic_i,
  output wire            ack_o,
  output wire[31:0]      count_o
);

	wire [63:0] count;

	// --------------------------------------------------------
	// DO NOT CHANGE ANYTHING HERE
	// --------------------------------------------------------
	reg  [63:0] count_q;

	always_ff @(posedge clk or posedge reset)
	if (reset)
		count_q[63:0] <= 64'h0;
	else
		count_q[63:0] <= count;
	// --------------------------------------------------------

	// Write your logic here
	reg  [63:0] counter;
	reg  [31:0] counter_32_upp;
	reg  [31:0] counter_32_low;
	reg  state;
	reg  ack;
	reg  reset_ff;
	
	localparam FIRST  = 1'd0;
	localparam SECOND = 1'd1; 
	
	assign ack_o   = ack;
	assign count_o = counter_32_low;       
	
	always_ff @(posedge clk or posedge reset) begin
		reset_ff <= reset;
		if (reset) begin 
			counter <= 0;
		end else begin
			counter <= ((!reset) && reset_ff) ? count : 
			           (trig_i) ? counter + 1 : counter;
		//	counter <= (trig_i) ? counter + 1 : counter;
		end
	end 
	
	always_ff @(posedge clk or posedge reset) begin 
		if (reset) begin 
			counter_32_low <= 0;
			counter_32_upp <= 0;
			ack		       <= 0;
			state		   <= 0;
		end else begin
			ack	<= req_i;
			case (state) 
			FIRST : begin 
				if (req_i && atomic_i) begin 
					state     	   <= SECOND;
					counter_32_low <= counter[31:0];
					counter_32_upp <= counter[63:32];
				if (req_i && (!atomic_i)) begin 
					state		   <= SECOND;
					counter_32_low <= counter[31:0];
					counter_32_upp <= 0;
				end else begin
					state 		   <= FIRST;
					counter_32_low <= 0;
					counter_32_upp <= 0;
				end 
			end 
			SECOND: begin 
				state		   <= FIRST;
				counter_32_low <= counter_32_upp; // may not be wrong
				counter_32_upp <= counter_32_upp;
			end
			endcase
		end
	end 

endmodule
