//*********************************************
// Time-Series Signal Processing
// e3_LinearSVM_Posture_Arduino_ThreeSensors
// Rong-Hao Liang: r.liang@tue.nl
//*********************************************
//Before use, please make sure your Arduino has 3 sensors connected
//to the analog input, and SerialString_ThreeSensors.ino was uploaded. 
//[Mouse Right Key] Collect Data
//[0-9] Change Label to 0-9
//[TAB] Increase Label Number
//[ENTER] Train the SVM
//[/] Clear the Data
//[SPACE] Pause Data Stream

import processing.serial.*;
Serial port; 

int sensorNum = 3; //number of sensors in use
int dataNum = 500; //number of data to show
int[] rawData = new int[sensorNum]; //raw data from serial port
float[] postProcessedDataArray = new float[sensorNum]; //data after postProcessing
float[][] sensorHist = new float[sensorNum][dataNum]; //history data to show
boolean b_pause = false; //flag to pause data collection

float[] modeArray = new float[dataNum]; //classification to show

//SVM parameters
double C = 64; //Cost: The regularization parameter of SVM
int d; //to be determined

//FFT parameters
final int NUM_DC = 2;

//FFT parameters
ezFFT[] fft = new ezFFT[sensorNum];
ezFFT fftMerged;
float[][] FFTHist; //history data to show


void setup() {
  size(700, 700);

  //Initiate the serial port
  for (int i = 0; i < Serial.list().length; i++) println("[", i, "]:", Serial.list()[i]);
  String portName = Serial.list()[Serial.list().length-1];//check the printed list
  port = new Serial(this, portName, 115200);
  port.bufferUntil('\n'); // arduino ends each data packet with a carriage return 
  port.clear();           // flush the Serial buffer

  for (int i = 0; i < modeArray.length; i++) { //Initialize all modes as null
    modeArray[i] = -1;
  }

  //ezFFT(number_of_samples, sample rate);
  for (int i = 0; i < sensorNum; i++) {
    fft[i] = new ezFFT(128, 500);
  }
  fftMerged = new ezFFT(128, 500);

  d = fftMerged.getSpecSize()-NUM_DC;
  for (int i = 0; i < sensorNum; i++) {
    FFTHist = new float[d][dataNum]; //history data to show
  }
}

void draw() {
  background(255);

  if (frameCount%4 == 0) { //update the FFT in 15fps
    for (int i = 0; i < sensorNum; i++) {
      fft[i].updateFFT(sensorHist[i]);
    }
    int SSize = fft[0].getSpecSize();
    float[] mergedSpectrum = new float[SSize];
    int max = 0;

    for (int i = 0; i < SSize; i++) {
      max = 0;
      for (int n = 0; n < fft.length; n++) {
        if (fft[n].getBand(i)>max) max = fft[n].getBand(i);
      }
      mergedSpectrum[i] = max;// += fft[n].getBand(i);
    }
    fftMerged.updateSpectrum(mergedSpectrum);

    for (int i = 0; i < d; i++) {
      appendArrayTail(FFTHist[i], mergedSpectrum[i+NUM_DC]);
    }

    //use the data for classification
    double[] X = new double[d]; //Form a feature vector X;
    double[] dataToTrain = new double[d+1];
    double[] dataToTest = new double[d];
    if (mousePressed) {
      if (!svmTrained) { //if the SVM model is not trained
        int Y = type; //Form a label Y;
        for (int i = 0; i < d; i++) {
          X[i] = mergedSpectrum[i+NUM_DC];
          dataToTrain[i] = X[i];
        }
        dataToTrain[d] = Y;
        trainData.add(new Data(dataToTrain)); //Add the dataToTrain to the trainingData collection.
        appendArrayTail(modeArray, Y); //append the label to  for visualization
        ++tCnt;
      } else { //if the SVM model is trained
        for (int i = 0; i < d; i++) {
          X[i] = mergedSpectrum[i+NUM_DC];
          dataToTest[i] = X[i];
        }
        int predictedY = (int) svmPredict(dataToTest); //SVMPredict the label of the dataToTest
        appendArrayTail(modeArray, predictedY); //append the prediction results to modeArray for visualization
      }
    } else {
      if (!svmTrained) { //if the SVM model is not trained
        appendArrayTail(modeArray, -1); //the class is null without mouse pressed.
      } else { //if the SVM model is trained
        for (int i = 0; i < d; i++) {
          X[i] = mergedSpectrum[i+NUM_DC];
          dataToTest[i] = X[i];
        }
        int predictedY = (int) svmPredict(dataToTest); //SVMPredict the label of the dataToTest
        appendArrayTail(modeArray, predictedY); //append the prediction results to modeArray for visualization
      }
    }
  }

  if (!svmTrained && firstTrained) {
    //train a linear support vector classifier (SVC) 
    trainLinearSVC(d, C);
  }

  //Draw the sensor data
  //lineGraph(float[] data, float lowerbound, float upperbound, float x, float y, float width, float height, int _index)
  for (int i = 0; i < sensorNum; i++) {
    lineGraph(sensorHist[i], 0, 500, 0, 500, 500, 200, i);
  }

  for (int i = 0; i < d; i++) {
    float v = FFTHist[i][FFTHist[i].length-1];
    if (v>50) lineGraph(FFTHist[i], 0, 1000, 0, i*10, 500, 10, 0, color(0, 255, 0));
    else    lineGraph(FFTHist[i], 0, 1000, 0, i*10, 500, 10, 0, color(0));
  }

  //Draw the modeArray
  //barGraph(float[] data, float lowerbound, float upperbound, float x, float y, float width, float height)
  barGraph(modeArray, 0, 100, 0, 700, 500, 200);

  float fftScale = 2;
  pushMatrix();
  translate(500, 0);
  fft[0].drawSpectrogram(fftScale, 1024);
  translate(0, 150);
  fft[1].drawSpectrogram(fftScale, 1024);
  translate(0, 150);
  fft[2].drawSpectrogram(fftScale, 1024);
  translate(0, 150);
  fftMerged.drawSpectrogram(fftScale, 1024);
  popMatrix();
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
      appendArrayTail(sensorHist[dataIndex], rawData[dataIndex]); //store the data to history (for visualization)
      return;
    }
  }
}

void keyPressed() {
  if (key == ENTER) {
    if (tCnt>0 || type>0) {
      if (!firstTrained) firstTrained = true;
      resetSVM();
    } else {
      println("Error: No Data");
    }
  }
  if (key >= '0' && key <= '9') {
    type = key - '0';
  }
  if (key == TAB) {
    if (tCnt>0) { 
      if (type<(colors.length-1))++type;
      tCnt = 0;
    }
  }
  if (key == '/') {
    firstTrained = false;
    resetSVM();
    clearSVM();
  }
  if (key == 'S' || key == 's') {
    if (model!=null) { 
      saveSVM_Model(sketchPath()+"/data/test.model", model);
      println("Model Saved");
    }
  }
  if (key == ' ') {
    if (b_pause == true) b_pause = false;
    else b_pause = true;
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

float[] appendArrayTail (float[] _array, float _val) {
  for (int i = 0; i < _array.length-1; i++) {  
    _array[i] = _array[i+1];
  }
  _array[_array.length-1] = _val;
  return _array;
}

//Draw a line graph to visualize the sensor stream

void lineGraph(float[] data, float _l, float _u, float _x, float _y, float _w, float _h, int _index, color c) {
  pushStyle();
  float delta = _w/data.length;
  beginShape();
  noFill();
  stroke(c);
  for (float i : data) {
    float h = map(i, _l, _u, 0, _h);
    vertex(_x, _y+h);
    _x = _x + delta;
  }
  endShape();
  popStyle();
}

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