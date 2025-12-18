import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1), // White frost
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield, size: 48, color: Colors.cyanAccent),
                            const SizedBox(height: 12),
                            const Text(
                              'GardaLoto',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      _buildListTile(context, 'Dashboard', Icons.home, 'dashboard'),
                      _buildListTile(context, 'LOTO', Icons.lock, 'loto'),
                      _buildListTile(context, 'Fit To Work', Icons.health_and_safety, 'fit'),
                      _buildListTile(context, 'Ready To Work', Icons.check_circle, 'ready'),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Future.delayed(const Duration(milliseconds: 250), () {
                      if (context.mounted) {
                        context.read<AuthCubit>().logout();
                        context.goNamed('auth_gate');
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon, String routeName) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Future.delayed(const Duration(milliseconds: 250), () {
          if (context.mounted) {
            context.pushNamed(routeName);
          }
        });
      },
    );
  }
}
