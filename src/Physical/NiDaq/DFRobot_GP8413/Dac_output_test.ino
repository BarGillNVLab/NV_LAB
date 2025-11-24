// #include <DFRobot_GP8XXX.h>
// /**************************
// ----------------------------
// | A0 |  A1 | A2 | i2c_addr |
// ----------------------------
// | 0  |  0  | 0  |   0x58   |
// ----------------------------
// | 1  |  0  | 0  |   0x59   |
// ----------------------------
// | 0  |  1  | 0  |   0x5A   |
// ----------------------------
// | 1  |  1  | 0  |   0x5B   |
// ----------------------------
// | 0  |  0  | 1  |   0x5C   |
// ----------------------------
// | 1  |  0  | 1  |   0x5D   |
// ----------------------------
// | 0  |  1  | 1  |   0x5E   |
// ----------------------------
// | 1  |  1  | 1  |   0x5F   |
// ----------------------------
// ***************************/
// DFRobot_GP8413 GP8413(/*deviceAddr=*/0x58);

// void setup() {

//   Serial.begin(115200);

//   while(GP8413.begin()!=0){
//     Serial.println("Communication with the device has encountered a failure. Please verify the integrity of the connection or ensure that the device address is properly configured.");
//     delay(1000);
//   }

//   /**
//    * @brief. Setting the range of DAC output.
//    * @param range. the range of DAC output.
//    * @n     eOutputRange5V(0-5V)
//    * @n     eOutputRange10V(0-10V)
//    */
//   GP8413.setDACOutRange(GP8413.eOutputRange10V);

//   /**
//    * @brief. Configuring different channel outputs for DAC values
//    * @param data. Data values corresponding to voltage values
//    * @n （0 - 32767）.This module is a 15-bit precision DAC module, hence the values ranging from 0 to 32767 correspond to voltages of 0-5V or 0-10V respectively. The specific voltage range depends on the selection of the module's voltage fluctuation switch.
//    * @param channel. Output channels
//    * @n  0:channel 0
//    * @n  1:channel 1
//    * @n  2:All channels
//    */
//   GP8413.setDACOutVoltage(0,0);//channel 0 output 6.548V
//   GP8413.setDACOutVoltage(0.0,1);//channel 1 output 0.979V

//   delay(10000);

//   //The set voltage is saved internally in the chip for power-off retention.
//   //GP8413.store();
// }

// void loop() {

// }

