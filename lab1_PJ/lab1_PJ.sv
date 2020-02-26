//Created by Peter Johnson pjohnson@g.hmc.edu
//September 12, 2018
//Summary: Test functions of Board and implement 7 segment display
module lab1_PJ(input logic clk, 
					input logic [3:0] s,
					output logic [7:0] led,
					output logic [6:0] seg);
	//Internal Logic variables
	logic reset;
	logic [31:0] q; // for the counter
	
	//LED logic
	assign led[0]=s[0];
	assign led[1]=~s[0];
	assign led[2]=s[1];
	assign led[3]=~s[1];
	assign led[4]=s[2];
	assign led[5]=~s[2];
	assign led[6]=s[2]&s[3];
	
	//LED 7 needs to blink at ~2.4 Hz
	//Will use a counter module
	counter countLED(clk,reset, q[31:0]); //Need instantiation name
	
	//LED 7 will toggle at the same freq as the most significant bit
	assign led[7]=q[31];
	
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
		default:seg=7'b1111111; //Default is to display nothing
		endcase
		
		//Note that to turn on the LEDs we actually need to pass a 0 not a 1 so truth table looks backwards
	
					

endmodule

//Idiomatic counter code provided by Prof David Harris in Ch. 5 slides
//a divide by 2^N counter where the most significant bit toggles every 2^N cycles
//value of p(value incremented) selected so that toggling occurs at 2.4 Hz.
//fout=fclk*p/2^N
//fout=2.4 Hz, fclk=40MHz, N=32 bits so p=258
module counter (input logic clk, reset,
					 output logic [31:0] q);
 always_ff @ (posedge clk, posedge reset)
		if (reset) q <= 0;
		else 		 q <= q+258;
		
endmodule
		