#include <Wire.h>
#include <BH1750FVI.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// WiFi and Firebase settings
#define WIFI_SSID <YOUR_WIFI>
#define WIFI_PASSWORD <WIFI_PASSWORD>
#define API_KEY <API_KEY>
#define DATABASE_URL <DATABASE_URL>

FirebaseAuth auth;
FirebaseConfig config;
FirebaseData fbdo;

// BH1750FVI settings
uint8_t ADDRESSPIN = 13;
BH1750FVI::eDeviceAddress_t DEVICEADDRESS = BH1750FVI::k_DevAddress_H;
BH1750FVI::eDeviceMode_t DEVICEMODE = BH1750FVI::k_DevModeContHighRes;
BH1750FVI LightSensor(ADDRESSPIN, DEVICEADDRESS, DEVICEMODE);

// MAX30102 settings
MAX30105 particleSensor;
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int heartRateAvg;

// I2C Pins
#define SCL_PIN 22
#define SDA_PIN 21

// Sound Sensor settings
const int SOUND_SENSOR_PIN = 35; // ADC pin for the sound sensor

// Gas Sensor (MQ-135) settings
const int MQ135_PIN = 12; // ADC pin for the MQ-135 sensor

// Timing variables
unsigned long lightSensorPrevMillis = 0;
unsigned long heartRatePrevMillis = 0;
unsigned long firebasePrevMillis = 0;
unsigned long soundSensorPrevMillis = 0;
unsigned long gasSensorPrevMillis = 0;
const unsigned long sensorInterval = 5000; // 5 seconds

// Variables to store readings
uint16_t lux = 0;
int soundLevel = 0;
int airQuality = 0;

void setup() {
  // Initialize Serial Monitor
  Serial.begin(115200);
  Serial.println("Initializing...");

  // Initialize Wire
  Wire.begin(SDA_PIN, SCL_PIN);

  // Initialize BH1750FVI sensor
  LightSensor.begin();
  Serial.println("BH1750FVI Initialized.");

  // Initialize MAX30102 sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found. Check wiring.");
    while (1);
  }
  Serial.println("Place your finger on the sensor.");
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);

  Serial.println("Sound Sensor Initialized.");
  Serial.println("MQ-135 Gas Sensor Initialized.");

  // WiFi setup
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi!");

  // Firebase setup
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase signUp OK");
  } else {
    Serial.printf("Firebase signUp Error: %s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  unsigned long currentMillis = millis();

  // Read and process light sensor data every 5 seconds
  if (currentMillis - lightSensorPrevMillis >= sensorInterval) {
    lightSensorPrevMillis = currentMillis;
    lux = LightSensor.GetLightIntensity();
    Serial.print("Light: ");
    Serial.println(lux);
  }

  // Read and process heart rate sensor data
  long irValue = particleSensor.getIR();
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);
    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;

      heartRateAvg = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        heartRateAvg += rates[x];
      }
      heartRateAvg /= RATE_SIZE;
    }
  }

  // Print Heart Rate Sensor Data
  Serial.print("IR=");
  Serial.print(irValue);
  Serial.print(", BPM=");
  Serial.print(beatsPerMinute);
  Serial.print(", Avg BPM=");
  Serial.println(heartRateAvg);

  // Read sound level data every 5 seconds
  if (currentMillis - soundSensorPrevMillis >= sensorInterval) {
    soundSensorPrevMillis = currentMillis;
    soundLevel = analogRead(SOUND_SENSOR_PIN);
    Serial.print("Sound Level: ");
    Serial.println(soundLevel);
  }

  // Read gas sensor data every 5 seconds
  if (currentMillis - gasSensorPrevMillis >= sensorInterval) {
    gasSensorPrevMillis = currentMillis;
    int mq135Value = analogRead(MQ135_PIN);
    airQuality = map(mq135Value, 0, 4095, 0, 1000); // Map to air quality index
    Serial.print("Raw MQ-135 Value: ");
    Serial.print(mq135Value);
    Serial.print(" | Air Quality Index: ");
    Serial.println(airQuality);
  }

  // Update Firebase every 5 seconds
  if (currentMillis - firebasePrevMillis >= sensorInterval) {
    firebasePrevMillis = currentMillis;

    if (Firebase.ready()) {
      // Upload light intensity
      if (Firebase.RTDB.setInt(&fbdo, "/sensors/light", lux)) {
        Serial.println("Light data uploaded.");
      } else {
        Serial.printf("Light data upload failed: %s\n", fbdo.errorReason().c_str());
      }

      // Upload heart rate
      if (Firebase.RTDB.setInt(&fbdo, "/sensors/heartRate", heartRateAvg)) {
        Serial.println("Heart rate data uploaded.");
      } else {
        Serial.printf("Heart rate upload failed: %s\n", fbdo.errorReason().c_str());
      }

      // Upload sound level
      if (Firebase.RTDB.setInt(&fbdo, "/sensors/soundLevel", soundLevel)) {
        Serial.println("Sound level data uploaded.");
      } else {
        Serial.printf("Sound level upload failed: %s\n", fbdo.errorReason().c_str());
      }

      // Upload gas sensor data
      if (Firebase.RTDB.setInt(&fbdo, "/sensors/airQuality", airQuality)) {
        Serial.println("Gas sensor data uploaded.");
      } else {
        Serial.printf("Gas sensor data upload failed: %s\n", fbdo.errorReason().c_str());
      }
    }
  }
}