#define PIN_NUM 1
int  data[PIN_NUM]; //data array
char dataID[PIN_NUM] = {'A'}; //data label
int  pinID[PIN_NUM]  = {A0}; //corresponding pins

long timer = millis(); //timer

void setup() {
  Serial.begin(115200); //serial
}

void loop() {
  if (millis() - timer > 10) { //Timer: send sensor data in every 10ms
    timer = millis();
    for (int i = 0 ; i < PIN_NUM ; i++) {
      data[i] = analogRead(pinID[i]); //get the analog reading
      sendDataToProcessing(dataID[i], data[i]);
    }
  }
}

void sendDataToProcessing(char symbol, int data) {
  Serial.print(symbol);  // symbol prefix of data type
  Serial.println(data);  // the integer data with a carriage return
}
