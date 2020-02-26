/////////////////////////////////////////////
// aes.sv
// HMC E155 16 September 2015 
// bchasnov@hmc.edu, David_Harris@hmc.edu
//
//Modified October 30 2018 for lab7
//pjohnson@g.hmc.edu
/////////////////////////////////////////////

/////////////////////////////////////////////
// testbench
//   Tests AES with cases from FIPS-197 appendix
/////////////////////////////////////////////

module testbench();
    logic clk, load, done, sck, sdi, sdo;
    logic [127:0] key, plaintext, cyphertext, expected;
	 logic [255:0] comb;
    logic [8:0] i;
    
    // device under test
    aes dut(clk, sck, sdi, sdo, load, done);
    
    // test case
    initial begin   
// Test case from FIPS-197 Appendix A.1, B
        key       <= 128'h2B7E151628AED2A6ABF7158809CF4F3C;
        plaintext <= 128'h3243F6A8885A308D313198A2E0370734;
        expected  <= 128'h3925841D02DC09FBDC118597196A0B32;

// Alternate test case from Appendix C.1
//      key       <= 128'h000102030405060708090A0B0C0D0E0F;
//      plaintext <= 128'h00112233445566778899AABBCCDDEEFF;
//      expected  <= 128'h69C4E0D86A7B0430D8CDB78070B4C55A;
    end
    
    // generate clock and load signals
    initial 
        forever begin
            clk = 1'b0; #5;
            clk = 1'b1; #5;
        end
        
    initial begin
      i = 0;
      load = 1'b1;
    end 
    
	assign comb = {plaintext, key};
    // shift in test vectors, wait until done, and shift out result
    always @(posedge clk) begin
      if (i == 256) load = 1'b0;
      if (i<256) begin
        #1; sdi = comb[255-i];
        #1; sck = 1; #5; sck = 0;
        i = i + 1;
      end else if (done && i < 384) begin
        #1; sck = 1; 
        #1; cyphertext[383-i] = sdo;
        #4; sck = 0;
        i = i + 1;
      end else if (i == 384) begin
            if (cyphertext == expected)
                $display("Testbench ran successfully");
            else $display("Error: cyphertext = %h, expected %h",
                cyphertext, expected);
            $stop();
      
      end
    end
    
endmodule


/////////////////////////////////////////////
// aes
//   Top level module with SPI interface and SPI core
/////////////////////////////////////////////

module aes(input  logic clk,
           input  logic sck, 
           input  logic sdi,
           output logic sdo,
           input  logic load,
           output logic done);
                    
    logic [127:0] key, plaintext, cyphertext;
    
    aes_spi spi(sck, sdi, sdo, done, key, plaintext, cyphertext);   
    aes_core core(clk, load, key, plaintext, done, cyphertext);
endmodule

/////////////////////////////////////////////
// aes_spi
//   SPI interface.  Shifts in key and plaintext
//   Captures ciphertext when done, then shifts it out
//   Tricky cases to properly change sdo on negedge clk
/////////////////////////////////////////////

module aes_spi(input  logic sck, 
               input  logic sdi,
               output logic sdo,
               input  logic done,
               output logic [127:0] key, plaintext,
               input  logic [127:0] cyphertext);

    logic         sdodelayed, wasdone;
    logic [127:0] cyphertextcaptured;
               
    // assert load
    // apply 256 sclks to shift in key and plaintext, starting with plaintext[0]
    // then deassert load, wait until done
    // then apply 128 sclks to shift out cyphertext, starting with cyphertext[0]
    always_ff @(posedge sck)
        if (!wasdone)  {cyphertextcaptured, plaintext, key} = {cyphertext, plaintext[126:0], key, sdi};
        else           {cyphertextcaptured, plaintext, key} = {cyphertextcaptured[126:0], plaintext, key, sdi}; 
    
    // sdo should change on the negative edge of sck
    always_ff @(negedge sck) begin
        wasdone = done;
        sdodelayed = cyphertextcaptured[126];
    end
    
    // when done is first asserted, shift out msb before clock edge
    assign sdo = (done & !wasdone) ? cyphertext[127] : sdodelayed;
endmodule

/////////////////////////////////////////////
// aes_core
//   top level AES encryption module
//   when load is asserted, takes the current key and plaintext
//   generates cyphertext and asserts done when complete 11 cycles later
// 
//   See FIPS-197 with Nk = 4, Nb = 4, Nr = 10
//
//   The key and message are 128-bit values packed into an array of 16 bytes as
//   shown below
//        [127:120] [95:88] [63:56] [31:24]     S0,0    S0,1    S0,2    S0,3    0  4  8 12
//        [119:112] [87:80] [55:48] [23:16]     S1,0    S1,1    S1,2    S1,3    1  5  9 13
//        [111:104] [79:72] [47:40] [15:8]      S2,0    S2,1    S2,2    S2,3    2  6 10 14
//        [103:96]  [71:64] [39:32] [7:0]       S3,0    S3,1    S3,2    S3,3    3  7 11 15
//
//   Equivalently, the values are packed into four words as given
//        [127:96]  [95:64] [63:32] [31:0]      w[0]    w[1]    w[2]    w[3]
/////////////////////////////////////////////

module aes_core(input  logic         clk,
                input  logic         load,
                input  logic [127:0] key, 
                input  logic [127:0] plaintext, 
                output logic         done, 
                output logic [127:0] cyphertext);

  // Your code goes here
  logic [127:0] state, stateSB, stateSR, stateMC, stateSel, stateAR, stateFin, oldstate;				//state and intermediate values of the state
  logic [127:0] words, wordsKE, wordsSel, oldwords;
  logic start, last, reset;
  logic[31:0] Rcon;
  
  //level to pulse to reset FSM when load is done
  levelToPulse lvp(clk,load,reset);
  
  controllerFSM control(clk, reset, load, start, last, done, Rcon);
  
  //state = input or the old state 
  bigmux2 muxStateIn(oldstate, plaintext, start, state); 	
  //words=key or oldwords
  bigmux2 muxKeyIn(oldwords, key, start, words); 
  
  //Main path
  subBytes SB(state,stateSB);
  shiftRows SR(stateSB,stateSR);
  mixcolumns MC(stateSR,stateMC);
  
  //Expand the old words
  keyExpansionRounds KE(words, Rcon, wordsKE);
  
  //Select words based on whether the first round
  bigmux2 muxWordsGen(wordsKE, words, start, wordsSel);  
  //Select between initial round and general round
  bigmux2 muxStateGen(stateMC, state, start, stateSel);
  
    //Select whether this is the last round or not
  bigmux2 muxFin(stateSel, stateSR, last, stateFin);
  
  //StateAR and the current words goes to AddRoundKey
  addRoundKey AR(stateFin, wordsSel, stateAR); 
 
  //store the values of the state and the words of the keyexpansion
  flopen stateFlop(clk,~done, stateAR, oldstate);
  flopen keyExFlop(clk,~done, wordsSel, oldwords);
  
  assign cyphertext = oldstate;

  
endmodule


module controllerFSM(input logic			clk,
						input logic 		reset,
						input logic			load,
						output logic		start,
						output logic		last,
						output logic 		done,
						output logic[31:0] Rcon);
						
		 //FSM to do the looping from 1 to Nr-1 (9 rounds since last round is special)
	 typedef enum logic [4:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11} statetype;
	statetype s, ns;
	
	// state register
	always_ff @(posedge clk, posedge reset)
		if (reset) s <= S0;
		else s <= ns;
	
	// next state logic
	always_comb
		case (s)
			S0: ns = S1;
			S1: ns = S2;
			S2: ns = S3;
			S3: ns = S4;
			S4: ns = S5;
			S5: ns = S6;
			S6: ns = S7;
			S7: ns = S8;
			S8: ns = S9;
			S9: ns = S10;
			S10: ns = S11;
			S11: ns = S11;
			default: ns = S1;
		endcase
	
	// output logic
	//
	always_comb
		case(s)
			S0: begin
					start=1'b1;
					last =1'b0;
					Rcon =32'h00000000;//Do not matter
					done = 1'b0;
				end
			S1: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h01000000;
					done = 1'b0;
				end
			S2: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h02000000;
					done = 1'b0;
				end
			S3: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h04000000;
					done = 1'b0;
				end
			S4: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h08000000;
					done = 1'b0;
				end
			S5: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h10000000;
					done = 1'b0;
				end
			S6: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h20000000;
					done = 1'b0;
				end
			S7: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h40000000;
					done = 1'b0;
				end
			S8: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h80000000;
					done = 1'b0;
				end
			S9: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h1b000000;
					done = 1'b0;
				end
			S10: begin
					start=1'b0;
					last =1'b1;
					Rcon =32'h36000000;
					done = 1'b0;
				end
			S11: begin
					start=1'b0;
					last =1'b1;
					Rcon =32'h00000000; //It do not matter
					done = 1'b1;
				end
			default: begin
					start=1'b0;
					last =1'b0;
					Rcon =32'h00000000;
					done = 1'b0;
				end
		endcase
endmodule

/////////////////////////////////////////////
// subBytes
//   Infamous AES byte substitutions with magic numbers
//   Section 5.1.1, Figure 7
/////////////////////////////////////////////

module subBytes(input  logic [127:0] s,
					 output logic [127:0] sp);
            
  //Call sbox for each byte in the state
  sbox sbox1(s[127:120], sp[127:120]); 
  sbox sbox2(s[119:112], sp[119:112]); 
  sbox sbox3(s[111:104], sp[111:104]); 
  sbox sbox4(s[103:96] , sp[103:96]); 
  sbox sbox5(s[95:88],   sp[95:88]); 
  sbox sbox6(s[87:80],   sp[87:80]); 
  sbox sbox7(s[79:72] ,  sp[79:72]); 
  sbox sbox8(s[71:64]  , sp[71:64]); 
  sbox sbox9(s[63:56],   sp[63:56]); 
  sbox sbox10(s[55:48],   sp[55:48]); 
  sbox sbox11(s[47:40] ,  sp[47:40]); 
  sbox sbox12(s[39:32]  , sp[39:32]); 
  sbox sbox13(s[31:24],   sp[31:24]); 
  sbox sbox14(s[23:16],   sp[23:16]); 
  sbox sbox15(s[15:8] ,   sp[15:8]); 
  sbox sbox16(s[7:0]  ,   sp[7:0]);  
endmodule

/////////////////////////////////////////////
// sbox
//   Infamous AES byte substitutions with magic numbers
//   Section 5.1.1, Figure 7
/////////////////////////////////////////////

module sbox(input  logic [7:0] a,
            output logic [7:0] y);
            
  // sbox implemented as a ROM
  logic [7:0] sbox[0:255];

  initial   $readmemh("sbox.txt", sbox);
  assign y = sbox[a];
endmodule

/////////////////////////////////////////////
// shiftRows
//   Bytes in the last 3 rows of the State are cyclically shifted
//   Section 5.1.2, Figure 8
/////////////////////////////////////////////

module shiftRows(input  logic [127:0] s,
					  output logic [127:0] sp);
  
  //Row 0 Nothing to do
  assign sp[127:120] = s[127:120];
  assign sp[95:88] = s[95:88];
  assign sp[63:56] = s[63:56];
  assign sp[31:24] = s[31:24];
  //Row 1
  assign sp[119:112] = s[87:80];				//Replace with byte to the right
  assign sp[87:80]   = s[55:48];		
  assign sp[55:48]   = s[23:16];
  assign sp[23:16]   = s[119:112];	
  //Row 2
  assign sp[111:104]= s[47:40];				//Replace with byte 2 to the right
  assign sp[79:72]  = s[15:8];
  assign sp[47:40]  = s[111:104]; 
  assign sp[15:8]   = s[79:72];  
  //Row 3
  assign sp[103:96] = s[7:0];					//Replace with byte 3 to the right
  assign sp[71:64]  = s[103:96]; 
  assign sp[39:32]  = s[71:64];
  assign sp[7:0]    = s[39:32]; 
endmodule

/////////////////////////////////////////////
// mixcolumns
//   Even funkier action on columns
//   Section 5.1.3, Figure 9
//   Same operation performed on each of four columns
/////////////////////////////////////////////

module mixcolumns(input  logic [127:0] a,
                  output logic [127:0] y);

  mixcolumn mc0(a[127:96], y[127:96]);
  mixcolumn mc1(a[95:64],  y[95:64]);
  mixcolumn mc2(a[63:32],  y[63:32]);
  mixcolumn mc3(a[31:0],   y[31:0]);
endmodule

/////////////////////////////////////////////
// mixcolumn
//   Perform Galois field operations on bytes in a column
//   See EQ(4) from E. Ahmed et al, Lightweight Mix Columns Implementation for AES, AIC09
//   for this hardware implementation
/////////////////////////////////////////////

module mixcolumn(input  logic [31:0] a,
                 output logic [31:0] y);
                      
        logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3, t0, t1, t2, t3, tmp;
        
        assign {a0, a1, a2, a3} = a;
        assign tmp = a0 ^ a1 ^ a2 ^ a3;
    
        galoismult gm0(a0^a1, t0);
        galoismult gm1(a1^a2, t1);
        galoismult gm2(a2^a3, t2);
        galoismult gm3(a3^a0, t3);
        
        assign y0 = a0 ^ tmp ^ t0;
        assign y1 = a1 ^ tmp ^ t1;
        assign y2 = a2 ^ tmp ^ t2;
        assign y3 = a3 ^ tmp ^ t3;
        assign y = {y0, y1, y2, y3};    
endmodule

/////////////////////////////////////////////
// galoismult
//   Multiply by x in GF(2^8) is a left shift
//   followed by an XOR if the result overflows
//   Uses irreducible polynomial x^8+x^4+x^3+x+1 = 00011011
/////////////////////////////////////////////

module galoismult(input  logic [7:0] a,
                  output logic [7:0] y);

    logic [7:0] ashift;
    
    assign ashift = {a[6:0], 1'b0};
    assign y = a[7] ? (ashift ^ 8'b00011011) : ashift;
endmodule

/////////////////////////////////////////////
// addRoundKey
//   A round Key is added to the state by a simple bitwise XOR
//   Each round key consist of Nb (4) words
//   Section 5.1.4 Figure 10
//   
/////////////////////////////////////////////

module addRoundKey(input  logic [127:0] s,
						 input  logic [127:0] words, //words is 4 cols from keySched
					    output logic [127:0] sp);
			  
  assign sp = s^words;         

endmodule

//KEY EXPANSION Functions

/////////////////////////////////////////////
// keyExpansionRounds
//    takes the previous 4 words, and generates the next 4 words (Sec. 5.2,
//    keySched should have 44 words (Nb*(Nr+1)) w words for 11 rounds
//    
//		Fig. 11) 
//   
/////////////////////////////////////////////

module keyExpansionRounds(input logic [127:0] words,
								  input logic [31:0] Rcon,
								  output logic [127:0] wordsP);
	logic [127:0] t1,t2,t3; //intermediate logic
	
  keyExpansionHelper keyHelp1(words,1'b1, Rcon, t1 );
  keyExpansionHelper keyHelp2(t1,1'b0, Rcon, t2 );
  keyExpansionHelper keyHelp3(t2,1'b0, Rcon, t3 );
  keyExpansionHelper keyHelp4(t3,1'b0, Rcon, wordsP );
  
endmodule

/////////////////////////////////////////////
// keyExpansionHelper
//    takes the previous 4 words and generates a new word (Sec. 5.2,
//    keySched should have 44 words (Nb*(Nr+1)) w words for 11 rounds
//    
//		Fig. 11) 
//   
/////////////////////////////////////////////
  
module keyExpansionHelper(input logic  [127:0] words,
									input logic				rcEn,
									input logic [31:0] Rcon,
									output logic [127:0] wordsP);
  logic [31:0] temp0, temp1,temp2,temp3,temp4;
  logic [31:0] word0, word1, word2, word3;
  
  assign word0 = words[127:96];
  assign word1 = words[95:64];
  assign word2 = words[63:32];
  assign word3 = words[31:0];
  
  assign temp0 = word3;
  
  rotWord rotWordA(temp0,temp1);
  subWord subWordA(temp1,temp2);
  assign temp3 = temp2 ^ Rcon;
  
  //if statements
  //d0 temp0 (rcEn low)
  //d1 temp1 (rcEn high)
  mux2 muxA(word3,temp3,rcEn,temp4);
  assign wordsP[31:0] = word0^temp4; //Put in highest index
  assign wordsP[127:32]=words[95:0];
  
endmodule

/////////////////////////////////////////////
// subWord
//    takes a four-byte input word and applies the S-box (Sec. 5.1.1,
//		Fig. 7) to each of the four bytes to produce an output word. 
//   
/////////////////////////////////////////////

module subWord(input  logic [31:0] w,
					output logic [31:0] wp);
  //Apply sbox to each byte of the word
  sbox sboxA(w[31:24],wp[31:24]); 
  sbox sboxB(w[23:16],wp[23:16]); 
  sbox sboxC(w[15:8] ,wp[15:8]); 
  sbox sboxD(w[7:0]  ,wp[7:0]);  
  
endmodule

/////////////////////////////////////////////
// rotWord
//    takes a word [a0,a1,a2,a3] as input, performs a 
//    cyclic permutation, and returns the word [a1,a2,a3,a0]
//   
/////////////////////////////////////////////

module rotWord(input  logic [31:0] w,
					output logic [31:0] wp);
  //assign each byte to a new spot
  assign wp[31:24]=w[23:16]; 
  assign wp[23:16]=w[15:8]; 
  assign wp[15:8] =w[7:0]; 
  assign wp[7:0]  =w[31:24];  
  
endmodule


//IDIOMATIC Digital design elements

//Mux code provided in Digital Design by Harris and Harris

//128 bit mux
module bigmux2(input logic [127:0] d0, d1,
				 input logic 				 s,
				 output logic [127:0]  y);
  //When s1 is 0, d0 is selected
  assign y=s ? d1:d0;
endmodule

//32 bit mux
module mux2(input logic [31:0] d0, d1,
				 input logic 				 s,
				 output logic [31:0]  y);
  //When s1 is 0, d0 is selected
  assign y=s ? d1:d0;
endmodule

//Flip flop
module flopen(input logic clk,en, 
				  input logic [127:0] d,
				  output logic [127:0] q);
	always_ff @(posedge clk)
		if(en) q <= d;
		else 	 q <= q;
endmodule

//Level to pulse converter
module levelToPulse(input logic clk, 
						  input logic level,
						  output logic enable);
  typedef enum logic [1:0] {S0, S1, S2} statetype;
  statetype state, nextstate;
  
  //state register
  always_ff @(posedge clk)
		state <= nextstate;
		
  //next state logic
  always_comb
		case (state)
			S0: if (~level) nextstate=S1; //REgular level to pulse, but with the level inverted since we want a pulse when we switch to 0
				 else 		 nextstate=S0;
			S1: if (~level) nextstate=S2;
				 else			 nextstate=S0;
			S2: if (~level) nextstate=S2;
				 else 		 nextstate=S0;
			default:			 nextstate=S0;
		endcase
	
	//output logic
	assign enable=((state==S1)|(state ==S0));
endmodule
