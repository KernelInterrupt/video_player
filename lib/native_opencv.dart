import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:developer' as dev;
// C function signatures
typedef _CVersionFunc = ffi.Pointer<Utf8> Function();
typedef _CProcessImageFunc = ffi.Void Function(
  ffi.Pointer<Utf8>,
  ffi.Pointer<Utf8>,
);

// Dart function signatures
typedef _VersionFunc = ffi.Pointer<Utf8> Function();
typedef _ProcessImageFunc = void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef _cvtColorFunc = ffi.Pointer<Utf8> Function();


// Getting a library that holds needed symbols
ffi.DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libnative_opencv.so');
  } else if (Platform.isWindows) {
    return ffi.DynamicLibrary.open("native_opencv_windows_plugin.dll");
  }

  return ffi.DynamicLibrary.process();
}

ffi.DynamicLibrary _lib = _openDynamicLibrary();

// Looking for the functions
final _VersionFunc _version =
    _lib.lookup<ffi.NativeFunction<_CVersionFunc>>('version').asFunction();
final _ProcessImageFunc _processImage = _lib
    .lookup<ffi.NativeFunction<_CProcessImageFunc>>('process_image')
    .asFunction();
final int Function(int inBytesCount,ffi.Pointer<ffi.Uint8> bytes, ffi.Pointer<ffi.Pointer<ffi.Uint8>> encodedOutput) 
_cvtColor = _lib
        .lookup<ffi.NativeFunction<ffi.Int32 Function(ffi.Int32 inBytesCount, 
ffi.Pointer<ffi.Uint8> bytes, ffi.Pointer<ffi.Pointer<ffi.Uint8>> encodedOutput)>>('cvtColor').asFunction();


String opencvVersion() {
  return _version().toDartString();
}
void cvtColor(ProcessImageArgumentsB args){

  try{
    DateTime startTime;
    startTime = DateTime.now();
  ffi.Pointer<ffi.Uint8> imgPtr = malloc.allocate(args.imgBytes.lengthInBytes);

   //allocate just 8 bytes to store a pointer that will be malloced in C++ that points to our variably sized encoded image
   ffi.Pointer<ffi.Pointer<ffi.Uint8>> encodedImgPtr = malloc.allocate(8);
    
   //copy the image data into the memory heap we just allocated
   imgPtr.asTypedList(args.imgBytes.length).setAll(0, args.imgBytes);

   //c++ image processing
   //image in memory heap -> processing... -> processed image in memory heap
   int encodedImgLen = _cvtColor(args.imgBytes.length, imgPtr, encodedImgPtr);
   //

   //retrieve the image data from the memory heap
   ffi.Pointer<ffi.Uint8> cppPointer = encodedImgPtr.elementAt(0).value;
   Uint8List encodedImBytes = cppPointer.asTypedList(encodedImgLen);
   //myImg = Image.memory(encodedImBytes);
   args.sendPort.send(encodedImBytes); // 将数据发送回主isolate
  DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function cvtColor took ${elapsedTime.inMilliseconds} milliseconds to execute.');
  malloc.free(imgPtr);
   malloc.free(cppPointer);
   malloc.free(encodedImgPtr); 
  } catch (e) {
    args.sendPort.send(null); // 发送null或错误指示信号回到主isolate
  } finally {
    
  }
 }
void processImage(ProcessImageArguments args) {
   DateTime startTime;
    startTime = DateTime.now();
  _processImage(args.inputPath.toNativeUtf8(), args.outputPath.toNativeUtf8());
  DateTime endTime = DateTime.now();
  Duration elapsedTime = endTime.difference(startTime);
  dev.log('Function proc took ${elapsedTime.inMilliseconds} milliseconds to execute.');
}

class ProcessImageArguments {
  final String inputPath;
  final String outputPath;

  ProcessImageArguments(this.inputPath, this.outputPath);
}
class ProcessImageArgumentsB {
  
  final Uint8List imgBytes;
  final SendPort sendPort;
  ProcessImageArgumentsB(this.imgBytes,this.sendPort);
}
