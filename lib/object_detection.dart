/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import 'package:dart_tensor/dart_tensor.dart';
import 'package:vector_math/vector_math.dart' as vm;

class ImageAnalysisResult {
  final String type;
  final List<int> classes;
  final List<String> classication;
  final List<double> scores;
  final List<List<double>> locations;
  final int numberOfDetections;
  final int originalHeight;
  final int originalWidth;
  final int scaledHeight;
  final int scaledWidth;
  
  
  
  ImageAnalysisResult({
    required this.type,
    required this.classes,
    required this.classication,
    required this.scores,
    required this.locations,
    required this.numberOfDetections,
    required this.originalHeight,
    required this.originalWidth,
    required this.scaledHeight,
    required this.scaledWidth
  });
}

class TextDetection {
  static const String _modelPath = 'assets/models/east_model_float16.tflite';
  

  Interpreter? _interpreter;
 // declaration of DartTensor class

DartTensor dt = DartTensor();
  TextDetection() {
    _loadModel();
    
    log('Done.');
  }

  Future<void> _loadModel() async {
    log('Loading interpreter options...(Text)');
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      interpreterOptions.addDelegate(GpuDelegate());
    }
    if(Platform.isLinux) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    log('Loading interpreter...');
    _interpreter =
        await Interpreter.fromAsset(_modelPath, options: interpreterOptions);
  }

 

  ImageAnalysisResult analyseImageUI(Uint8List imageData) {
    log('Analysing image...');
    // Reading image bytes from file

    // Decoding image
    final image = img.decodeImage(imageData);
    final int height=image!.height;
    final int width=image!.width;
    // Resizing image fpr model, [300, 300]
    final imageInput = img.copyResize(
      image!,
      width: 320,
      height: 320,
    );

    // Creating matrix representation, [300, 300, 3]
    final imageMatrix = List.generate(
  imageInput.height,
  (y) => List.generate(
    imageInput.width,
    (x) {
      final pixel = imageInput.getPixel(x, y);
      return [pixel.b.toDouble()-103.939, pixel.g.toDouble()-116.779, pixel.r.toDouble()-123.68];
    },
  ),
);

  

  
    final output = _runInference(imageMatrix);
    int lastNativeInferenceDuration =
        (_interpreter!.lastNativeInferenceDurationMicroSeconds / 1000).round();
    log('lastNativeInferenceDuration time: $lastNativeInferenceDuration ms');
    log('Processing outputs...');
    // Location
        // Scores
    final scores = output.first as List<List<List<List<double>>>>;
    log('Scores: $scores');


    // Location
    final locationsRaw = output.elementAt(1) as List<List<List<List<double>>>>;
    var numRows = scores[0][0].length;
var numCols = scores[0][0][0].length;


List<List<double>> locations=[[]];
var numberOfDetections=0;
// Loop over the number of rows
for (int y = 0; y < numRows; y++) {
    // Assuming locationsRaw is also a List of Lists that can be indexed similarly to your Python code
    List<double> scoresData = scores[0][0][y];
    List<double> xData0 = locationsRaw[0][0][y];
    List<double> xData1 = locationsRaw[0][1][y];
    List<double> xData2 = locationsRaw[0][2][y];
    List<double> xData3 = locationsRaw[0][3][y];
    List<double> anglesData = locationsRaw[0][4][y];
    
    // Loop over the number of columns
    for (int x = 0; x < numCols; x++) {
        // If our score does not have sufficient probability, ignore it
        if (scoresData[x] < 0.5) {
            continue;
        }
        locations.add([]);
        // Compute the offset factor as our resulting feature maps will
        // be 4x smaller than the input image
        double offsetX = x * 4.0;
        double offsetY = y * 4.0;
        
        // Extract the rotation angle for the prediction and then
        // compute the sin and cosine
        double angle = anglesData[x];
        double cos = math.cos(angle);
        double sin = math.sin(angle);
        
        double h = xData0[x] + xData2[x];
        double w = xData1[x] + xData3[x];
        var endX = (offsetX + (cos * xData1[x]) + (sin * xData2[x])) ;
          var endY = (offsetY - (sin * xData1[x]) + (cos * xData2[x])) ;
            var startX = (endX - w) ;
            var startY =(endY - h) ;
            locations[numberOfDetections].addAll([startY,startX,endY,endX]);
            
            numberOfDetections++;

    }
}
    
     return ImageAnalysisResult(
      
      type:'Text',
      classes: [],
      classication: [],
      scores:[],
      locations: locations,
      numberOfDetections: numberOfDetections,
      originalHeight:height,
      originalWidth:width,
      scaledHeight: 320,
      scaledWidth: 320
      
    );
  }
    
  

  List<List<Object>> _runInference(
    List<List<List<num>>> imageMatrix,
  ) {
    log('Running inference...');

    // Set input tensor [1, 320, 320, 3]
    final input = [imageMatrix];

    
    final output = {
      0: [List.generate(1, (_) =>List.generate(80, (_) =>List<double>.filled(80, 0)))],
      1: [List.generate(5, (_) =>List.generate(80, (_) =>List<double>.filled(80, 0)))],
      
    };

    _interpreter!.runForMultipleInputs([input], output);
    return output.values.toList();
  }
}




class ObjectDetection {
  static const String _modelPath = 'assets/models/ssd_mobilenet.tflite';
  static const String _labelPath = 'assets/models/labelmap.txt';

  Interpreter? _interpreter;
  List<String>? _labels;

  ObjectDetection() {
    _loadModel();
    _loadLabels();
    log('Done.');
  }

  Future<void> _loadModel() async {
    log('Loading interpreter options...(Object)');
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      interpreterOptions.addDelegate(GpuDelegate());
    }

    log('Loading interpreter...');
    _interpreter =
        await Interpreter.fromAsset(_modelPath, options: interpreterOptions);
  }

  Future<void> _loadLabels() async {
    log('Loading labels...');
    final labelsRaw = await rootBundle.loadString(_labelPath);
    _labels = labelsRaw.split('\n');
  }


  ImageAnalysisResult analyseImageUI(Uint8List imageData) {
    log('Analysing image...');
    // Reading image bytes from file

    // Decoding image
    final image = img.decodeImage(imageData);
    final int height=image!.height;
    final int width=image!.width;
    // Resizing image fpr model, [300, 300]
    final imageInput = img.copyResize(
      image!,
      width: 300,
      height: 300,
    );

    // Creating matrix representation, [300, 300, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );
  
    final output = _runInference(imageMatrix);
    int lastNativeInferenceDuration =
        (_interpreter!.lastNativeInferenceDurationMicroSeconds / 1000).round();
    log('lastNativeInferenceDuration time: $lastNativeInferenceDuration ms');
    log('Processing outputs...');
    // Location
    final locationsRaw = output.first.first as List<List<double>>;
    final locations = locationsRaw.map((list) {
      return list.map((value) => (value * 300).toDouble()).toList();
    }).toList();
    log('Locations: $locations');

    // Classes
    final classesRaw = output.elementAt(1).first as List<double>;
    final classes = classesRaw.map((value) => value.toInt()).toList();
    log('Classes: $classes');

    // Scores
    final scores = output.elementAt(2).first as List<double>;
    log('Scores: $scores');

    // Number of detections
    final numberOfDetectionsRaw = output.last.first as double;
    final numberOfDetections = numberOfDetectionsRaw.toInt();
    log('Number of detections: $numberOfDetections');

    log('Classifying detected objects...');
    final List<String> classication = [];
    for (var i = 0; i < numberOfDetections; i++) {
      classication.add(_labels![classes[i]]);
    }

    log('Outlining objects...');
    

    log('Done.');

    
     return ImageAnalysisResult(
      type:'Object',
      classes: classes,
      classication:classication,
      scores: scores,
      locations: locations,
      numberOfDetections: numberOfDetections,
      originalHeight:height,
      originalWidth:width,
      scaledHeight: 300,
      scaledWidth: 300
      
    );
  }
    
  

  Uint8List analyseImage(String imagePath) {
    log('Analysing image...');
    // Reading image bytes from file
    final imageData = File(imagePath).readAsBytesSync();

    // Decoding image
    final image = img.decodeImage(imageData);

    // Resizing image fpr model, [300, 300]
    final imageInput = img.copyResize(
      image!,
      width: 300,
      height: 300,
    );

    // Creating matrix representation, [300, 300, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );

    final output = _runInference(imageMatrix);

    log('Processing outputs...');
    // Location
    final locationsRaw = output.first.first as List<List<double>>;
    final locations = locationsRaw.map((list) {
      return list.map((value) => (value * 300).toInt()).toList();
    }).toList();
    log('Locations: $locations');

    // Classes
    final classesRaw = output.elementAt(1).first as List<double>;
    final classes = classesRaw.map((value) => value.toInt()).toList();
    log('Classes: $classes');

    // Scores
    final scores = output.elementAt(2).first as List<double>;
    log('Scores: $scores');

    // Number of detections
    final numberOfDetectionsRaw = output.last.first as double;
    final numberOfDetections = numberOfDetectionsRaw.toInt();
    log('Number of detections: $numberOfDetections');

    log('Classifying detected objects...');
    final List<String> classication = [];
    for (var i = 0; i < numberOfDetections; i++) {
      classication.add(_labels![classes[i]]);
    }

    log('Outlining objects...');
    for (var i = 0; i < numberOfDetections; i++) {
      if (scores[i] > 0.6) {
        // Rectangle drawing
        img.drawRect(
          imageInput,
          x1: locations[i][1],
          y1: locations[i][0],
          x2: locations[i][3],
          y2: locations[i][2],
          color: img.ColorRgb8(255, 0, 0),
          thickness: 3,
        );

        // Label drawing
        img.drawString(
          imageInput,
          '${classication[i]} ${scores[i]}',
          font: img.arial14,
          x: locations[i][1] + 1,
          y: locations[i][0] + 1,
          color: img.ColorRgb8(255, 0, 0),
        );
      }
    }

    log('Done.');

    return img.encodeJpg(imageInput);
  }

  List<List<Object>> _runInference(
    List<List<List<num>>> imageMatrix,
  ) {
    log('Running inference...');

    // Set input tensor [1, 300, 300, 3]
    final input = [imageMatrix];

    // Set output tensor
    // Locations: [1, 10, 4]
    // Classes: [1, 10],
    // Scores: [1, 10],
    // Number of detections: [1]
    final output = {
      0: [List<List<num>>.filled(10, List<num>.filled(4, 0))],
      1: [List<num>.filled(10, 0)],
      2: [List<num>.filled(10, 0)],
      3: [0.0],
    };

    _interpreter!.runForMultipleInputs([input], output);
    return output.values.toList();
  }
}

