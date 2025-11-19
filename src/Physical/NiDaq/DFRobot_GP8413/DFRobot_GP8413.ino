/*
 * Arduino Firmware for GP8413 DAC Control via MATLAB
 *
 * This sketch uses strstr() for robust command parsing.
 *
 * Connections (Arduino Due):
 * SDA (Pin 20) -> DAC SDA (C)
 * SCL (Pin 21) -> DAC SCL (D)
 * 5V           -> DAC VCC (+)  <-- !! USE THE 5V PIN !!
 * GND          -> DAC GND (-)
 */

#include <Wire.h>
#include "DFRobot_GP8XXX.h"

const float MAX_VOLTAGE = 10.0;
DFRobot_GP8413 dac;
char serialBuffer[64];

void setup() {
  Serial.begin(115200);
  Wire.begin();

  // We are SKIPPING the hardware check (dac.begin())
  // because of the 3.3V/5V logic level mismatch.
  dac.begin();

  // Set DAC range
  if (MAX_VOLTAGE == 10.0) {
    dac.setDACOutRange(dac.eOutputRange10V);
  } else {
    dac.setDACOutRange(dac.eOutputRange5V);
  }

  // Set channels to 0V
  for (int i = 0; i < 4; i++) {
    dac.setDACOutVoltage(0, i);
  }

  // Tell MATLAB we are ready
  Serial.print("READY\n");
}

void loop() {
  if (Serial.available() > 0) {
    int bytesRead = Serial.readBytesUntil('\n', serialBuffer, 63);
    serialBuffer[bytesRead] = '\0';

    // --- NEW ROBUST LOGIC ---
    // Use strstr() to see if the buffer *contains* "PING"
    // This is much safer than strcmp()

    if (strstr(serialBuffer, "PING") != NULL) {
      Serial.print("PONG\n");
    }
    // Check if the buffer *contains* "SET"
    else if (strstr(serialBuffer, "SET") != NULL) {
      int channel;
      float voltage;
      // sscanf is still the best way to parse this
      int itemsParsed = sscanf(serialBuffer, "SET %d %f", &channel, &voltage);

      if (itemsParsed == 2) {
        setVoltage(channel, voltage);
      }
    }
    // --- END NEW LOGIC ---
  }
}

void setVoltage(int channel, float voltage) {
  if (channel < 0 || channel > 3) { return; }
  if (voltage < 0.0) { voltage = 0.0; }
  if (voltage > MAX_VOLTAGE) { voltage = MAX_VOLTAGE; }
  uint16_t dacValue = (uint16_t)((voltage / MAX_VOLTAGE) * 32768.0);
  dac.setDACOutVoltage(dacValue, channel);
}