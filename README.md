# face

A simple face recognize project.



## 实现

- Camera 的使用直接找了 `camera` 插件官方仓库的 example
- 人脸识别没有使用本地模型，使用 `google_mlkit_face_detection` 插件更方便
- 人脸特征提取用的一个 github 仓库使用的模型
- 图片格式的转换：Camera 得到的格式需要转换到
  -  `imglib.Image` 给用来裁剪（使用 `image` 插件，其中有对图像的各种操作）；
  -  `InputImage` 给 `google_mlkit_face_detection` 进行识别
  -  转为 List<double> 输入到人脸特征模型



## 图片处理流程

1. `CameraView` 类中持有 `CameraController? _controller`，调用通过 `_controller` 获取照片：

    ```dart
    final picture = await _controller!.takePicture();
    final bytes = await picture.readAsBytes();
    ```

    `picture` 为 `XFile` 类型，是跨平台文件抽象类型，可以理解为一个临时文件，所以可以从中读取得到 `Uint8List` 保存到 `bytes` 

    接着需要将数据转为两个图片表示格式：`imglib.Image` 是 `image` 插件的图片数据类型，方便后续对图片的裁剪；`InputImage` 是 `google_mlkit_face_detection` 插入中人脸识别模型的输入。直接调用构造函数即可：

    ```
    final imglib.Image? image = imglib.decodeImage(bytes);
    final inputImage = InputImage.fromFilePath(picture.path);
    ```

    > lib/views/widgets/camera_view.dart 中的 `_takePictureAndProcess` 函数

2. 使用 `google_mlkit_face_detection` 插件提供的接口处理 `inputImage`：

    ```dart
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    ```

    遍历每个 `Face` 对象，其中包含人脸在图片中的位置，这样可以对 `image` 进行剪裁：

    ````dart
    for (Face face in faces) {
        double x = face.boundingBox.left - 10;
        double y = face.boundingBox.top - 10;
        double w = face.boundingBox.width + 10;
        double h = face.boundingBox.height + 10;
    	
        // 拷贝出指定区域
        imglib.Image croppedImage = imglib.copyCrop(
          convertedImage,
          x: x.round(),
          y: y.round(),
          width: w.round(),
          height: h.round(),
        );
        // 缩放图片到指定大小（112 等常量应该用 const 定义，避免出现魔数）
        croppedImage = imglib.copyResizeCropSquare(croppedImage, size: 112);
    }
    ````

    > lib/views/pages/camera.dart 中的 `_processImage` 函数
3. 执行人脸识别。首先将 `imglib.Image` 转为一个 `ListFloat32`，这样才能输入模型

    ```dart
    List input = imageToByteListFloat32(img, 112, 128, 128);
    ```

    接着可以进行模型推理：

    ```dart
    input = input.reshape([1, 112, 112, 3]);
    List<List<double>> output = List.generate(1, (_) => List.filled(192, 0));
    _interpreter.run(input, output);
    List<double> outputDouble = output[0];
    ```

	>lib/views/pages/camera.dart 中的 `_recog` 函数

这个过程没有包含人脸对齐。




## References

- https://bbs.itying.com/topic/67892ace24cdd5004b4488d7：使用 `google_mlkit_face_detection` 的简单例子
- https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/camera_view.dart：`camera` 插件的官方例子，实现了一个完整的拍照界面，暴露了 `onImage` 接口来处理图像
- https://github.com/Rajatkalsotra/Face-Recognition-Flutter.git：一个开源的面部识别 demo，主要从这里下载 mobilefacenet.tflite，以及学习一下 `tflite_flutter` 插件的基本使用（如何加载、推理）
- https://stackoverflow.com/questions/68080493/how-to-convert-cameracontrollers-xfile-to-image-type-in-flutter：Image 图像各种格式的转换