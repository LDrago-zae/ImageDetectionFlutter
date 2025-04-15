import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ObjectDetector objectDetector;
  XFile? _image;
  List<DetectedObject> _detectedObjects = [];

  // Function to pick image either from gallery or camera
  Future<void> _picImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? image;

    // Show dialog and get user choice (camera or gallery)
    final String? source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'camera');
            },
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'gallery');
            },
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source != null) {
      if (source == 'camera') {
        image = await picker.pickImage(source: ImageSource.camera);
      } else if (source == 'gallery') {
        image = await picker.pickImage(source: ImageSource.gallery);
      }

      // Check if the widget is still mounted before calling setState
      if (!mounted) return;

      if (image != null) {
        setState(() {
          _image = image;
          _detectedObjects = []; // Clear previous detections
        });
        doObjectDetection();
      }
    }
  }

  // Method to initialize the object detector
  void initializeObjectDetector() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    objectDetector = ObjectDetector(options: options);
  }

  // Object detection method
  void doObjectDetection() async {
    if (_image == null) return;

    final inputImage = InputImage.fromFile(File(_image!.path));
    final List<DetectedObject> objects = await objectDetector.processImage(inputImage);

    // Update state with detected objects
    setState(() {
      _detectedObjects = objects;
    });

    // Process detected objects here (e.g., show bounding boxes, etc.)
    for (DetectedObject object in objects) {
      final rect = object.boundingBox;
      final trackingId = object.trackingId;

      // Iterate through object labels and print confidence
      for (Label label in object.labels) {
        print('${label.text} ${label.confidence}');
      }
      print('Detected Object Bounding Box: $rect');
      print('Tracking ID: $trackingId');
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
      _detectedObjects = [];
    });
  }

  @override
  void initState() {
    super.initState();
    initializeObjectDetector();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/bg.jpg",
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 60.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onLongPress: _picImage,
                      onTap: _clearImage,
                      child: Container(
                        height: 300,
                        width: 300,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _image != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(
                                      File(_image!.path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Draw bounding boxes
                                  CustomPaint(
                                    painter: ObjectDetectorPainter(
                                      _detectedObjects,
                                      Size(300, 300),
                                      File(_image!.path),
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
                if (_detectedObjects.isNotEmpty)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        itemCount: _detectedObjects.length,
                        itemBuilder: (context, index) {
                          final object = _detectedObjects[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Object ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...object.labels.map((label) => Text(
                                        '${label.text}: ${(label.confidence * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 14),
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter to draw bounding boxes
class ObjectDetectorPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size absoluteImageSize;
  final File imageFile;

  ObjectDetectorPainter(this.objects, this.absoluteImageSize, this.imageFile);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    final Paint background = Paint()..color = Colors.black.withValues(alpha: 0.5);

    for (final DetectedObject object in objects) {
      final Rect rect = Rect.fromLTRB(
        object.boundingBox.left * scaleX,
        object.boundingBox.top * scaleY,
        object.boundingBox.right * scaleX,
        object.boundingBox.bottom * scaleY,
      );

      canvas.drawRect(rect, paint);

      // Draw label if available
      if (object.labels.isNotEmpty) {
        final String label = object.labels.first.text;
        final TextSpan span = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );

        final TextPainter textPainter = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Draw background for text
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left,
            rect.top - textPainter.height,
            textPainter.width + 4,
            textPainter.height,
          ),
          background,
        );

        // Draw text
        textPainter.paint(
          canvas,
          Offset(rect.left + 2, rect.top - textPainter.height),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.objects != objects;
  }
}
