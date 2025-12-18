import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';

class FitToWorkPage extends StatefulWidget {
  const FitToWorkPage({super.key});

  @override
  State<FitToWorkPage> createState() => _FitToWorkPageState();
}

class _FitToWorkPageState extends State<FitToWorkPage> {
  final _picker = ImagePicker();

  File? ftwScreenshot;
  File? parentalScreenshot;
  File? sobrietyPhoto;

  final String name = "Septian Nuriyanto";
  final String nrp = "NRP123456";
  final String sid = "SID998877";

  String shift = "Pagi";

  Future<void> pickImage(Function(File) onPicked) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      onPicked(File(image.path));
    }
  }

  Widget imageInput(String label, File? file, VoidCallback onPick) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle:
            file == null
                ? const Text("Belum diupload")
                : const Text("Sudah diupload"),
        trailing: IconButton(
          icon: const Icon(Icons.camera_alt),
          onPressed: onPick,
        ),
      ),
    );
  }

  bool get isFormValid =>
      ftwScreenshot != null &&
      parentalScreenshot != null &&
      sobrietyPhoto != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      appBar: AppBar(title: const Text("Fit To Work")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Data Driver",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Nama Driver",
                border: const OutlineInputBorder(),
                hintText: name,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "NRP",
                border: const OutlineInputBorder(),
                hintText: nrp,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "SID",
                border: const OutlineInputBorder(),
                hintText: sid,
              ),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField(
              value: shift,
              items: const [
                DropdownMenuItem(value: "Pagi", child: Text("Pagi")),
                DropdownMenuItem(value: "Malam", child: Text("Malam")),
              ],
              onChanged: (val) => setState(() => shift = val!),
              decoration: const InputDecoration(
                labelText: "Shift",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              "Upload Evidence",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            imageInput(
              "Screenshot FTW",
              ftwScreenshot,
              () => pickImage((f) => setState(() => ftwScreenshot = f)),
            ),

            imageInput(
              "Screenshot Parental Control",
              parentalScreenshot,
              () => pickImage((f) => setState(() => parentalScreenshot = f)),
            ),

            imageInput(
              "Foto Sobriety Test",
              sobrietyPhoto,
              () => pickImage((f) => setState(() => sobrietyPhoto = f)),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isFormValid
                        ? () {
                          // TODO: upload to Supabase storage & insert data
                          context.go('/ready');
                        }
                        : null,
                child: const Text("Submit Fit To Work"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
