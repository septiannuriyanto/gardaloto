import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';

class ReadyToWorkPage extends StatelessWidget {
  const ReadyToWorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Drawer(child: Sidebar()),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/ready.json', width: 220, repeat: true),
            const SizedBox(height: 24),
            const Text(
              "SIAP BEKERJA",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tetap patuhi prosedur keselamatan kerja",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
