import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:isolate';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_detection_ssd_mobilenet/object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'native_opencv.dart';

class Img_utils{
 final _picker = ImagePicker();

  Img_utils() {
    
    
    dev.log('Done.');
  }



//原生灰度函数
Future<Uint8List> convertToGrayscale(Uint8List imageData) async {
    DateTime startTime;
    startTime = DateTime.now();
  // 解码图像获取图像对象
  ui.Image originalImage = await decodeImageFromList(imageData);

  // 获取图像宽度和高度
  int width = originalImage.width;
  int height = originalImage.height;

  // 获取图像像素字节数据
  ByteData? byteData = await originalImage.toByteData();
 if (byteData == null) {
    throw Exception("Failed to get byte data from image.");
  }
  // 灰度化图像数据
  Uint8List grayscaleImageData = Uint8List(width * height);

  // 根据灰度化公式计算每个像素的灰度值
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      // 计算像素在字节数据中的偏移量
      int pixelOffset = (y * width + x) * 4;

      // 获取像素颜色值
      int r = byteData.getUint8(pixelOffset);
      int g = byteData.getUint8(pixelOffset + 1);
      int b = byteData.getUint8(pixelOffset + 2);

      // 使用加权平均法计算灰度值
      int grayscaleValue = (0.299 * r + 0.587 * g + 0.114 * b).round();

      // 将灰度值写入灰度化图像数据中的相应位置
      grayscaleImageData[y * width + x] = grayscaleValue;
    }
  }
img.Image image = img.Image(width: width,height: height);
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int gray = grayscaleImageData[y * width + x];
      // 设置像素颜色为灰度值（灰度值被用作红色、绿色和蓝色分量）
      image.setPixelRgb(x, y, gray, gray, gray);
    }
  }
  
  // 将Image对象编码成PNG格式字节数据
  Uint8List pngBytes = Uint8List.fromList(img.encodePng(image));


  

DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function took ${elapsedTime.inMilliseconds} milliseconds to execute.');
 return pngBytes;
}

//调用opencv实现的灰度函数
   Future<Uint8List?> cv_cvtColor(Uint8List imageData) async {
    
  
  
  DateTime startTime;
    startTime = DateTime.now();
  

  
  
  // Creating a port for communication with isolate and arguments for entry point
  final port = ReceivePort();
  final args = ProcessImageArgumentsB(imageData,port.sendPort);

  // Completer for managing the future response
  final completer = Completer<Uint8List?>();

  // Spawning an isolate
  // 启动一个isolate，并传入正确的send port参数
Isolate.spawn(
  cvtColor,
  args, // 包含SendPort的新消息对象
  onError: port.sendPort,
  onExit: port.sendPort,
);

  // Making a variable to store a subscription in
  late StreamSubscription sub;

  // Listening for messages on port
  sub = port.listen((dynamic data) async {
    if (data is Uint8List) {
      // Handle the received Uint8List here
      await sub.cancel();

      

      completer.complete(data);
    }
  });

  Uint8List? processedImageData = await completer.future;
  dev.log("Running isolate");
  // Only save image if processedImageData is not null
  if (processedImageData != null) {
    await saveImageToFile(processedImageData, '/home/pc/images/screenshot.png');
  }
DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function took ${elapsedTime.inMilliseconds} milliseconds to execute.');
  return processedImageData;
}
//ui.Image转Uint8List
  Future<Uint8List> uiImage2Uint8List(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asInt8List();
    final bytesBuffer = bytes.buffer;
    return Uint8List.view(bytesBuffer);
  }
 img.Image drawQuadrilateral(img.Image image,List<List<int>> coordinate)
 {
    // 连接四边形的四个顶点
    for (int i = 0; i < coordinate.length; i++) {
      //x1=coordinate[i][1];
      //y1=coordinate[i][0];
      //x2=coordinate[i][3];
      //y2=coordinate[i][2];
      img.drawLine(image,
            x1: coordinate[i][1],
            y1: coordinate[i][0],
            x2: coordinate[i][3],
            y2: coordinate[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,);
    }
    
  
  return image;

 }
  Uint8List drawResult(Uint8List imageData, ImageAnalysisResult result) {
    final imageTmp = img.decodeImage(imageData);
    final imageForDrawing = imageTmp!;
    String type = result.type;
    List<int> classes = result.classes;
    List<List<double>> locations = result.locations;
    List<String> classication = result.classication;
    List<double> scores = result.scores;
    int numberOfDetections = result.numberOfDetections;
    int originalHeight = result.originalHeight;
    int originalWidth = result.originalWidth;
    int scaledHeight = result.scaledHeight;
    int scaledWidth = result.scaledWidth;
    
      
    for (int i = 0; i < numberOfDetections; i++) {
      for (int j = 0; j < locations[i].length; j++) {
        if (j == 1 || j == 3) {
          // 转换x轴坐标
          locations[i][j] =
              locations[i][j] * originalWidth / scaledWidth;
        } else if (i == 0 && j == 2) {
          // 执行第二行第二列元素的操作
          locations[i][j] =
              locations[i][j] * originalHeight / scaledHeight;
        } else {
          // 其他元素保持不变
        }
      }
    }
    List<List<int>> finalLocations = locations.map((row) {
      return row.map((element) {
        return element.toInt();
      }).toList();
    }).toList();
    if (type == 'Object') {
      for (var i = 0; i < numberOfDetections; i++) {
        if (scores[i] > 0.6) {
          // Rectangle drawing
          img.drawRect(
            imageForDrawing,
            x1: finalLocations[i][1],
            y1: finalLocations[i][0],
            x2: finalLocations[i][3],
            y2: finalLocations[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,
          );

          // Label drawing
          img.drawString(
            imageForDrawing,
            '${classication[i]} ${scores[i]}',
            font: img.arial14,
            x: finalLocations[i][1] + 1,
            y: finalLocations[i][0] + 1,
            color: img.ColorRgb8(255, 0, 0),
          );
        }
      }
    }
    else if(type=='Text')//文字类score在数据后处理时已经根据阈值筛选了，所以这里不需要按照score（置信度）来筛选画图
    {
        for (var i = 0; i < numberOfDetections; i++) {
        
          // Rectangle drawing
          img.drawRect(
            imageForDrawing,
            x1: finalLocations[i][1],
            y1: finalLocations[i][0],
            x2: finalLocations[i][3],
            y2: finalLocations[i][2],
            color: img.ColorRgb8(255, 0, 0),
            thickness: 3,
          );

          
        
      }
    }

    return img.encodePng(imageForDrawing);
  }
Future<Uint8List> loadImageAsUint8List(String imagePath) async {
 DateTime startTime;
    startTime = DateTime.now();
  File imageFile = File(imagePath);

  if (!imageFile.existsSync()) {
    throw Exception('指定路径的图片文件不存在');
  }

  List<int> imageBytes = await imageFile.readAsBytes();
  Uint8List uint8List = Uint8List.fromList(imageBytes);
 DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function load took ${elapsedTime.inMilliseconds} milliseconds to execute.');
  return uint8List;
}
//暂时没用，保存截图到某个路径
  Future<void> saveImage(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asInt8List().cast<int>();

    // 指定保存目录的路径
    final directory = Directory('/home/pc/images'); // 将路径替换为想要保存到的目录路径

    if (await directory.exists()) {
      // 生成一个唯一的文件名
      final fileName = 'video_snapshot.png';

      // 创建文件并写入截图数据
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      print('Screenshot saved at: ${file.path}');
    } else {
      print('目录不存在：${directory.path}');
    }
  }
Future<void> saveImageToFile(Uint8List imageData, String filePath) async {
  // 创建文件
  final file = File(filePath);
  
  // 将图像数据写入文件
  await file.writeAsBytes(imageData);
}
}