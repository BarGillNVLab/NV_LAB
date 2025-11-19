/*
 * Simple Script: Output AO0 = 1.0 V and AO1 = 0.0 V
 * Hardware: Arduino Due + GP8413 DAC
 */

#include <Wire.h>
#include "DFRobot_GP8XXX.h"

const float MAX_VOLTAGE = 10.0;
DFRobot_GP8413 dac;

void setup() {
  Serial.begin(115200);
  Wire.begin();

  dac.begin();

  // Set DAC range to 10 V
  if (MAX_VOLTAGE == 10.0) {
    dac.setDACOutRange(dac.eOutputRange10V);
  } else {
    dac.setDACOutRange(dac.eOutputRange5V);
  }

  // --- SET OUTPUTS ---
  float v0 = 1.0;   // AO0 = 1 V
  float v1 = 0.0;   // AO1 = 0 V

  uint16_t dac0 = (uint16_t)((v0 / MAX_VOLTAGE) * 32768.0);
  uint16_t dac1 = (uint16_t)((v1 / MAX_VOLTAGE) * 32768.0);

  dac.setDACOutVoltage(dac0, 0);   // Channel 0 → 1 V
  dac.setDACOutVoltage(dac1, 1);   // Channel 1 → 0 V

  Serial.println("AO0 = 1.0V, AO1 = 0.0V set.");
}

void loop() {
  // nothing needed
}
