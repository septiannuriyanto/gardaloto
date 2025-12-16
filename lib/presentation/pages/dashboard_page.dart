import 'package:flutter/material.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Welcome to the Dashboard!')),
      drawer: Drawer(child: Sidebar()),
    );
  }
}
