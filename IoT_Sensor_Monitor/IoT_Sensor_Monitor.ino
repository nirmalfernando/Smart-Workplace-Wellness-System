#include <Wire.h>
#include <BH1750FVI.h>
#include <Firebase_ESP_Client.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// WiFi and Firebase settings
#define WIFI_SSID <YOUR_WIFI>
#define WIFI_PASSWORD <WIFI_PASSWORD>
#define API_KEY <API_KEY>
#define DATABASE_URL <FIREBASE_DATABASE_URL>

// LED Pin definitions
const int WHITE_LED_1 = 25;    // First white LED
const int WHITE_LED_2 = 26;    // Second white LED
const int WARM_LED_1 = 27;     // First warm white LED
const int WARM_LED_2 = 14;     // Second warm white LED

// BH1750FVI settings
uint8_t ADDRESSPIN = 13;
BH1750FVI::eDeviceAddress_t DEVICEADDRESS = BH1750FVI::k_DevAddress_H;
BH1750FVI::eDeviceMode_t DEVICEMODE = BH1750FVI::k_DevModeContHighRes;
BH1750FVI LightSensor(ADDRESSPIN, DEVICEADDRESS, DEVICEMODE);

// I2C Pins
#define SCL_PIN 22
#define SDA_PIN 21

// Sound Sensor settings
const int SOUND_SENSOR_PIN = 35;

// Gas Sensor (MQ-135) settings
const int MQ135_PIN = 12;

// Firebase objects
FirebaseAuth auth;
FirebaseConfig config;
FirebaseData fbdo;
FirebaseData fbdoLight;  

// NTP Client for time
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org");

// Timing variables
unsigned long lightSensorPrevMillis = 0;
unsigned long firebasePrevMillis = 0;
unsigned long soundSensorPrevMillis = 0;
unsigned long gasSensorPrevMillis = 0;
const unsigned long sensorInterval = 5000;

// Variables to store readings
uint16_t lux = 0;
int soundLevel = 0;
int airQuality = 0;
int heartRateAvg = 75;

// Light control variables
String currentMode = "off";
float currentIntensity = 0.5;
unsigned long lastLightCheck = 0;
const unsigned long CHECK_INTERVAL = 5000;

void setup() {
  Serial.begin(115200);
  Serial.println("Initializing...");

  // Initialize LED pins
  pinMode(WHITE_LED_1, OUTPUT);
  pinMode(WHITE_LED_2, OUTPUT);
  pinMode(WARM_LED_1, OUTPUT);
  pinMode(WARM_LED_2, OUTPUT);
  turnOffAllLEDs();

  // Initialize Wire
  Wire.begin(SDA_PIN, SCL_PIN);

  // Initialize BH1750FVI sensor
  LightSensor.begin();
  Serial.println("BH1750FVI Initialized.");

  Serial.println("Sound Sensor Initialized.");
  Serial.println("MQ-135 Gas Sensor Initialized.");

  // WiFi setup
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi!");

  // Initialize NTP Client
  timeClient.begin();
  timeClient.setTimeOffset(19800);  // UTC +5:30 for Sri Lanka

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

  // Set up listener for light control settings
  if (Firebase.RTDB.beginStream(&fbdoLight, "/lights")) {
    Serial.println("Light control stream began");
    Firebase.RTDB.setStreamCallback(&fbdoLight, streamCallback, streamTimeoutCallback);
  }
}

void loop() {
  unsigned long currentMillis = millis();
  timeClient.update();

  // Light sensor reading
  if (currentMillis - lightSensorPrevMillis >= sensorInterval) {
    lightSensorPrevMillis = currentMillis;
    lux = LightSensor.GetLightIntensity();
    Serial.print("Light: ");
    Serial.println(lux);
  }

  // Sound level reading
  if (currentMillis - soundSensorPrevMillis >= sensorInterval) {
    soundSensorPrevMillis = currentMillis;
    soundLevel = analogRead(SOUND_SENSOR_PIN);
    Serial.print("Sound Level: ");
    Serial.println(soundLevel);
  }

  // Gas sensor reading
  if (currentMillis - gasSensorPrevMillis >= sensorInterval) {
    gasSensorPrevMillis = currentMillis;
    int mq135Value = analogRead(MQ135_PIN);
    airQuality = map(mq135Value, 0, 4095, 0, 1000);
    Serial.print("Raw MQ-135 Value: ");
    Serial.print(mq135Value);
    Serial.print(" | Air Quality Index: ");
    Serial.println(airQuality);
  }

  // Firebase updates
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

  // Light control check
  if (currentMillis - lastLightCheck >= CHECK_INTERVAL) {
    lastLightCheck = currentMillis;
    if (currentMode == "auto") {
      handleAutoMode();
    }
  }
}

void streamCallback(FirebaseStream data) {
  if (data.dataPath() == "/") {
    FirebaseJson &json = data.jsonObject();
    FirebaseJsonData result;
    
    // Get mode
    if(json.get(result, "mode")) {
      currentMode = result.stringValue;
    }
    
    // Get intensity
    if(json.get(result, "intensity")) {
      currentIntensity = result.floatValue;
    }
    
    updateLighting();
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) {
    Serial.println("Stream timeout, resume streaming...");
  }
}

bool isDaytime() {
  int currentHour = timeClient.getHours();
  return (currentHour >= 6 && currentHour < 18);
}

void handleAutoMode() {
    // Check the light level
    if (lux < 300) {  
        bool isDayTime = isDaytime();
        
        // Select which LEDs are lighting up based on the time of the day
        int led1 = isDayTime ? WHITE_LED_1 : WARM_LED_1;
        int led2 = isDayTime ? WHITE_LED_2 : WARM_LED_2;
        
        // Apply user's intensity preference
        if (currentIntensity > 0) {
            digitalWrite(led1, HIGH);  // First LED activates when intensity > 0
        }
        
        if (currentIntensity >= 1) {
            digitalWrite(led2, HIGH);  // Second LED activates when intensity = 1
        }
    } else {
        turnOffAllLEDs();
    }
}

void updateLighting() {
  turnOffAllLEDs();
  
  if (currentMode == "off") {
    return;
  }
  
  if (currentMode == "auto") {
    handleAutoMode();
    return;
  }
  
  // Handle manual modes (white or warm)
  bool useWarmLights = (currentMode == "warm");
  int led1 = useWarmLights ? WARM_LED_1 : WHITE_LED_1;
  int led2 = useWarmLights ? WARM_LED_2 : WHITE_LED_2;
  
  if (currentIntensity > 0) {
    digitalWrite(led1, HIGH);  // First LED
  }
  
  if (currentIntensity >= 1) {
    digitalWrite(led2, HIGH);  // Second LED
  }
}

void turnOffAllLEDs() {
  digitalWrite(WHITE_LED_1, LOW);
  digitalWrite(WHITE_LED_2, LOW);
  digitalWrite(WARM_LED_1, LOW);
  digitalWrite(WARM_LED_2, LOW);
}
