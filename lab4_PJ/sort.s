//sort.s
//29 September 2018 pjohnson@g.hmc.edu
//Based on code provided by david_harris@hmc.edu
//sort 12 numbers for E155 Lab 4 using bubblesort algorithm

.text
.global main
main:
	LDR R3,=array2		//load base address of a into R3
	MOV R1, #0		//Set loopoing variable i=0
for1:
	CMP R1,#11     	 	//Check i<11
	BGE done		//Branch to end  of loop 1 if cond met
	MOV R2, #0		//Set 2nd looping variable j=0
	MOV R4, #1		//Set looping variable j+1=1
for2:
	CMP R2,#11		//check j<11
	BGE done2		//Branch to end of loop 2 if cond  met
	LDRSB R6,[R3,R2]	//R6 gets the value at  R3 offset by R2(j) (a[j])
	LDRSB R7,[R3,R4]	//R7 gets the value at R3 offset by R4(j+1) (a[j+1])
	CMP R6,R7		//if a[j] > a[j+1]
	BLE ifdone		//branch to end of if statement if Less or equal
	MOV R5, R7		//temp gets a[j+1]
	STRB R6,[R3,R4] 	//R6(a[j])  goes into a[j+1]
	STRB R7,[R3,R2]		//R7(a[j+1]) goes into a[j]
ifdone:
	ADD R2,R2,#1		//increment j
	ADD R4,R4,#1		//increment j+1
	B for2			//return to start of loop 2
done2:
	ADD R1,R1, #1		//increment i
	B for1			//return to start of loop1
done: 
	LDRSB R0,[R3]		//Display the outputs in individual registers // No offset necessary
	LDRSB R1,[R3,#1]
	LDRSB R2,[R3,#2]
	LDRSB R4,[R3,#3]
	LDRSB R5,[R3,#4]
	LDRSB R6,[R3,#5]
	LDRSB R7,[R3,#6]
	LDRSB R8,[R3,#7]
	LDRSB R9,[R3,#8]
	LDRSB R10,[R3,#9]
	LDRSB R11,[R3,#10]
	LDRSB R12,[R3,#11]
	NOP
	BX LR
.data
array1:
	.byte 0x08
	.byte 0x10
	.byte 0xFF
	.byte 0x11
	.byte 0x12
	.byte 0x0F
	.byte 0xE6
	.byte 0x35
	.byte 0x01
	.byte 0x9A
	.byte 0x0B
	.byte 0xCD
array2:
	.byte 0x7F
	.byte 0x31
	.byte 0x70
	.byte 0x12
	.byte 0x36
	.byte 0x00
	.byte 0x7F
	.byte 0x7F
	.byte 0x80
	.byte 0x82
	.byte 0x95
	.byte 0x01
.end