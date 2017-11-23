//*********************************************
// Time-Series Signal Processing and Classification
// e2_TimeSeriesData_Arduino_ThreeSensors
// Rong-Hao Liang: r.liang@tue.nl
//*********************************************
//Before use, please make sure your Arduino has 3 sensors connected
//to the analog input, and SerialString_ThreeSensors.ino was uploaded. 
//[SPACE] Pause Data Stream
//[TAB] Change Visualization

import processing.serial.*;
Serial port; 

int sensorNum = 3; //number of sensors in use
int dataNum = 500; //number of data to show
int[] rawData = new int[sensorNum]; //raw data from serial port
float[] postProcessedDataArray = new float[sensorNum]; //data after postProcessing
float[][] sensorHist = new float[sensorNum][dataNum]; //history data to show
boolean b_pause = false; //flag to pause data collection

int visualMode = 0;

void setup() {
  size(500, 500);

  //Initiate the serial port
  for (int i = 0; i < Serial.list().length; i++) println("[", i, "]:", Serial.list()[i]);
  String portName = Serial.list()[Serial.list().length-1];//check the printed list
  port = new Serial(this, portName, 115200);
  port.bufferUntil('\n'); // arduino ends each data packet with a carriage return 
  port.clear();           // flush the Serial buffer
}

void draw() {
  background(255);
  
  //Draw the sensor data
  //lineGraph(float[] data, float lowerbound, float upperbound, float x, float y, float width, float height, int _index)
  for (int i = 0; i < sensorNum; i++) {
    if(visualMode==0)lineGraph(sensorHist[i], 0, height, 0, 0, width, height, i);
    if(visualMode==1)lineGraph(sensorHist[i], 0, height, 0, i*height*0.3, width, height*0.3, i);
  }
  
}


void serialEvent(Serial port) {   
  String inData = port.readStringUntil('\n');  // read the serial string until seeing a carriage return
  int dataIndex = -1;
  if (!b_pause) {
    //assign data index based on the header
    if (inData.charAt(0) == 'A') {  
      dataIndex = 0;
    }
    if (inData.charAt(0) == 'B') {  
      dataIndex = 1;
    }
    if (inData.charAt(0) == 'C') {  
      dataIndex = 2;
    }
    //data processing
    if (dataIndex>=0) {
      rawData[dataIndex] = int(trim(inData.substring(1))); //store the value
      postProcessedDataArray[dataIndex] = map(constrain(rawData[dataIndex], 0, 1023), 0, 1023, 0, height); //scale the data (for visualization)
      appendArray(sensorHist[dataIndex], rawData[dataIndex]); //store the data to history (for visualization)
      return;
    }
  }
}

void keyPressed() {
  if (key == ' ') {
    if (b_pause == true) b_pause = false;
    else b_pause = true;
  }
  if (key == TAB) {
    visualMode = 1-visualMode;
  }
}

//Tool functions

//Append a value to a float[] array.
float[] appendArray (float[] _array, float _val) {
  float[] array = _array;
  float[] tempArray = new float[_array.length-1];
  arrayCopy(array, tempArray, tempArray.length);
  array[0] = _val;
  arrayCopy(tempArray, 0, array, 1, tempArray.length);
  return array;
}

//Draw a line graph to visualize the sensor stream
void lineGraph(float[] data, float _l, float _u, float _x, float _y, float _w, float _h, int _index) {
  color colors[] = {
    color(255, 0, 0), color(0, 255, 0), color(0, 0, 255), color(255, 255, 0), color(0, 255, 255), 
    color(255, 0, 255), color(0)
  };
  int index = min(max(_index, 0), colors.length);
  pushStyle();
  float delta = _w/data.length;
  beginShape();
  noFill();
  stroke(colors[index]);
  for (float i : data) {
    float h = map(i, _l, _u, 0, _h);
    vertex(_x, _y+h);
    _x = _x + delta;
  }
  endShape();
  popStyle();
}

//Draw a bar graph to visualize the modeArray
void barGraph(float[] data, float _l, float _u, float _x, float _y, float _w, float _h) {
  color colors[] = {
    color(155, 89, 182), color(63, 195, 128), color(214, 69, 65), color(82, 179, 217), color(244, 208, 63), 
    color(242, 121, 53), color(0, 121, 53), color(128, 128, 0), color(52, 0, 128), color(128, 52, 0)
  };
  pushStyle();
  noStroke();
  float delta = _w / data.length;
  for (int p = 0; p < data.length; p++) {
    float i = data[p];
    int cIndex = min((int) i, colors.length-1);
    if (i<0) fill(255, 100);
    else fill(colors[cIndex], 100);
    float h = map(_u, _l, _u, 0, _h);
    rect(_x, _y-h, delta, h);
    _x = _x + delta;
  }
  popStyle();
}