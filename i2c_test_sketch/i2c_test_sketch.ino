// I2C Bus Scanner for T-Beam 1W
// Upload this to scan the I2C bus and see what devices are present

#include <Arduino.h>
#include <Wire.h>

#define PIN_BOARD_SDA 8
#define PIN_BOARD_SCL 9

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("\n\nI2C Bus Scanner for T-Beam 1W");
  Serial.println("SDA: GPIO 8, SCL: GPIO 9");
  Serial.println("Scanning...\n");
  
  Wire.begin(PIN_BOARD_SDA, PIN_BOARD_SCL);
  
  byte error, address;
  int nDevices = 0;
  
  for(address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();
    
    if (error == 0) {
      Serial.print("I2C device found at address 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);
      Serial.print("  (");
      
      // Identify common devices
      if (address == 0x34) Serial.print("AXP2101/AXP192 PMU");
      else if (address == 0x3C) Serial.print("OLED Display");
      else if (address == 0x42) Serial.print("GPS");
      else if (address == 0x68) Serial.print("MPU6050/DS3231");
      else Serial.print("Unknown");
      
      Serial.println(")");
      nDevices++;
    }
    else if (error == 4) {
      Serial.print("Unknown error at address 0x");
      if (address < 16) Serial.print("0");
      Serial.println(address, HEX);
    }
  }
  
  Serial.print("\nScan complete. Found ");
  Serial.print(nDevices);
  Serial.println(" device(s).");
  
  if (nDevices == 0) {
    Serial.println("ERROR: No I2C devices found!");
  }
}

void loop() {
  delay(5000);
}
