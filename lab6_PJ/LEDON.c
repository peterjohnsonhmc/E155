//Turn On LED

#include "GPIO.h"
int main(void)
{
	
	// Turn on the LED
	pioInit();
	pinMode(LEDPIN, OUTPUT);
	digitalWrite(LEDPIN, 1);

	//HTML header
	printf("%s%c%c\n",
		"Content-Type:text/html;charset=iso-8859-1",13,10);
		
	// Redirect to LEDCON with no delay
	printf("<META HTTP-EQUIV=\"Refresh\" CONTENT=\"0;url=/ledcontrol.html\">");
	return 0;

}
