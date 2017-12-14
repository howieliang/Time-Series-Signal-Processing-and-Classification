#define PIN_NUM 3
int  data[PIN_NUM];
char dataID[PIN_NUM] = {'A','B','C'};
int  pinID[PIN_NUM]  = {A0,A1,A2};

long timer = micros();

void setup() {
  Serial.begin(115200); 
}

void loop() {
  if ((micros() - timer) >= 2000) {
//    Serial.println(micros() - timer);
    timer = micros();
    for (int i = 0 ; i < PIN_NUM ; i++) {
      data[i] = analogRead(pinID[i]);
      sendDataToProcessing(dataID[i], data[i]);
    }
  }
}

void sendDataToProcessing(char symbol, int data) {
  Serial.print(symbol);                // symbol prefix tells Processing what type of data is coming
  Serial.println(data);                // the data to send culminating in a carriage return
}
