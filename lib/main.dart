import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  var detectResult;
  CameraImage imageStrem;
  CameraController controller;
  var isWorking = false;

  Future<String> loadModel() async {
    return await Tflite.loadModel(
        model: "assets/face_mask.tflite", labels: "assets/mask_labelmap.txt");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        controller = CameraController(cameras[0], ResolutionPreset.max);
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    loadModel().then((value) => print(value));
    initCamera();
    super.initState();
  }

  initCamera() {
    controller = CameraController(cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        controller.startImageStream((image) {
          if (!isWorking) {
            isWorking = true;
            imageStrem = image;
            onFrameDetection();
          }
        });
      });
    });
  }

  onFrameDetection() async {
    var recognitions;
    if (imageStrem != null) {
      recognitions = await Tflite.detectObjectOnFrame(
          bytesList: imageStrem.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          model: "SSDMobileNet",
          imageHeight: imageStrem.height,
          imageWidth: imageStrem.width,
          imageMean: 127.5,
          imageStd: 127.5,
          rotation: 90,
          numResultsPerClass: 10,
          threshold: 0.1,
          asynch: true);
      setState(() {
        detectResult = recognitions;
      });
      recognitions = "";
      isWorking = false;
    }
  }

  Widget drawWidget() {
    return Container();
  }

  @override
  void dispose() {
    super.dispose();
    Tflite.close();
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AllContent(
          cameraController: controller,
          detectResult: detectResult,
        ),
      ),
    );
  }
}

class AllContent extends StatelessWidget {
  final List detectResult;
  final CameraController cameraController;
  const AllContent({Key key, this.detectResult, this.cameraController})
      : super(key: key);
  List<Widget> renderBoxes(Size screen) {
    if (detectResult == null) return [];

    double factorX = screen.width;
    double factorY = screen.height;

    Color blue = Colors.redAccent;

    return detectResult.map((re) {
      return Container(
        child: Positioned(
            left: re["rect"]["x"] * factorX,
            top: re["rect"]["y"] * factorY,
            width: re["rect"]["w"] * factorX,
            height: re["rect"]["h"] * factorY,
            child: ((re["confidenceInClass"] > 0.50))
                ? Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                      color: blue,
                      width: 3,
                    )),
                    child: Text(
                      "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        background: Paint()..color = blue,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  )
                : Container()),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChild = [];
    stackChild.add(Container(
      child: CameraPreview(cameraController),
      height: MediaQuery.of(context).size.height,
    ));
    stackChild.addAll(renderBoxes(MediaQuery.of(context).size));
    return Stack(
      children: stackChild,
    );
  }
}
