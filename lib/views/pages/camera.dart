import 'package:face/data/notifiers.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../widgets/camera_view.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  CameraPageState createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> {
  late FaceDetector _faceDetector;
  late tfl.Interpreter _interpreter;
  bool _isBusy = false;
  String _text = '';

  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadModels();
  }

  Future<void> _loadModels() async {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
    );
    _faceDetector = FaceDetector(options: options);
    _interpreter = await tfl.Interpreter.fromAsset('assets/mobilefacenet.tflite');
  }

  Future<void> _processImage(imglib.Image convertedImage, InputImage inputImage) async {
    if (_isBusy) return; // 防止并发执行
    setState(() {
      _isBusy = true;
      _text = 'Processing...';
    });

    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      String result = '';
      for (Face face in faces) {
        final Rect boundingBox = face.boundingBox;
        final double? rotX = face.headEulerAngleX;
        final double? rotY = face.headEulerAngleY;
        final double? rotZ = face.headEulerAngleZ;

        double x = face.boundingBox.left - 10;
        double y = face.boundingBox.top - 10;
        double w = face.boundingBox.width + 10;
        double h = face.boundingBox.height + 10;

        imglib.Image croppedImage = imglib.copyCrop(
          convertedImage,
          x: x.round(),
          y: y.round(),
          width: w.round(),
          height: h.round(),
        );
        croppedImage = imglib.copyResizeCropSquare(croppedImage, size: 112);

        var res = _recog(croppedImage);

        result += 'Face detected!\n';
        result += 'Bounding Box: ${boundingBox.toString()}\n';
        result += 'Rotation X: $rotX\n';
        result += 'Rotation Y: $rotY\n';
        result += 'Rotation Z: $rotZ\n\n';
        result += 'Vector : $res\n\n';
      }

      setState(() {
        _text = faces.isEmpty ? 'No faces detected.' : result;
      });
    } catch (e) {
      setState(() {
        _text = 'Failed to process image: $e';
      });
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  String _recog(imglib.Image img) {
    List input = imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List<List<double>> output = List.generate(1, (_) => List.filled(192, 0));
    _interpreter.run(input, output);
    List<double> outputDouble = output[0];

    return _compare(outputDouble);
  }

  String _compare(List<double> currEmb) {
    const threshold = 1.0;
    double minDist = double.infinity;
    double currDist = 0.0;
    String predRes = "";
    bool notFound = true;
    for (var entry in facesNotifier.value.entries) {
      currDist = euclideanDistance(entry.value, currEmb);
      if (currDist <= threshold && currDist < minDist) {
        notFound = false;
        minDist = currDist;
        predRes = entry.key;
      }
    }

    if (notFound) {
      _showSaveDialog(currEmb);
      return "Not Found";
    }

    return predRes;
  }

  void _showSaveDialog(List<double> embedding) {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新人物"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "请输入人物名称",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 取消
              },
              child: const Text("取消"),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);

                String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  bool exits = facesNotifier.value.containsKey(name);
                  if (exits) {
                    final shouldOverride = await showDialog<bool>(
                      context: context, 
                      builder:(context) => AlertDialog(
                        title: Text('覆盖已有的人脸？'),
                        content: Text('名称 "$name" 已存在，是否覆盖原有数据？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('覆盖'),
                          ),
                        ],
                      )
                    );

                    if (shouldOverride != true) return; 
                  }
                  facesNotifier.value[name] = embedding;
                }

                navigator.pop();
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }




  @override
  void dispose() {
    _faceDetector.close();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 加载中
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // 加载失败
          return Center(child: Text('加载模型失败: ${snapshot.error}'));
        } else {
          // 加载成功，正常显示界面
          return Column(
            children: [
              Expanded(
                flex: 3,
                child: CameraView(
                  customPaint: null,
                  onImage: _processImage,
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_text),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}

Float32List imageToByteListFloat32(imglib.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (pixel.r - mean) / std;
      buffer[pixelIndex++] = (pixel.g - mean) / std;
      buffer[pixelIndex++] = (pixel.b - mean) / std;
    }
  }
  return convertedBytes.buffer.asFloat32List();
}

double euclideanDistance(List<double> e1, List<double> e2) {
  double sum = 0.0;
  for (int i = 0; i < e1.length; i++) {
    sum += pow((e1[i] - e2[i]), 2);
  }
  return sqrt(sum);
}
