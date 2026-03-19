import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../main.dart';

class HomeController extends GetxController {
  CameraController? cameraController;
  var isCameraInitialized = false.obs;
  var currentExpressionImage =
      'assets/images/wigabofaces/neutral-wigabo.png'.obs;

  late final FaceDetector _faceDetector;

  bool _isProcessing = false;

  @override
  void onInit() {
    super.onInit();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
      ),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await cameraController!.initialize();
    isCameraInitialized.value = true;

    cameraController!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      _detectFaces(image, frontCamera);
    });
  }

  Future<void> _detectFaces(CameraImage image, CameraDescription camera) async {
    try {
      final inputImage = _convertCameraImageToInputImage(image, camera);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;

        final double smile = face.smilingProbability ?? 0.0;
        final double leftEye = face.leftEyeOpenProbability ?? 1.0;
        final double rightEye = face.rightEyeOpenProbability ?? 1.0;
        final double headTurnY = face.headEulerAngleY ?? 0.0;
        final double headTurnX = face.headEulerAngleX ?? 0.0;

        if (leftEye < 0.3 && rightEye < 0.3 && headTurnX > 15) {
          currentExpressionImage.value =
              'assets/images/wigabofaces/sleep-wigabo.png';
        } else if (leftEye < 0.5 && rightEye > 0.1  && headTurnX < 0.5) {
          currentExpressionImage.value =
              'assets/images/wigabofaces/wink-wigabo.png';
        } else if (smile > 0.75) {
          currentExpressionImage.value =
              'assets/images/wigabofaces/smile-wigabo.png';
        } else if (headTurnY > 30 || headTurnY < -30) {
          currentExpressionImage.value =
              'assets/images/wigabofaces/look-suspicius-wigabo.png';
        } else {
          currentExpressionImage.value =
              'assets/images/wigabofaces/neutral-wigabo.png';
        }
      } else {
        currentExpressionImage.value =
            'assets/images/wigabofaces/away-wigabo.png';
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  @override
  void onClose() {
    cameraController?.stopImageStream();
    cameraController?.dispose();
    _faceDetector.close();
    super.onClose();
  }
}
