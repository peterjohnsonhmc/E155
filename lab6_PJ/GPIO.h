#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

/////////////////////////////////////////////////////////////////////
// Constants
/////////////////////////////////////////////////////////////////////

// GPIO FSEL Types
#define INPUT  0
#define OUTPUT 1
#define ALT0   4
#define ALT1   5
#define ALT2   6
#define ALT3   7
#define ALT4   3
#define ALT5   2

#define GPFSEL   ((volatile unsigned int *) (gpio + 0))
#define GPSET    ((volatile unsigned int *) (gpio + 7))
#define GPCLR    ((volatile unsigned int *) (gpio + 10))
#define GPLEV    ((volatile unsigned int *) (gpio + 13))

//System Timer Types
#define SYS_TIM	    ((volatile unsigned int *) (timer + 0))
#define SYS_TIM_CS  ((volatile unsigned int *) (timer + 0)) //+1 translate to a 0x4 offset
#define SYS_TIM_CLO ((volatile unsigned int *) (timer + 1))
#define SYS_TIM_CHI ((volatile unsigned int *) (timer + 2))
#define SYS_TIM_C0  ((volatile unsigned int *) (timer + 3))
#define SYS_TIM_C1  ((volatile unsigned int *) (timer + 4))
#define SYS_TIM_C2  ((volatile unsigned int *) (timer + 5))

//SPI Types
#define SPI			((volatile unsigned int *) (spi + 0))
#define SPI_CS		((volatile unsigned int *) (spi + 0))
#define SPI_FIFO	((volatile unsigned int *) (spi + 1))
#define SPI_CLK		((volatile unsigned int *) (spi + 2))
#define SPI_DELN	((volatile unsigned int *) (spi + 3))
#define SPI_LTOH	((volatile unsigned int *) (spi + 4))
#define SPI_DC		((volatile unsigned int *) (spi + 5))




#define INPUT  0
#define OUTPUT 1

#define LEDPIN 21

// Physical addresses
#define BCM2836_PERI_BASE        0x3F000000
#define GPIO_BASE               (BCM2836_PERI_BASE + 0x200000)
#define SYS_TIM_BASE		(BCM2836_PERI_BASE + 0x3000)
#define SPI_BASE		(BCM2836_PERI_BASE + 0x204000)
#define BLOCK_SIZE (4*1024)

// Pointers that will be memory mapped when pioInit() is called
volatile unsigned int *gpio; //pointer to base of gpio
volatile unsigned int *timer; //pointer to base of System timer
volatile unsigned int *spi;	 //pointer to base of the SPI

void pioInit() {
	int  mem_fd;
	void *reg_map;
	void *timer_map;
	void *spi_map;

	// /dev/mem is a psuedo-driver for accessing memory in the Linux filesystem
	if ((mem_fd = open("/dev/mem", O_RDWR|O_SYNC) ) < 0) {
	      printf("can't open /dev/mem \n");
	      exit(-1);
	}

	reg_map = mmap(
	  NULL,             //Address at which to start local mapping (null means don't-care)
      BLOCK_SIZE,       //Size of mapped memory block
      PROT_READ|PROT_WRITE,// Enable both reading and writing to the mapped memory
      MAP_SHARED,       // This program does not have exclusive access to this memory
      mem_fd,           // Map to /dev/mem
      GPIO_BASE);       // Offset to GPIO peripheral

	timer_map = mmap(
	  NULL,             //Address at which to start local mapping (null means don't-care)
      BLOCK_SIZE,       //Size of mapped memory block
      PROT_READ|PROT_WRITE,// Enable both reading and writing to the mapped memory
      MAP_SHARED,       // This program does not have exclusive access to this memory
      mem_fd,           // Map to /dev/mem
      SYS_TIM_BASE);       // Offset to Timers base

	spi_map = mmap(
	  NULL,             //Address at which to start local mapping (null means don't-care)
      BLOCK_SIZE,       //Size of mapped memory block
      PROT_READ|PROT_WRITE,// Enable both reading and writing to the mapped memory
      MAP_SHARED,       // This program does not have exclusive access to this memory
      mem_fd,           // Map to /dev/mem
      SPI_BASE);       // Offset to SPI base

	if (reg_map == MAP_FAILED) {
      printf("gpio mmap error %d\n", (int)reg_map);
      close(mem_fd);
      exit(-1);
    }

	if (timer_map == MAP_FAILED) {
      printf("timer mmap error %d\n", (int)timer_map);
      close(mem_fd);
      exit(-1);
    }

	if (spi_map == MAP_FAILED) {
      printf("spi mmap error %d\n", (int)spi_map);
      close(mem_fd);
      exit(-1);
    }

	gpio = (volatile unsigned *)reg_map;
	timer= (volatile unsigned *)timer_map;
	spi  = (volatile unsigned *)spi_map;
}

//Sets the Pin modes to input output or an alt
void pinMode(int pin, int mode){
	int reg=pin/10;		//Integer divide by 10 since 10 pins per reg
	int offset=(pin%10)*3;	//Remainder for that reg.  3 bits per pin
	
	//Set the 0's then set the 1's
	GPFSEL[reg]&=~((0b111&~mode)<<offset);	
	GPFSEL[reg]|=(0b111&mode) <<offset;
}


//Reads the value of a pin
int digitalRead(int pin){
	int reg=pin/32;		//Integer divide by 10 since 10 pins per reg
	int offset=pin%32;	//Offset is just 1 bit per pin
	
	return(GPLEV[reg] >> offset) & 0x1;
}

//Sets a pin to 0 or 1
void digitalWrite(int pin, int val){
	int reg=pin/32;		//Integer divide by 10 since 10 pins per reg
	int offset=pin%32;	//Offset is just 1 bit per pin

	if(val) GPSET[reg]=1<<offset;	//Set the bit to 1
	else    GPCLR[reg]=1<<offset;	//Set the clear register to change bit to 0
	
}	


//Delay function
void delay(int microSecs){
	*SYS_TIM_C2=*SYS_TIM_CLO+ microSecs;	//Set the C1 compare register to the value we want to wait for
	*SYS_TIM_CS|=0b100;			//Reset match flag M2 to 0 to ensure it will be triggered
	while(((*SYS_TIM_CS>>2) & 0x1)==0);	//Loop will go until the flag is set Shift 1 down
}

//initialize SPI0 port function
void spiInit(int freq, int csBits){
	//pinMode(7, ALT0);	//CE1 this is chip enable 1, we only need to enable one chip
	pinMode(8, ALT0);	//CE0
	//pinMode(8, OUTPUT);	//Manually set CE0 low when we need to
	pinMode(9, ALT0);	//MISO
	pinMode(10, ALT0);	//MOSI
	pinMode(11, ALT0);	//SCLK
	
				//Clock dvider value is what goes into the bottom 16 bits of SPI_CLK reg
				//Set the value of the Clock divider should be a 16 bit number
	*SPI_CLK = 250000000/freq;//System CLock is 250 MHz
	*SPI_CS |= csBits;	//Settings for the CS bits
	*SPI_CS |= 1 << 7;	//Set Transfer Active bit to turn SPI on
	digitalWrite(8,1);	//Something about the CE0/CS value should start high from the datasheet	
}

//function to send out 8-bits
char spiSendReceive(char data){
	*SPI_FIFO=data;						//Send data to the slave using FIFO
	while(((*SPI_CS>>16) & 0x1)==0);	//Wait until data transfer is complete (Done bit goes high)
	return(*SPI_FIFO);					//Return the recieved data
										//May want to consider writing theCE0 bit low then high yourself
}


//Need a function to accomodate the 10 bits from the ADC, so use 16 bits for two groups of 8 bits
short spiBigSendReceive(short data) {
    short rec;										//simpler to use a single short than to make multiple chars
    *SPI_CS |= 1 << 7;								//Set Transfer Active bit to turn SPI on
    rec = spiSendReceive((data & 0xFF00) >> 8); 	// send the upper half of the data first
    rec = (rec << 8) | spiSendReceive(data & 0x00FF);	//Send the second half of the data next
    unsigned int out = (unsigned int) rec;
    //printf("%u \n", out );
    *SPI_CS &= 0 << 7;								//Set Transfer Active bit to 0 to turn SPI off
    return rec;
}












