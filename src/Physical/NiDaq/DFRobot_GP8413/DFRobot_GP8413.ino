#include <Wire.h>
#include "DFRobot_GP8XXX.h"

DFRobot_GP8413 dac;

const float MAX_VOLTAGE = 10.0;
char serialBuffer[64];

void setup() {
  Serial.begin(115200);
  Wire.begin();

  dac.begin();
  dac.setDACOutRange(dac.eOutputRange10V);

  for (int i=0;i<4;i++)
      dac.setDACOutVoltage(0, i);

  Serial.print("READY\n");
}

void loop() {
  if (!Serial.available()) return;

  int n = Serial.readBytesUntil('\n', serialBuffer, sizeof(serialBuffer)-1);
  serialBuffer[n] = '\0';

  // PING
  if (strncmp(serialBuffer, "PING", 4) == 0) {
    Serial.print("PONG\n");
    return;
  }

  // SET <dac#> <voltage>
  if (strncmp(serialBuffer, "SET", 3) == 0) {
    int ch; float v;
    if (sscanf(serialBuffer, "SET %d %f", &ch, &v) == 2)
        writeDAC(ch, v);
    return;
  }

  // DSET <pin> <0|1>
  if (strncmp(serialBuffer, "DSET", 4) == 0) {
    int pin, val;
    if (sscanf(serialBuffer, "DSET %d %d", &pin, &val) == 2)
        writeDig(pin, val);
    return;
  }

  // DGET <pin>
  if (strncmp(serialBuffer, "DGET", 4) == 0) {
    int pin;
    if (sscanf(serialBuffer, "DGET %d", &pin) == 1) {
      pinMode(pin, INPUT);
      int val = digitalRead(pin);
      Serial.print("DVAL "); Serial.print(pin);
      Serial.print(" "); Serial.print(val);
      Serial.print("\n");
    }
    return;
  }
}

/************ Helpers ************/

void writeDAC(int ch, float v) {
  if (ch < 0 || ch > 2) return;
  if (v < 0) v = 0;
  if (v > 5.0) v = 5.0;

  uint16_t raw = (uint16_t)((v / MAX_VOLTAGE) * 32767);
  dac.setDACOutVoltage(raw, ch);
}

void writeDig(int pin, int val) {
  if (pin < 0 || pin > 53) return;
  pinMode(pin, OUTPUT);
  digitalWrite(pin, val ? HIGH : LOW);
}
