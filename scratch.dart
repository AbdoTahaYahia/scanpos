import 'package:camera/camera.dart';

void main() {
  CameraController(
    const CameraDescription(
      name: '0',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
    ResolutionPreset.medium,
    fps: 60,
  );
}
