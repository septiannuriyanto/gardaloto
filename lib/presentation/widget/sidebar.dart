import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'GardaLoto',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Future.delayed(const Duration(milliseconds: 250), () {
                    context.goNamed('dashboard');
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('LOTO'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Future.delayed(const Duration(milliseconds: 250), () {
                    context.pushNamed('loto');
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety),
                title: const Text('Fit To Work'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Future.delayed(const Duration(milliseconds: 250), () {
                    context.pushNamed('fit');
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Ready To Work'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Future.delayed(const Duration(milliseconds: 250), () {
                    context.pushNamed('ready');
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Future.delayed(const Duration(milliseconds: 250), () {
              context.read<AuthCubit>().logout();
              context.goNamed('auth_gate');
            });
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
