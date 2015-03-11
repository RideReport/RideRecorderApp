/* ==========================================================
Project : Read sensor inputs from ambient light sensor, magnetometer,
infrared detector and ultrasonic reader.
Author: Jono
Date: 02/10/2015
Description: This sketch will make the arduino read ALS on analog
             pin A3. Reads magnetometer on pins A0 and A1.
             IR readings are on A2 (read twice) and the ultrasonic signals
             aresent to A5. The readings will be sent to the
             computer via the USB cable using Serial communication.
             02/10 Updated Magnetometer MHMC5883
==============================================================
*/
#include <boards.h>
#include <Wire.h>
#include <SPI.h>
#include <RBL_nRF8001.h>
#include <RBL_services.h>

#define MAG_ADDR 0x1E // 0011110b, I2C 7bit address of HMC5883

int AlsPin = 3; 
int irPin = 2;
int ultPin = 1;
int PWPin = 0; //Ultrasonic Pulse Width

void setup() {
  Serial.begin(57600);
  Serial.println("BLE Arduino Slave");
  
 pinMode(ultPin, INPUT); //for the Ultrasonic sensor
 Wire.begin();
 //Start the Serial and I2C communications (with magnetometer)
 Wire.beginTransmission(MAG_ADDR);
 Wire.write(0x02);          //select mode register
 Wire.write(0x80);          //continuous measurement mode
 Wire.endTransmission();
 
  
  ble_begin();
}

static byte buf_len = 0;

void ble_write_string(byte *bytes, uint8_t len)
{
  if (buf_len + len > 20)
  {
    for (int j = 0; j < 15000; j++)
      ble_do_events();
    
    buf_len = 0;
  }
  
  for (int j = 0; j < len; j++)
  {
    ble_write(bytes[j]);
    buf_len++;
  }
    
  if (buf_len == 20)
  {
    for (int j = 0; j < 15000; j++)
      ble_do_events();
    
    buf_len = 0;
  }  
}

byte queryDone = false;

void loop()
{
  while(ble_available())
  {
    if (!ble_connected())
      return ;

    int ALSLevel;
    ALSLevel=analogRead(AlsPin); 

    int x,y,z; //triple axis for magnetometer
    Wire.beginTransmission(MAG_ADDR); //tel where to begin reading mag data
    Wire.write(0x03); //select register 3, X MSB register
    Wire.endTransmission();

    //Read data from each axis, 2 registers per axis
    Wire.requestFrom (MAG_ADDR, 6);
    if(6<=Wire.available()){
     x = Wire.read()<<8;
     x |= Wire.read();
     z = Wire.read()<<8;
     z |= Wire.read();
     y = Wire.read()<<8;
     y |= Wire.read();
     }

     int dis;
     int pirVal = digitalRead(irPin);
     if(pirVal == LOW){ //motion was detected
         dis = 1;
     }
     else{
         dis = 0; 
     }
     analogRead(irPin); //Infrared reading
     int ultDist = analogRead(ultPin);
     int ultPW = pulseIn(PWPin, HIGH, 10000); //Read Ultrasonic Pulse Width, microsecond delay
     
     byte buf[] = {'A', dis};         
     ble_write_string(buf, 2);
     
     byte buf2[] = {'U', ultDist};         
     ble_write_string(buf2, 2);
     
     byte buf3[] = {'1', x};         
     ble_write_string(buf3, 2);
     
     byte buf4[] = {'2', y};         
     ble_write_string(buf4, 2);
     
     byte buf5[] = {'3', z};         
     ble_write_string(buf5, 2);
    
    ble_do_events();
    buf_len = 0;
    
    //slow down the transmission for effective BT communication.
    delay(200);
    
    return;  
  }
    
  ble_do_events();
  buf_len = 0;
}
