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
//[/] Clear the SVM

import ddf.minim.analysis.*;
import ddf.minim.*;

Minim minim;
AudioInput in;
FFT fft;

int dataNum = 500;
float sampleRate = 22050;
int bufferSize = 1024;
//FFT parameters
float[][] FFTHist;
final int LOW_THLD = 2; //low threshold of band-pass frequencies
final int HIGH_THLD = 102; //high threshold of band-pass frequencies

//SVM parameters
double C = 64; //Cost: The regularization parameter of SVM 
int d = HIGH_THLD-LOW_THLD; //number of feature
float[] modeArray = new float[dataNum]; //classification to show

//Global Variables for visualization
int col;
int leftedge;

void setup()
{
  size(700, 700, P3D);
  textFont(createFont("SanSerif", 12));

  minim = new Minim(this);

  // setup audio input
  in = minim.getLineIn(Minim.MONO, bufferSize, sampleRate);

  for (int i = 0; i < modeArray.length; i++) { //Initialize all modes as null
    modeArray[i] = -1;
  }

  fft = new FFT(in.bufferSize(), in.sampleRate());
  fft.window(FFT.NONE);

  d = HIGH_THLD - LOW_THLD; //for band-pass
  //d = fft.specSize()-LOW_THLD; //for high-pass
  FFTHist = new float[d][dataNum]; //history data to show
}

void draw()
{
  background(255);
  stroke(0);
  // grab the input samples
  float[] samples = in.mix.toArray();
  updateFFT(samples);
  drawSpectrogram();

  //use the data for classification
  double[] X = new double[d]; //Form a feature vector X;
  double[] dataToTrain = new double[d+1];
  double[] dataToTest = new double[d];
  if (mousePressed) {
    if (!svmTrained) { //if the SVM model is not trained
      int Y = type; //Form a label Y;
      for (int i = 0; i < d; i++) {
        X[i] = fft.getBand(i+LOW_THLD);
        dataToTrain[i] = X[i];
      }
      dataToTrain[d] = Y;
      trainData.add(new Data(dataToTrain)); //Add the dataToTrain to the trainingData collection.
      appendArrayTail(modeArray, Y); //append the label to  for visualization
      ++tCnt;
    } else { //if the SVM model is trained
      for (int i = 0; i < d; i++) {
        X[i] = fft.getBand(i+LOW_THLD);
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
        X[i] = fft.getBand(i+LOW_THLD);
        dataToTest[i] = X[i];
      }
      int predictedY = (int) svmPredict(dataToTest); //SVMPredict the label of the dataToTest
      appendArrayTail(modeArray, predictedY); //append the prediction results to modeArray for visualization
    }
  }
  
  if (!svmTrained && firstTrained) {
    //train a linear support vector classifier (SVC) 
    trainLinearSVC(d, C);
  }
  
  barGraph(modeArray, 0, 100, 0, 700, 500, 150);
}

void updateFFT(float[] _samples) {
  // apply windowing
  for (int i = 0; i < _samples.length/2; ++i) {
    // Calculate & apply window symmetrically around center point
    // Hanning (raised cosine) window
    float winval = (float)(0.5+0.5*Math.cos(Math.PI*(float)i/(float)(bufferSize/2)));
    if (i > bufferSize/2)  winval = 0;
    _samples[_samples.length/2 + i] *= winval;
    _samples[_samples.length/2 - i] *= winval;
  }
  // zero out first point (not touched by odd-length window)
  _samples[0] = 0;

  // perform a forward FFT on the samples in the input buffer
  fft.forward(_samples);
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

float[] appendArrayTail (float[] _array, float _val) {
  for (int i = 0; i < _array.length-1; i++) {  
    _array[i] = _array[i+1];
  }
  _array[_array.length-1] = _val;
  return _array;
}

void drawSpectrogram() {
  // fill in the new column of spectral values  
  for (int i = 0; i < HIGH_THLD-LOW_THLD; i++) {
    //FFTHist[i][col] = Math.round(Math.max(0, 2*20*Math.log10(1000*fft.getBand(i+NUM_DC))));
    FFTHist[i][col] = fft.getBand(i+LOW_THLD);
  }
  // next time will be the next column
  col = col + 1; 
  // wrap back to the first column when we get to the end
  if (col == dataNum) { 
    col = 0;
  }

  // Draw points.  
  // leftedge is the column in the ring-filled array that is drawn at the extreme left
  // start from there, and draw to the end of the array
  for (int i = 0; i < dataNum-leftedge; i++) {
    for (int j = 0; j < HIGH_THLD-LOW_THLD; j++) {
      stroke(255-map(FFTHist[j][i+leftedge], 0, 10, 0, 255));
      point(i, height-150-(j+LOW_THLD));
    }
  }
  // Draw the rest of the image as the beginning of the array (up to leftedge)
  for (int i = 0; i < leftedge; i++) {
    for (int j = 0; j < HIGH_THLD-LOW_THLD; j++) {
      stroke(255-map(FFTHist[j][i], 0, 10, 0, 255));
      point(i+dataNum-leftedge, height-150-(j+LOW_THLD));
    }
  }

  // Next time around, we move the left edge over by one, to have the whole thing
  // scroll left
  leftedge = leftedge + 1; 
  // Make sure it wraps around
  if (leftedge == dataNum) { 
    leftedge = 0;
  }

  // Add frequency axis labels
  int x = dataNum + 2; // to right of spectrogram display
  stroke(0);
  line(x, 0, x, height-150); // vertical line
  fill(0);
  // Make text appear centered relative to specified x,y point 
  textAlign(LEFT, CENTER);
  for (float freq = 500.0; freq < in.sampleRate()/2; freq += 500.0) {
    int y = height - fft.freqToIndex(freq)-150; // which bin holds this frequency?
    line(x, y, x+3, y); // add tick mark
    text(Math.round(freq)+" Hz", x+5, y); // add text label
  }
  line(0, height-150, width, height-150); // vertical line
}

void stop()
{
  // always close Minim audio classes when you finish with them
  in.close();
  minim.stop();

  super.stop();
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
  //if (key == ' ') {
  //  if (b_pause == true) b_pause = false;
  //  else b_pause = true;
  //}
}