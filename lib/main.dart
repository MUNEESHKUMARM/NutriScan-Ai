import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const NutriScanApp());
}

class NutriScanApp extends StatelessWidget {
  const NutriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? controller;
  bool isScanning = false;
  String status = "Ready to Scan";
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras![0], ResolutionPreset.medium);
    controller!.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> scanFood() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        isScanning) {
      return;
    }

    setState(() {
      isScanning = true;
      status = "AI is analyzing...";
      result = null;
    });

    try {
      final image = await controller!.takePicture();

      // 🔴 CHANGE THIS IF USING MOBILE
      final uri = Uri.parse("http://localhost:8001/predict");

      final request = http.MultipartRequest("POST", uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          await image.readAsBytes(),
          filename: image.name,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint("RAW RESPONSE => ${response.body}");

      final decoded = json.decode(response.body);

      setState(() {
        if (decoded is Map && decoded["error"] != null) {
          status = "Scan Failed";
          result = {"error": decoded["error"].toString()};
        } else {
          status = "Scan Complete!";
          result = decoded;
        }
      });
    } catch (e) {
      setState(() {
        status = "Connection Error";
        result = {"error": e.toString()};
      });
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Widget nutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "NutriScan AI 🥗",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: controller != null && controller!.value.isInitialized
                ? CameraPreview(controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(status,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),

                    // ❌ ERROR VIEW
                    if (result != null && result!["error"] != null)
                      Text(
                        result!["error"],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    // ✅ SUCCESS VIEW
                    if (result != null && result!["error"] == null) ...[
                      Text(
                        result!["food"] ?? "",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        "Accuracy: ${result!["accuracy"] ?? "-"}",
                        style:
                            const TextStyle(color: Colors.orange),
                      ),
                      const Divider(height: 30),

                      nutritionRow(
                          "🔥 Calories", result!["calories"] ?? "N/A"),
                      nutritionRow(
                          "💪 Protein", result!["protein"] ?? "N/A"),
                      nutritionRow(
                          "🥑 Total Fat", result!["fat"] ?? "N/A"),
                      nutritionRow(
                          "🍞 Carbs", result!["carbs"] ?? "N/A"),

                      const SizedBox(height: 12),
                      Text(
                        result!["advice"] ?? "",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isScanning ? null : scanFood,
                      icon: isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(
                          isScanning ? "ANALYZING..." : "SCAN FOOD"),
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, 55),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
