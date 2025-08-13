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



## References

- https://bbs.itying.com/topic/67892ace24cdd5004b4488d7：使用 `google_mlkit_face_detection` 的简单例子
- https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/camera_view.dart：`camera` 插件的官方例子，实现了一个完整的拍照界面，暴露了 `onImage` 接口来处理图像
- https://github.com/Rajatkalsotra/Face-Recognition-Flutter.git：一个开源的面部识别 demo，主要从这里下载 mobilefacenet.tflite，以及学习一下 `tflite_flutter` 插件的基本使用（如何加载、推理）
- https://stackoverflow.com/questions/68080493/how-to-convert-cameracontrollers-xfile-to-image-type-in-flutter：Image 图像各种格式的转换