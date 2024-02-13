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
	  
	* How the testbench is going to preload the counter, which is inside the design? 
	  I can use this feature to create good testbenches of my own.
	
	Givens and Observations:
	
	* REQ will at least be 2 consecutive cycles wide. 
	* The count_o value is 0x0 even after the REQ has de-asserted. Which means that the 
	  output remembers the last value driven, eg: UPPER HALF of the 64-bit value unless 
	  the new REQ appears. 
	
	Assumptions:
	
	* If multiple REQ come without a cycle gap, will have to use atomic_i to differentiate
	  b/w 2 consecutive REQs. Assertion of atomic_i will mark as the next consecutive REQ
	
	
	CAVEATS:
	
	
	EDGE CASES:
	* When the count value crosses the LOWER 32 bits and updates the value in UPPER 32 bits.
	* Need to know at what interval, will the above situation will occur?
	
	FSM SPEC:
	
	FIRST: (acts as IDLE)
	* When no REQ, be in the IDLE state. 
	* IF (REQ_i && atomic_i) go to FIRST state. count_o be NBA assigned the LOWER HALF value.
	* ELSE remain in IDLE state. count_o retains whatever was the previous value.
	
	SECOND: 
	* By default, REQ_i will be HIGH, and the atomic_i will be LOW. No need to check it.
	* count_o be NBA assigned the UPPER HALF value. 
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
	reg  ack;
	
	localparam [1:0] FIRST  = 2'd0;
	localparam [1:0] SECOND = 2'd1; 
	
	always_ff @(posedge clk or posedge reset) begin 
		if (reset) begin 
			ack     <= 0;
			counter <= 0;
		end else begin
			counter <= (trig_i) ? counter + 1 : counter;
		end
	end 

endmodule
