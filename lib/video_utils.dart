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
import 'package:fvp/fvp.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_detection_ssd_mobilenet/object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'native_opencv.dart';
import 'img_utils.dart';

class Video_utils extends StatefulWidget {
  const Video_utils({super.key});

  @override
  State<Video_utils> createState() => video_utils();
}

class video_utils extends State<Video_utils> {
  final imagePicker = ImagePicker();
  late VideoPlayerController controller;
  late File videoFile;
  String? videoPath;
  String? videoUrl;
  TextDetection? textDetection;
  ObjectDetection? objectDetection;
  Img_utils? img_utils;
  GlobalKey _containerKey = GlobalKey();
  Uint8List? image;
  late Directory tempDir;

String get tempPath => '${tempDir.path}/temp.jpg';

  @override
  void initState() {
    super.initState();
    objectDetection = ObjectDetection();
    textDetection=TextDetection();
    img_utils=Img_utils();
    controller = VideoPlayerController.networkUrl(Uri.parse(""));
    getTemporaryDirectory().then((dir) => tempDir = dir);
    controller.initialize().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  final _picker = ImagePicker();

  bool _isProcessed = false;
  bool _isWorking = false;

  

  Future<String?> pickAnImage() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return _picker
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          )
          .then((v) => v?.path);
    } else {
      return FilePicker.platform
          .pickFiles(
            type: FileType.image,
            allowMultiple: false,
          )
          .then((v) => v?.files.first.path);
    }
  }

  Future<void> takeImageAndProcess() async {
    
    final imagePath = await pickAnImage();

    if (imagePath == null) {
      return;
    }

    setState(() {
      _isWorking = true;
    });
    DateTime startTime;
    startTime = DateTime.now();
    // Creating a port for communication with isolate and arguments for entry point
    final port = ReceivePort();
    final args = ProcessImageArguments(imagePath, tempPath);

    // Spawning an isolate
    Isolate.spawn<ProcessImageArguments>(
      processImage,
      args,
      onError: port.sendPort,
      onExit: port.sendPort,
    );

    // Making a variable to store a subscription in
    late StreamSubscription sub;

    // Listening for messages on port
    sub = port.listen((_) async {
      // Cancel a subscription after message received called
      await sub.cancel();

      setState(() {
        _isProcessed = true;
        _isWorking = false;
      });
    });
     DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function took ${elapsedTime.inMilliseconds} milliseconds to execute.');
  }
   
  Future<void> selectVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() {
        videoFile = File(result.files.single.path!);
        videoPath = videoFile.path;
        videoUrl = null; // 清空视频URL
      });
      controller.dispose();
      setState(() {});
      controller = VideoPlayerController.file(videoFile);
      controller.initialize().then((_) {
        controller.play();
        setState(() {});
      });
    }
  }

  void playVideoFromUrl() {
    if (videoUrl != null) {
      setState(() {
        videoPath = null; // 清空视频路径
      });
      controller.dispose();
      controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl!));
      controller.initialize().then((_) {
        controller.play();
        setState(() {});
      });
    }
  }

  Widget buildVideoWidget() {
    if (controller.value.isInitialized) {
      return RepaintBoundary(
        key: _containerKey,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      return const Text('No video selected');
    }
  }

  Future<ui.Image> captureImageFromVideo(GlobalKey _containerKey) async {
    RenderRepaintBoundary boundary = _containerKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary;
    ui.Image capturedImage =
        await boundary.toImage(pixelRatio: ui.window.devicePixelRatio);
    return capturedImage;
  }

//ui.Image转Uint8List
  
  void PlayVideo() {
    controller.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: (image != null) ? Image.memory(image!) : Container(),
              ),
            ),
            Expanded(
              child: buildVideoWidget(),
            ),
            const SizedBox(),
            if (videoPath == null)
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      videoUrl = value.trim();
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Enter video URL',
                  ),
                ),
              ),
            if (videoPath != null)
              FloatingActionButton(
                onPressed: () {
                  // Wrap the play or pause in a call to `setState`. This ensures the
                  // correct icon is shown.
                  setState(() {
                    // If the video is playing, pause it.
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      // If the video is paused, play it.
                      controller.play();
                    }
                  });
                },
                // Display the correct icon depending on the state of the player.
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () async {
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  
                  Uint8List imageTmp = await img_utils!.uiImage2Uint8List(capturedImage);
                  ImageAnalysisResult result =
                      textDetection!.analyseImageUI(imageTmp);
                  image = img_utils!.drawResult(imageTmp, result);

                  setState(() {});
                },
                child: const Text('Analyze Text'),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: 
                  takeImageAndProcess,
                   
                  
                
                child: const Text('Analyze 1'),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed:() async{
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  
                  Uint8List imageTmp = await img_utils!.uiImage2Uint8List(capturedImage);
                  image=await img_utils!.convertToGrayscale(imageTmp);
                  
                },
                child: const Text('Show 2'),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed:() async{
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  
                  Uint8List imageTmp = await img_utils!.uiImage2Uint8List(capturedImage);
                  image=await img_utils!.cv_cvtColor(imageTmp);
                  
                },
                child: const Text('Show 1'),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () async {
                  ui.Image capturedImage =
                      await captureImageFromVideo(_containerKey);
                  img_utils!.saveImage(capturedImage);
                  Uint8List imageTmp = await img_utils!.uiImage2Uint8List(capturedImage);
                  ImageAnalysisResult result =
                      objectDetection!.analyseImageUI(imageTmp);
                  image = img_utils!.drawResult(imageTmp, result);

                  setState(() {});
                },
                child: const Text('Analyze'),
              ),
            ),
            const SizedBox(height: 16.0),
            if (videoPath == null && videoUrl == null)
              ElevatedButton(
                onPressed: selectVideo,
                child: const Expanded(
                  child: Text('Select Video Files'),
                ),
              ),
            if (videoPath == null && videoUrl != null)
              ElevatedButton(
                onPressed: playVideoFromUrl,
                child: const Expanded(
                  child: Text('Play Video'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
