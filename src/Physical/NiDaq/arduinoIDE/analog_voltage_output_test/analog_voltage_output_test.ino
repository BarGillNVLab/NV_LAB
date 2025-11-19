#include "DFRobot_GP8403.h"
DFRobot_GP8403 dac(&Wire,0x58);

void setup() {
  Serial.begin(115200);
  while(dac.begin()!=0){
    Serial.println("init error");
    delay(1000);
   }
  Serial.println("init succeed");
  dac.setDACOutRange(dac.eOutputRange10V);//Set the output range as 0-10V
  dac.setDACOutVoltage(1433,0);//The DAC value for 3.5V output in OUT0 channel
  delay(1000);
  dac.store(); //Save the set 3.5V voltage inside the chip
}

void loop(){

}