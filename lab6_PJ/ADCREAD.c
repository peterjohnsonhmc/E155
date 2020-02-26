// Read the value of the ADC

#include "GPIO.h"
int main(void)
{
	
	//Define Physical paremeters
	float vRef =3.3;	//V
	float maxVal=1023;
	
	float voltage;
	
	//Read ADC value
	short received;
			
	pioInit();		//Initialize the memory map
	spiInit(244000,0);	//Initiallize the SPI at 244 kHz with default settings
		
	pinMode(12, OUTPUT);
	//while(1){
		digitalWrite(12,0);

		//short initSeq = 0xd000;	//Transmit 1101 0000 then dont cares
		short initSeq = 0x6800;		//Transmit 0110 1000 then dont cares
		received = spiBigSendReceive(initSeq);

		if(received > 0){
			digitalWrite(12,1);
		}
		
		unsigned int tenBitRead = (unsigned int)received & 0x000003FF;
		//printf("%u\n", tenBitRead);
		float out = tenBitRead;
		voltage = out*vRef/maxVal;
		//printf("%f\n",voltage);
	//}
	//printf("%f", voltage);
	printf("%s%c%c\n",
		"Content-Type:text/html;charset=iso-8859-1",13,10);
	printf("<html>\n<head>\n<title>LED Control Page</title>\n<meta http-equiv=\"content-type\" content=\"text-html;charset=utf-8\">\n</head>\n<body>\n<form action=\"/cgi-bin/LEDON\" method=\"POST\">\n<input type=\"submit\" value=\"Turn LED On\">\n</form>\n<form action=\"/cgi-bin/LEDOFF\" method=\"POST\">\n<input type=\"submit\" value=\"Turn LED Off\">\n</form>\n<form action=\"/cgi-bin/ADCREAD\" method=\"POST\">\n<input type=\"submit\" value=\"Update ADC Reading\">\n</form>\n</body>\n</html>\n");
	printf("<html>\n The ADC Reads %f V \n <\html>", voltage);	//should insert this into the bottom of the webpage
	
	
	
	return 0;

}
