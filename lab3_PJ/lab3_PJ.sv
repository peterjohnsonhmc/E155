//Created by Peter Johnson
//pjohnson@g.hmc.edu
//Sep 22 2018
//Summary: Read input from a 4x4 matrix keypad, displaying the last two digits pressed on 2 7-segment displays with most recent entry on the right

module lab3_PJ(input logic clk,
					input logic [3:0] col, 		//columns of keypad
					output logic [3:0] row,
					output logic [1:0] anode, 	//turns anodes on and off, anode 1 correspons to s1 and display 1
					output logic [6:0] seg);
	//Internal Logic variables
	logic [3:0] hex,s0,s1,s; 	//current hexadecimal input, most recent pressed, press before that, what time mux is displaying
	logic [31:0] q; 	// word with most significant bit to be toggled
	logic cycle; 		//either on the 0 half cycle or the 1 half cycle
	
	

	
	//ScannerFSM instantiation
	scannerFSM scanner(clk,col, row, hex, inputPres);
	
	//Some logic or FSM to decide what s0 and s1 are based on the signal
	assign s0 = hex;
	assign s1 = hex;
	
	//****Old Display Section****//
	
	//Operation will occur at 60Hz
	//Will use a counter module defined below
	counter countLED(clk, q); 
	
	//Cycle will toggle at the same freq as the most significant bit
	//0 Cycle is when s is s0, and display 0 is lit, 1 cycle is when s is s1 and display 1 is lit
	assign cycle=q[31];
	
	//Multiplex based on what cycle we are on
	mux2 timeMux(s0,s1,cycle,s);
	
	//Turn on the anode depedning on which half cycle is the current one
	assign anode[1]= ~cycle; //when cycle=0 turn anode[1] on
	assign anode[0]= cycle; //opposite for anode[0]
	
	
	//7 Segment display logic
	//Encoding-	 seg 6543210
	// 				  abcdefg
	always_comb
		case(s)
		4'b0000:seg=7'b0000001; //0
		4'b0001:seg=7'b1001111; //1
		4'b0010:seg=7'b0010010; //2
		4'b0011:seg=7'b0000110; //3
		4'b0100:seg=7'b1001100; //4
		4'b0101:seg=7'b0100100; //5
		4'b0110:seg=7'b0100000; //6
		4'b0111:seg=7'b0001111; //7
		4'b1000:seg=7'b0000000; //8
		4'b1001:seg=7'b0001100; //9
		4'b1010:seg=7'b0001000; //A
		4'b1011:seg=7'b1100000; //b
		4'b1100:seg=7'b0110001; //C
		4'b1101:seg=7'b1000010; //d
		4'b1110:seg=7'b0110000; //E
		4'b1111:seg=7'b0111000; //F
		default:seg=7'b0110110; //Default is to display 3 horizontal lines which should never happen-can tell something is wrong
		endcase
		
		//Note that to turn on the LEDs we actually need to pass a 0 not a 1 so truth table looks inverted from what it normally is
	
endmodule

//Scanner Circuit Module
//Created by Peter Johnson
//pjohnson@g.hmc.edu
//September 22, 2018
//Sends out pulses to each row and checks which columns are connected to determine which button if any were pressed on the switch
//Takes in the row that is on (Will have been cleaned/debounced)
//Output is which column is on and the hexadecimal value of button pushed
//Final output inputPres deals with whether any input was present
module scannerFSM(input logic clk,  
						input logic [3:0] col, 
						output logic [3:0] row,
						output logic [3:0] hex,
						output logic inputPres); 
  typedef enum logic [1:0] {S0, S1, S2, S3} statetype; 
  statetype state, nextstate; 
  
  // state register 
  always_ff @(posedge clk)  
  state <= nextstate; 
  
  // next state logic 
  always_comb 
		case (state) 
			S0: nextstate=S1;  
			S1: nextstate=S2;
			S2: nextstate=S3;
			S3: nextstate=S0;  
		endcase 
	// output logic 
	//Logic for setting row values
	always_comb
		case(state)
			S0:row=4'b0001; 
			S1:row=4'b0100;
			S2:row=4'b0010;
			S3:row=4'b0001;
			default:row=4'b0000; //Default is to power no rows which should never happen
		endcase	
	//Logic for setting hex values
	always_comb
		case(state)
			S0: if 		(col[0]) hex=4'b0001; //1
				 else if (col[1]) hex=4'b0010; //2
				 else if (col[2]) hex=4'b0011; //3
				 else if	(col[3]) hex=4'b1010; //A
				 else             hex=4'b0000; //Nothing was pressed
			S1: if 		(col[0]) hex=4'b0100; //4
				 else if (col[1]) hex=4'b0101; //5
				 else if (col[2]) hex=4'b0110; //6
				 else if (col[3]) hex=4'b1011; //b
				 else             hex=4'b0000; //Nothing was pressed
			S2: if 		(col[0]) hex=4'b0111; //7
				 else if (col[1]) hex=4'b1000; //8
				 else if (col[2]) hex=4'b1001; //9
				 else if (col[3]) hex=4'b1100; //C
				 else             hex=4'b0000; //Nothing was pressed
			S3: if 		(col[0]) hex=4'b1110; //E
				 else if (col[1]) hex=4'b0000; //0
				 else if (col[2]) hex=4'b1111; //F
				 else if (col[3]) hex=4'b1101; //d
				 else             hex=4'b0000; //Nothing was pressed 
			default:					hex=4'b0000; //Default is 0
		endcase	
		//Set the inputPresent bit by or the bits of col
		assign inputPres = |col;
endmodule

//Idiomatic counter code provided by Prof David Harris in Ch. 5 slides
//Modified by Peter Johnson September 16, 2018
//pjohnson@g.hmc.edu
//a divide by 2^N counter where the most significant bit toggles every 2^N cycles
//value of p(value incremented) selected so that toggling occurs at 60 Hz.
//Value is 60Hz about the edge of what is visible for the human eye
//fout=fclk*p/2^N
//fout=60 Hz, fclk=40MHz, N=32 bits so p=6442
module counter (input logic clk,
					 output logic [31:0] q);
 always_ff @ (posedge clk)
				q <= q+6442;
		
endmodule

//Idiomatic 2:1 multiplexer using conditional assignment
//Provided by David Harris-Digital Design and Computer Architecture
module mux2 (input logic[3:0] d0,d1,
				input logic 		s,
				output logic[3:0] y);
	// if s=1 y=d1, if s=0, y=d0
	assign y=s?d1:d0;
endmodule

