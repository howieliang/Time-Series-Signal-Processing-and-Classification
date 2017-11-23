//*********************************************
// LibSVM for Processing (v8)
// Rong-Hao Liang: r.liang@tue.nl
// The Example is based on the original LibSVM library
// Please place the SVM4P.pde in [the same directory] with your Processing sketch.
// Please also place the libsvm.jar in [the same directory]/code/.
// LibSVM original Website: http://www.csie.ntu.edu.tw/~cjlin/libsvm/
//*********************************************

import libsvm.*; // Import the LibSVM JAVA library

//SVM Global Parameters 
int kernel_Type = svm_parameter.RBF;
ArrayList<Data> trainData = new ArrayList<Data>(); //ArrayList for storing the labeled test data.
ArrayList<Data> testData = new ArrayList<Data>(); //ArrayList for storing the labeled test data.
int featureNum = 2; //[mouse_x, mouse_y]
int maxLabel = 0; //The maximum label among the dataset.
PGraphics svmBuffer = new PGraphics();
svm_parameter param;
svm_problem problem;
svm_model model;
double best_accuracy = 0.;
double outOfSample_accuracy = 0.;
int imageSize = 500;

//GUI Global Parameters 
int type = 0; //Current type of data
int tCnt = 0; //Data count of the current label
String trainingInfo = "";

boolean svmTrained = false;
boolean firstTrained = false;

long trainTimer = millis();
long testTimer = millis();

color colors[] = {
  color(155, 89, 182), color(63, 195, 128), color(214, 69, 65), 
  color(82, 179, 217), color(244, 208, 63), color(242, 121, 53), 
  color(0, 121, 53), color(128, 128, 0), color(52, 0, 128), 
  color(128, 52, 0), color(52, 128, 0), color(128, 52, 0)
};
double noise = 50;
double currC = 64;
double currGamma = 1.;

int nr_fold = 5;

PrintWriter output;

boolean bAndroid = false;

void trainLinearSVR(int _featureNum, double C) {
  featureNum = _featureNum;
  svmBuffer = new PGraphics(); 
  if (!bAndroid) {
    svm.svm_set_print_string_function(new libsvm.svm_print_interface() {
      @Override public void print(String s) {
      }
    }
    );
  }
  kernel_Type = svm_parameter.LINEAR;
  best_accuracy = runSVR_Linear(C); //Run Linear SVM and get the cross-validation accuracy;
  svmTrained = true;
}

void trainLinearSVC(int _featureNum, double _C) {
  trainLinearSVC(_featureNum, _C, true);
}

void trainLinearSVC(int _featureNum, double _C, boolean updateImage) {
  trainLinearSVC(_featureNum, _C, updateImage, nr_fold);
}

void trainLinearSVC(int _featureNum, double _C, boolean updateImage, int _nr_fold) {
  featureNum = _featureNum;
  currC = _C;
  nr_fold = _nr_fold;
  svmBuffer = new PGraphics(); 
  if (!bAndroid) {
    svm.svm_set_print_string_function(new libsvm.svm_print_interface() {
      @Override public void print(String s) {
      }
    }
    );
  }
  kernel_Type = svm_parameter.LINEAR;
  trainTimer = millis();
  best_accuracy = runSVM_Linear(_C, updateImage, nr_fold); //Run Linear SVM and get the cross-validation accuracy
  svmTrained = true;
}

void trainRBFSVC(int _featureNum, double _Gamma, double _C) {
  trainRBFSVC(_featureNum, _Gamma, _C, true);
}

void trainRBFSVC(int _featureNum, double _Gamma, double _C, boolean updateImage) {
  trainRBFSVC(_featureNum, _Gamma, _C, true, nr_fold);
}

void trainRBFSVC(int _featureNum, double _Gamma, double _C, boolean updateImage, int _nr_fold) {
  featureNum = _featureNum;
  currC = _C;
  currGamma = _Gamma;
  nr_fold = _nr_fold;
  svmBuffer = new PGraphics(); 
  if (!bAndroid) {
    svm.svm_set_print_string_function(new libsvm.svm_print_interface() {
      @Override public void print(String s) {
      }
    }
    );
  }
  kernel_Type = svm_parameter.RBF;
  trainTimer = millis();
  double cv_accuracy = runSVM_RBF(_Gamma, _C, updateImage, nr_fold);
  if (cv_accuracy > best_accuracy) { 
    best_accuracy = cv_accuracy;
    currC = _C;
    currGamma = _Gamma;
  }
  svmTrained = true;
}

void resetSVM() {
  svmTrained = false;
  best_accuracy = 0.;
  outOfSample_accuracy = 0.;
  maxLabel = type;
  tCnt=0;
}

svm_node[] svmNode(double[] d) {
  svm_node[] sn = new svm_node[d.length];
  for (int i = 0; i < d.length; i++) {
    sn[i] = initSVM_Node(i, d[i]);
  }
  return sn;
}

double svmPredict(double[] d) {
  svm_node[] x = svmNode(d);
  return svm.svm_predict(model, x);
}

double svmPredict(svm_node[] x) {
  return svm.svm_predict(model, x);
}

void clearSVM() {
  tCnt=0;
  type = 0;
  trainData.clear();
  testData.clear();
  svmBuffer.beginDraw(); 
  svmBuffer.clear();
  svmBuffer.endDraw();
  model = null;
  println("SVM cleared");
}




// Functions for Interfacing Processing to the LibSVM JAVA library

//****
//double[] initGridPrameter(int grid_size, float init, float step)
//: Initialize the parameters of grid searching.
//****
double[] initGridParameter(int grid_size, float init, float step) {
  double[] grid_param = new double[grid_size];
  for (int i = 0; i < grid_size; i++) {
    grid_param[i] = (double) pow(2, init+i*step);
  }
  return grid_param;
}

double runSVR_Linear(double C) {
  if (trainData.size() > 0) {
    println("SVM (Linear kernel)\nTraining...");
    param   = initSVMParam(3, svm_parameter.LINEAR, 1, C, 1);//initSVM_Linear(C);
    problem = initSVMProblem(trainData, featureNum);
    model     = svm.svm_train(problem, param);
    println(trainData.size(), svm.svm_get_nr_class(model));
    //int[][] confMatrix = n_fold_cross_validation(problem, param, 5, maxLabel+1);
    //printConfusionMatrix(confMatrix);
    //double accuracy = evaluateAccuracy(confMatrix);
    //println("Done.\nPrediction Accuracy = "+(accuracy *100.)+"%");
    //if(featureNum==2)svmBuffer = getModelImage(svmBuffer, model, (double)width, (double)height);

    //svmBuffer = getModelImage(svmBuffer, model, (double)width, (double)height);
    //double accuracy = evaluateAccuracy(dataList, model);
    //println("Done.\nPrediction Accuracy = "+(accuracy *100.)+"%");
    //printConfusionMatrix(n_fold_cross_validation(problem, param, 5, svm.svm_get_nr_class(model)));

    return 1;//accuracy;
  } else {
    println("Error: No Data");
    return -1.;
  }
}

//****
//double[] runSVM_Linear()
//: Run SVM classification using linear kernel.
//****

double runSVM_Linear(double _C) {
  return runSVM_Linear(_C, true);
}

double runSVM_Linear(double _C, boolean updateImage) {
  return runSVM_Linear(_C, updateImage, nr_fold);
}

double runSVM_Linear(double C, boolean updateImage, int _nr_fold) {
  if (trainData.size() > 0) {
    println("SVM (Linear kernel)\nTraining...");
    param   = initSVM_Linear(C);
    problem = initSVMProblem(trainData, featureNum);
    model     = svm.svm_train(problem, param);
    println(trainData.size(), svm.svm_get_nr_class(model));
    nr_fold = _nr_fold;
    int[][] confMatrix = n_fold_cross_validation(problem, param, nr_fold, maxLabel+1);
    printConfusionMatrix(confMatrix, true);
    double accuracy = evaluateAccuracy(confMatrix);
    println("Done.\nPrediction Accuracy = "+(accuracy *100.)+"%");
    if (accuracy>=best_accuracy && updateImage && featureNum==2)svmBuffer = getModelImage(svmBuffer, model, (double)width, (double)height);
    return accuracy;
  } else {
    println("Error: No Data");
    return -1.;
  }
}

//****
//double[] runSVM_RBF()
//: Run SVM classification using RBF kernel.
//****

double runSVM_RBF(double gamma, double cost) {
  return runSVM_RBF(gamma, cost, true);
}

double runSVM_RBF(double gamma, double cost, boolean updateImage) {
  return runSVM_RBF(gamma, cost, updateImage, nr_fold);
}

double runSVM_RBF(double gamma, double cost, boolean updateImage, int _nr_fold) {
  if (trainData.size() > 0) {
    println("SVM (RBF kernel): gamma=", gamma, "cost=", cost, "\nTraining...");
    param   = initSVM_RBF(gamma, cost);
    problem = initSVMProblem(trainData, featureNum);
    model     = svm.svm_train(problem, param);
    println(trainData.size(), svm.svm_get_nr_class(model));
    nr_fold = _nr_fold;
    int[][] confMatrix = n_fold_cross_validation(problem, param, nr_fold, maxLabel+1);
    //int[][] confMatrix = n_fold_cross_validation(problem, param, 5, svm.svm_get_nr_class(model));
    printConfusionMatrix(confMatrix, true);
    double accuracy = evaluateAccuracy(confMatrix);
    if (accuracy>=best_accuracy && updateImage && featureNum==2) svmBuffer = getModelImage(svmBuffer, model, (double)width, (double)height);
    println("Done.\nPrediction Accuracy = "+(accuracy *100.)+"%");
    //double accuracy = evaluateAccuracy(dataList, model);
    //if (accuracy>=best_accuracy && updateImage) svmBuffer = getModelImage(svmBuffer, model, (double)width, (double)height);
    //println("Done.\nPrediction Accuracy = "+(accuracy *100.)+"%");
    //printConfusionMatrix(n_fold_cross_validation(problem, param, 5, svm.svm_get_nr_class(model)));
    return accuracy;
  } else {
    println("Error: No Data");
    return -1.;
  }
}

//****
//int[][] n_fold_cross_validation(svm_problem problem, svm_parameter param, int n_fold, int type)
//: Run (n_fold)-Fold Cross Validation
//****

int[][] n_fold_cross_validation(svm_problem problem, svm_parameter param, int n_fold, int type) {
  int[][] confMatrix = new int[type][type];
  double[] target = new double[problem.l];
  svm.svm_cross_validation(problem, param, n_fold, target);

  for (int i = 0; i < target.length; i++) {
    int r = (int)problem.y[i];
    int c = (int)target[i];
    ++confMatrix[r][c];
  }
  return confMatrix;
}

//****
//printConfusionMatrix (int[][] confMatrix)
//: Print confusion matrix in console
//****

void printConfusionMatrix (int[][] confMatrix, boolean train) {
  int tested = 0;
  int correct = 0;
  int totalR = 0;
  int totalC = 0;
  double duration = (double)(millis()-trainTimer)/1000.;
  if (train) output = createWriter("train_confMatrix.txt");
  else output = createWriter("test_confMatrix.txt");
  if (kernel_Type == svm_parameter.RBF) {
    output.print("RBF-Kernel SVM");
    output.print("\r\nFeature #:"+featureNum);
    output.print("\r\nGamma:"+currGamma);
    output.print("\r\nC:"+currC);
  }
  if (kernel_Type == svm_parameter.LINEAR) {
    output.print("Linear-Kernel SVM");
    output.print("\r\nFeature #:"+featureNum);
    output.print("\r\nC:"+currC);
  }
  if (train) output.println("\r\n"+nr_fold+"-Fold Cross Validation");
  output.print("\r\nConfusion Matrix:");
  output.print("\r\n\t");
  for (int j = 0; j < confMatrix[0].length; j++) {
    output.print("["+j+"]\t");
  }
  output.print("Total\t");
  output.print("\r\n");
  for (int i = 0; i < confMatrix.length; i++) {
    output.print("["+i+"]\t");
    totalR = 0;
    for (int j = 0; j < confMatrix[0].length; j++) {
      tested += confMatrix[i][j];
      if (i==j) correct += confMatrix[i][j];
      output.print(confMatrix[i][j]+"\t");
      totalR+=confMatrix[i][j];
    }
    output.print(totalR+"\t");
    output.print("\r\n");
  }
  output.print("Total\t");
  for (int j = 0; j < confMatrix[0].length; j++) {
    totalC = 0;
    for (int i = 0; i < confMatrix.length; i++) {
      totalC+=confMatrix[i][j];
    }
    output.print(totalC+"\t");
  }
  output.print("\r\n");
  output.println("correct/tested = "+ correct + "/" + tested);
  output.println("overall accuracy = "+((double)correct/(double)tested * 100.) + " %");
  output.println("time elapsed: "+duration+" (s)");
  output.flush();
  output.close();
}

//****
//svm_parameter initSVM_RBF(double gamma, double C)
//: Get the parameters for RBF-kernel SVM
//****

svm_parameter initSVM_RBF(double gamma, double C) {
  svm_parameter param = initSVMParam(svm_parameter.C_SVC, svm_parameter.RBF, gamma, C, 3);
  return param;
}

//****
//svm_parameter initSVM_Linear(double gamma, double C) 
//: Get the parameters for Linear-kernel SVM
//****

svm_parameter initSVM_Linear(double C) {
  svm_parameter param = initSVMParam(svm_parameter.C_SVC, svm_parameter.LINEAR, 1, C, 1);
  return param;
}

//****
//svm_parameter initSVM_Linear(int _svmType, int _kernelType, double _gamma, double _C, int _degree)
//: Get the parameters for a customized SVM 
//****

svm_parameter initSVMParam(int _svmType, int _kernelType, double _gamma, double _C, int _degree) {
  svm_parameter param = new svm_parameter();

  param.svm_type = _svmType;
  //0 -- C-SVC    (multi-class classification)
  //1 -- nu-SVC    (multi-class classification)
  //2 -- one-class SVM  
  //3 -- epsilon-SVR  (regression)
  //4 -- nu-SVR    (regression)
  param.kernel_type = _kernelType;
  //0 -- linear: u'*v
  //1 -- polynomial: (gamma*u'*v + coef0)^degree
  //2 -- radial basis function: exp(-gamma*|u-v|^2)
  //3 -- sigmoid: tanh(gamma*u'*v + coef0)
  //4 -- precomputed kernel (kernel values in training_set_file)
  param.degree = (int)_degree;

  param.gamma = _gamma;
  param.C = _C;

  param.coef0 = 0;
  param.nu = 0.5;
  param.cache_size = 40;
  param.eps = 1e-3;
  param.p = 0.1;
  param.shrinking = 1;
  param.probability = 1;
  param.nr_weight = 0;
  param.weight_label = new int[0];
  param.weight = new double[0]; 
  return param;
}

//****
//svm_node initSVM_Node(int _index, double _value)
//: Get a node with its index and value set. 
//****

svm_node initSVM_Node(int _index, double _value) {
  svm_node n = new svm_node();
  n.index = _index;  
  n.value = _value;
  return n;
}

//****
//svm_problem initSVMProblem(ArrayList<Data> dataList, int _featureNum)
//: Initialize an SVM problem for the solver.
//****

svm_problem initSVMProblem(ArrayList<Data> dataList, int _featureNum) {
  svm_problem problem = new svm_problem();
  int node_amount = dataList.size();
  if (node_amount > 0) {
    int feature_amount = dataList.get(0).dof;
    problem.l = node_amount;
    problem.x = new svm_node[node_amount][feature_amount]; //features
    problem.y = new double[node_amount]; //label
    for (int i=0; i<node_amount; i++) {
      Data p = dataList.get(i);
      problem.y[i] = p.label;
      for (int j=0; j < feature_amount; j++) problem.x[i][j] = initSVM_Node(j, p.features[j]);
    }
  }
  return problem;
}

//****
//void saveSVM_Model(String path, svm_model model)
//: Save an SVM model to a path
//****

void saveSVM_Model(String path, svm_model model) {
  try {
    svm.svm_save_model(path, model);
  } 
  catch (IOException e) {
    System.err.println(e);
  }
}

//****
//svm_model loadSVM_Model(String path)
//: Load an SVM model from a path
//****

svm_model loadSVM_Model(String path) {
  svm_model m = new svm_model();
  try {
    m = svm.svm_load_model(path);
  } 
  catch (IOException e) {
    System.err.println(e);
  }
  return m;
}

//****
//double evaluateTestSet(ArrayList<Data> dataList, svm_model model)
//: Get the accuracy of the SVM based on the given dataset.
//****

double evaluateTestSet(ArrayList<Data> dataList) {
  int[][] confMatrix = new int[type][type];
  for (int r = 0; r < type; r++) {
    for (int c = 0; c < type; c++) {
      confMatrix[r][c] = 0;
    }
  }
  for (int i=0; i<dataList.size(); i++) {
    Data p = dataList.get(i);
    int dataLabel = p.label;
    svm_node[] x = new svm_node[p.features.length-1];
    for (int j=0; j < p.features.length-1; j++) x[j] = initSVM_Node(j, p.features[j]);
    int predictLabel = (int) svm.svm_predict(model, x);
    ++confMatrix[dataLabel][predictLabel];
  }
  printConfusionMatrix(confMatrix, false);
  double accuracy = evaluateAccuracy(confMatrix);
  return accuracy;
}

//****
//double evaluateAccuracy(int[][] confMatrix)
//: Get the accuracy of the SVM based on the confusionMatrix obtained by cross validation.
//****

double evaluateAccuracy (int[][] confMatrix) {
  int tested = 0;
  int correct = 0;
  //println("Confusion Matrix:");
  for (int i = 0; i < confMatrix.length; i++) {
    for (int j = 0; j < confMatrix[i].length; j++) {
      tested += confMatrix[i][j];
      if (i==j) correct += confMatrix[i][j];
      //print(confMatrix[i][j]+"\t");
    }
    //print("\n");
  }
  //println("correct/tested = "+ correct + "/" + tested);
  //println("correct = "+((double)correct/(double)tested * 100.) + " %");
  return (double)correct/(double)tested;
}

//****
//PGraphics getModelImage (PGraphics buffer, svm_model model, double W, double H)
//: Get the 2D image of a 2-DOF SVM
//****

PGraphics getModelImage (PGraphics buffer, svm_model model, double W, double H) {
  buffer = createGraphics((int)W, (int)H, JAVA2D);
  buffer.beginDraw();
  svm_node[] x = new svm_node[featureNum];
  for (int i=0; i< W; i++) {
    for (int j=0; j<H; j++) {
      x[0] = initSVM_Node(0, (double)i/W);
      x[1] = initSVM_Node(1, (double)j/H);
      double d = svm.svm_predict(model, x);
      buffer.stroke(colors[(int)d]);
      buffer.point(i, j);
    }
  }
  buffer.endDraw();
  return buffer;
}

//Class Data: Data structure for the data feeding into SVM

class Data {
  double[] features;
  int label;
  int dof;
  double mX = 0;
  double mY = 0;
  Data (double[] _features) {
    features = new double[_features.length];
    dof = _features.length-1;
    for (int i = 0; i < _features.length; i++) features[i] = _features[i];
    label = (int)_features[_features.length-1];
    if (dof==2) { 
      mX = features[0];
      mY = features[1];
    }
  }
  public double X()
  {
    return this.mX;
  }
  public double Y()
  {
    return this.mY;
  }
  public int Label()
  {
    return this.label;
  }
  public double[] Features() {
    return this.features;
  }
  public int DOF() {
    return this.dof;
  }
}

// Functions for loading files (SVM, Dataset) into the SVM

ArrayList<Data> loadData(String fileName, int feature_Num) {
  return loadDataScaled(fileName, feature_Num, 1.);
}

ArrayList<Data> loadDataScaled(String fileName, int feature_Num, double scale) {
  ArrayList<Data> d_list = new ArrayList<Data>();
  String lines[] = loadStrings(fileName);
  if (lines!=null) {
    for (int i = 0; i < lines.length; i++) {
      String[] l = splitTokens(lines[i]);
      double[] p = new double[feature_Num+1];
      if (l.length>0) {
        double label = Double.parseDouble(l[0]);
        p[feature_Num] = label;
        for (int j = 1; j < l.length; j++) {
          String[] v = splitTokens(l[j], ":");
          int index = Integer.parseInt(v[0]);
          double value = Double.parseDouble(v[1])/scale;
          p[index-1] = value;
        }
        if (label>maxLabel) maxLabel = (int)label;
      }
      d_list.add(new Data(p));
    }
    type = maxLabel+1;
  } else {
    println("No such file");
  }
  return d_list;
}

ArrayList<Data> loadCSV(String fileName, float scale) {
  ArrayList<Data> arrayList = new ArrayList<Data>();
  Table data = loadTable(fileName);
  ArrayList<Double> labelList = new ArrayList<Double>();
  int labelCol = 0;

  if (data != null) {
    featureNum = data.getColumnCount()-1;
    labelCol = featureNum;
    for (int i = 1; i < data.getRowCount(); i++) {
      TableRow row = data.getRow(i);
      double[] p = new double[data.getColumnCount()];
      for(int j = 0 ; j < featureNum ; j++){
        p[j] = row.getDouble(j)*scale;
      }
      double oldlabel = row.getDouble(labelCol); 
      double newLabel = -1;
      for (int j = 0; j < labelList.size(); j++) {
        if (oldlabel == labelList.get(j)) { 
          newLabel = j; 
          break;
        }
      }
      if (newLabel<0) {
        newLabel = labelList.size();
        labelList.add(oldlabel);
      }
      p[labelCol] = newLabel;    //label: Integer. No scaling is required to perform. 
      if (newLabel>maxLabel) {
        maxLabel=(int)newLabel;
      }
      arrayList.add(new Data(p));
    }
  }
  type = maxLabel+1;
  return arrayList;
}
//Functions for Visualizing SVM

void drawSVM() {
  pushStyle();
  ellipseMode(CENTER);
  noStroke();     
  image(svmBuffer, 0, 0);
  stroke(0);
  textSize(10);
  textAlign(CENTER);
  for (int i=0; i<trainData.size(); i++) {
    fill(colors[trainData.get(i).label]);
    ellipse((float)trainData.get(i).X()*width, (float)trainData.get(i).Y()*height, 12, 12);
    fill(0);
    text(trainData.get(i).label, (float)trainData.get(i).X()*width, (float)trainData.get(i).Y()*height+4);
  }
  stroke(0);
  popStyle();
}

void drawPrediction(double predictLabel, double[] d) {
  drawPrediction(predictLabel, svmNode(d));
}

void drawPrediction(double predictLabel, svm_node[] testNode) {
  pushStyle();
  ellipseMode(CENTER);
  int sampleX = (int)(testNode[0].value*(double)width);
  int sampleY = (int)(testNode[1].value*(double)height);
  fill(colors[round(max((float)predictLabel, 0))]);
  stroke(255);
  ellipse(sampleX, sampleY, 20, 20);
  fill(0);
  text(predictLabel+"", sampleX, sampleY+4);
  popStyle();
}

void drawPrediction(int predictLabel, svm_node[] testNode) {
  pushStyle();
  ellipseMode(CENTER);
  int sampleX = (int)(testNode[0].value*(double)width);
  int sampleY = (int)(testNode[1].value*(double)height);
  fill(colors[predictLabel]);
  stroke(255);
  ellipse(sampleX, sampleY, 20, 20);
  fill(0);
  text(predictLabel+"", sampleX, sampleY+4);
  popStyle();
}

void drawCursor() {
  pushStyle();
  ellipseMode(CENTER);
  stroke(0, max(255./(float)noise, 25.));
  strokeWeight(5);
  fill(colors[type], max(255./(float)noise, 25.));
  ellipse(mouseX, mouseY, (float)noise*2., (float)noise*2.);
  popStyle();
}