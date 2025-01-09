#include <Wire.h>
#include <BH1750FVI.h>
#include "MAX30105.h"
#include "heartRate.h"

// BH1750FVI settings
uint8_t ADDRESSPIN = 13;
BH1750FVI::eDeviceAddress_t DEVICEADDRESS = BH1750FVI::k_DevAddress_H;
BH1750FVI::eDeviceMode_t DEVICEMODE = BH1750FVI::k_DevModeContHighRes;

// Create LightSensor instance for BH1750FVI sensor
BH1750FVI LightSensor(ADDRESSPIN, DEVICEADDRESS, DEVICEMODE);

// MAX30102 settings
MAX30105 particleSensor;
const byte RATE_SIZE = 4; 
byte rates[RATE_SIZE]; // Array of heart rates
byte rateSpot = 0;
long lastBeat = 0; // Time at which the last beat occurred
float beatsPerMinute;
int beatAvg;

// Sound sensor settings
const int SOUND_SENSOR_PIN = 35; // ADC pin connected to the OUT pin of the sound sensor

// MQ-135 Gas Sensor settings
const int MQ135_PIN = 12; // ADC pin connected to the MQ-135 sensor

// I2C Pins (Define SCL and SDA)
#define SCL_PIN 22  // Define SCL pin 
#define SDA_PIN 21  // Define SDA pin 

void setup() {
  // Start Serial Monitor
  Serial.begin(115200);
  Serial.println("Initializing...");

  // Initialize Wire for both sensors (using custom SCL and SDA pins)
  Wire.begin(SDA_PIN, SCL_PIN);

  // Initialize BH1750FVI sensor
  LightSensor.begin(); // No need for 'if' check, as it returns void
  Serial.println("BH1750FVI Initialized.");

  // Initialize MAX30102 sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 was not found. Please check wiring/power.");
    while (1);
  }
  Serial.println("Place your index finger on the sensor with steady pressure.");
  particleSensor.setup(); // Configure sensor with default settings
  particleSensor.setPulseAmplitudeRed(0x0A); // Turn Red LED to low to indicate sensor is running
  particleSensor.setPulseAmplitudeGreen(0); // Turn off Green LED

  // Print setup messages for additional sensors
  Serial.println("Sound Sensor Initialized.");
  Serial.println("MQ-135 Gas Sensor Initialized.");
}

void loop() {
  // BH1750FVI Light Sensor Reading
  uint16_t lux = LightSensor.GetLightIntensity();
  Serial.print("Light Intensity: ");
  Serial.println(lux);

  // MAX30102 Heart Rate Sensor Reading
  long irValue = particleSensor.getIR();

  if (checkForBeat(irValue) == true) {
    // We sensed a beat!
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute; // Store this reading in the array
      rateSpot %= RATE_SIZE; // Wrap variable

      // Take average of readings
      beatAvg = 0;
      for (byte x = 0 ; x < RATE_SIZE ; x++)
        beatAvg += rates[x];
      beatAvg /= RATE_SIZE;
    }
  }

  // Print Heart Rate Sensor Data
  Serial.print("IR=");
  Serial.print(irValue);
  Serial.print(", BPM=");
  Serial.print(beatsPerMinute);
  Serial.print(", Avg BPM=");
  Serial.print(beatAvg);

  if (irValue < 50000)
    Serial.print(" No finger?");

  Serial.println();

  // Sound Sensor Reading
  int soundLevel = analogRead(SOUND_SENSOR_PIN);
  Serial.print("Sound Level: ");
  Serial.println(soundLevel);

  // MQ-135 Gas Sensor Reading
  int mq135Value = analogRead(MQ135_PIN);
  int airQuality = map(mq135Value, 0, 4095, 0, 1000); // Map to air quality index
  Serial.print("Raw MQ-135 Value: ");
  Serial.print(mq135Value);
  Serial.print(" | Air Quality Index: ");
  Serial.println(airQuality);
}