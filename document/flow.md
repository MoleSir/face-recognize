# 人脸识别流程整理[https://github.com/Rajatkalsotra/Face-Recognition-Flutter.git]

这里分析 https://github.com/Rajatkalsotra/Face-Recognition-Flutter.git 项目采用的识别流程。但实际上本项目使用的略有不同。主要是使用 google_mlkit_face_detection 和 google_mlkit_commons 代替了 firebase_ml_vision。

## 1. Widget 初始化

使用 `tfl.Interpreter.fromAsset` 加载模型，得到 `interpreter`

```dart
final interpreter = tfl.Interpreter.fromAsset('your_model.tflite');
```

## 2. 初始化摄像头并监听图像流

```dart
_camera.startImageStream((CameraImage image) {
  // 每帧图像回调
  // 可调用检测、识别流程
});
```

## 3. 人脸检测

### 获取人脸检测模型

```dart
HandleDetection _getDetectionMethod() {
  final faceDetector = FirebaseVision.instance.faceDetector(
    FaceDetectorOptions(
      mode: FaceDetectorMode.accurate,
    ),
  );
  return faceDetector.processImage;
}
```

### 调用人脸检测

```dart
Future<dynamic> detect(
  CameraImage image,
  HandleDetection handleDetection,
  ImageRotation rotation,
) async {
  return handleDetection(
    FirebaseVisionImage.fromBytes(
      image.planes[0].bytes,
      buildMetaData(image, rotation),
    ),
  );
}
```

### Metadata 构建

```dart
FirebaseVisionImageMetadata buildMetaData(
  CameraImage image,
  ImageRotation rotation,
) {
  return FirebaseVisionImageMetadata(
    rawFormat: image.format.raw,
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    planeData: image.planes.map(
      (Plane plane) {
        return FirebaseVisionImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList(),
  );
}
```

## 4. 图像转换 

`_convertCameraImage` 函数的作用是将手机摄像头采集到的 `CameraImage`（通常是 YUV420 格式）转换成 `image` 包中的 RGB 图像格式 (`imglib.Image`)，方便后续图像处理和模型推理。

```dart
import 'package:image/image.dart' as imglib;

imglib.Image _convertCameraImage(CameraImage image, CameraLensDirection dir) {
  int width = image.width;
  int height = image.height;
  var img = imglib.Image(width, height); // 创建空图像

  const int hexFF = 0xFF000000;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      final int uvIndex =
          uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
      final int index = y * width + x;

      final int yp = image.planes[0].bytes[index];
      final int up = image.planes[1].bytes[uvIndex];
      final int vp = image.planes[2].bytes[uvIndex];

      int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255);
      int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

      img.data![index] = hexFF | (r) | (g << 8) | (b << 16);
    }
  }

  return (dir == CameraLensDirection.front)
      ? imglib.copyRotate(img, -90)
      : imglib.copyRotate(img, 90);
}
```

### 输入参数

- `CameraImage image`：摄像头采集到的原始图像数据，包含多平面数据（Y、U、V）。
- `CameraLensDirection dir`：摄像头方向，前置或后置，用来决定图像最终旋转角度。

### 主要流程和功能

#### 1. 创建目标图像缓冲区

```dart
var img = imglib.Image(width, height);
```

构造一个宽高同摄像头图像一样的空白 RGB 图像。

#### 2. 读取 YUV420 平面数据

- `image.planes[0]`：Y 平面（亮度）
- `image.planes[1]`：U 平面（色度）
- `image.planes[2]`：V 平面（色度）

YUV420 中 U、V 分辨率是 Y 的一半，所以计算 U、V 索引时用了 `(x/2)` 和 `(y/2)`。

#### 3. YUV 转 RGB 颜色空间转换

```dart
int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
```

通过常见的 YUV 转 RGB 公式，将 YUV 数值转换为 RGB 颜色值，最后用 `clamp` 限制在 0-255 范围内。

#### 4. 设置图像像素值

```dart
img.data![index] = hexFF | (r) | (g << 8) | (b << 16);
```

将计算得到的 RGB 颜色值存入目标图像数据缓冲区，`hexFF` 用于设置 Alpha 通道为不透明。

#### 5. 图像旋转调整

根据摄像头方向不同，旋转图像确保方向正确：

```dart
var img1 = (dir == CameraLensDirection.front)
    ? imglib.copyRotate(img, -90)
    : imglib.copyRotate(img, 90);
```

## 5. 遍历检测到的人脸结果

```dart
for (var face in result) {
  double x = (face.boundingBox.left - 10);
  double y = (face.boundingBox.top - 10);
  double w = (face.boundingBox.width + 10);
  double h = (face.boundingBox.height + 10);

  imglib.Image croppedImage = imglib.copyCrop(
    convertedImage, x.round(), y.round(), w.round(), h.round());

  croppedImage = imglib.copyResizeCropSquare(croppedImage, 112);

  var res = _recog(croppedImage);
  // 使用res做后续操作
}
```

从 `face` 获取人脸的区域，并且从图像 `convertedImage` （经过 5 步得到的 imglib 的 Image 对象）取出这个子图，并且将这个图片缩放到 112。

## 6. 识别函数 `_recog`

`_recog` 函数的核心作用是将经过裁剪和预处理的人脸图像输入到 TensorFlow Lite 模型中，进行推理，最终得到人脸的特征向量（embedding）。

```dart
import 'dart:typed_data';

String _recog(imglib.Image img) {
  List input = imageToByteListFloat32(img, 112, 128, 128);
  input = input.reshape([1, 112, 112, 3]);

  List output = List.filled(192, 0).reshape([1, 192]);

  interpreter.run(input, output);

  output = output.reshape([192]);

  List<double> e1 = List<double>.from(output);

  // 返回特征向量或识别结果
  return e1.toString();
}
```

### 输入参数

- `imglib.Image img`：已经裁剪且缩放到固定尺寸（如 112x112）的彩色人脸图像。

### 关键步骤解析

#### 1. 图像转换成模型输入格式

```dart
List input = imageToByteListFloat32(img, 112, 128, 128);
input = input.reshape([1, 112, 112, 3]);
```

````dart
Float32List imageToByteListFloat32(
  imglib.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;

  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (imglib.getRed(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (imglib.getBlue(pixel) - mean) / std;
    }
  }
  return convertedBytes.buffer.asFloat32List();
}
````

- `imageToByteListFloat32` 将 `imglib.Image` 中的 RGB 像素转换成浮点数数组。
- 归一化操作：每个像素的 R、G、B 通道值减去 `mean=128`，再除以 `std=128`，标准化到大致[-1,1]区间。
- 重塑（reshape）成模型期望的输入张量形状 `[batch=1, height=112, width=112, channels=3]`。

#### 2. 准备输出容器

```
List output = List.filled(192, 0).reshape([1, 192]);
```

- 创建一个大小为 192 的列表，代表模型输出的人脸特征向量长度（一般128、192等）。
- reshape 为 `[1, 192]` 以匹配模型输出形状。

#### 3. 运行模型推理

```
interpreter.run(input, output);
```

- 使用已经加载的 TensorFlow Lite 解释器执行推理，将输入数据传入，模型计算结果写入 `output`。

#### 4. 处理输出结果

```
output = output.reshape([192]);
List<double> e1 = List<double>.from(output);
```

- 将输出重塑为一维长度为192的数组。
- 转成 `List<double>` 类型，方便后续处理（比如相似度计算）。



