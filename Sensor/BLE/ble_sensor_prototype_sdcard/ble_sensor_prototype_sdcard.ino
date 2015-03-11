

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
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <Time.h>


#define MAG_ADDR 0x1E // 0011110b, I2C 7bit address of HMC5883

int AlsPin = 3; 
int irPin = 2;
int ultPin = 1;
int PWPin = 0; //Ultrasonic Pulse Width

void setup() {
  Serial.begin(57600); 
     while (!Serial) {
    ; // wait for serial port to connect. Needed for Leonardo only
     }
  
 pinMode(ultPin, INPUT); //for the Ultrasonic sensor
 Wire.begin();
 //Start the Serial and I2C communications (with magnetometer)
 Wire.beginTransmission(MAG_ADDR);
 Wire.write(0x02);          //select mode register
 Wire.write(0x80);          //continuous measurement mode
 Wire.endTransmission();
 
  Serial.print("Initializing SD card...");

  pinMode(SCK, OUTPUT);
  pinMode(MOSI, OUTPUT);
  pinMode(MISO, INPUT);
  // see if the card is present and can be initialized:
  if (!SD.begin(10)) {
    Serial.println("Card failed, or not present");
    // don't do anything more:
    return;
  }
  Serial.println("card initialized.");
  
}



void loop()
{

    String dateString = getTimeStamp();

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
     
  // open the file. note that only one file can be open at a time,
  // so you have to close this one before opening another.
  File dataFile = SD.open("datalog.txt", FILE_WRITE);

  // if the file is available, write to it:
  if (dataFile) {
  dataFile.print(dateString);    
  dataFile.print("\t");      
  dataFile.print(dis);
  dataFile.print(",");
  dataFile.print(ultDist);
  dataFile.print(",");
  dataFile.print(x);
  dataFile.print(",");
  dataFile.print(y);
  dataFile.print(",");
  dataFile.println(z);
   
    dataFile.close();
  }
      // print to the serial port too:
  Serial.print(dateString);    
  Serial.print("\t");      
  Serial.print(dis);
  Serial.print(",");
  Serial.print(ultDist);
  Serial.print(",");
  Serial.print(x);
  Serial.print(",");
  Serial.print(y);
  Serial.print(",");
  Serial.println(z);

    
    //slow down the transmission for effective BT communication.
    delay(50);
    
    return;  

}

// Gets the date and time from the ds1307 and return
// result in a format a spreadsheet can parse: 06/10/11 15:10:00
String getTimeStamp()
{ 
  String dataString = "";
  
  dataString += hour();
  dataString += String(":");
  dataString += minute();
  dataString += String(":");
  dataString += second();

  return dataString;
}

