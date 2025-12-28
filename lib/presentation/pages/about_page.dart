import 'package:flutter/material.dart';

import 'package:gardaloto/core/constants.dart'; // Ensure this imports appVersion
import 'package:gardaloto/presentation/widget/glass_panel.dart'; // Reuse GlassPanel for consistency
import 'package:http/http.dart' as http;

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent, // Glassy look if possible
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027), // Deep Dark Blue/Black
              Color(0xFF203A43), // Muted Teal/Grey-Blue
              Color(0xFF2C5364), // Softer Blue-Grey
            ],
          ),
        ),
        child: SafeArea(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: Colors.cyanAccent,
                  labelColor: Colors.cyanAccent,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: 'About'),
                    Tab(text: 'Contact'),
                    Tab(text: 'Changelog'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAboutTab(),
                      _buildContactTab(),
                      const _ChangelogTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 100, width: 100),
          const SizedBox(height: 24),
          const Text(
            'GardaLoto',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Version $appVersion',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'App to Track Fuelman Activity of Performing LOTO isolation to mining equipment before conducting refueling activity.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Developer Card
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'DEVELOPED BY',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Scalar Coding Profile
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.black26,
                              backgroundImage: NetworkImage(
                                'https://fylkjewedppsariokvvl.supabase.co/storage/v1/object/public/images/profile/scalar.png',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scalar Coding',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // Septian Profile
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.black26,
                              backgroundImage: NetworkImage(
                                'https://fylkjewedppsariokvvl.supabase.co/storage/v1/object/public/images/profile/septian.jpg',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Septian N.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Inquiry Card
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Colors.cyanAccent,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Have a project in mind?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inquiry to make any program can be sent through email:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.email,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const SelectableText(
                          'scalar.coding@gmail.com',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangelogTab extends StatefulWidget {
  const _ChangelogTab();

  @override
  State<_ChangelogTab> createState() => _ChangelogTabState();
}

class _ChangelogTabState extends State<_ChangelogTab> {
  String? _changelogContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchChangelog();
  }

  Future<void> _fetchChangelog() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://raw.githubusercontent.com/septiannuriyanto/gardaloto/main/CHANGELOG.md',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _changelogContent = response.body;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load changelog: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading changelog: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchChangelog();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Manual Markdown Parsing
    final lines = _changelogContent?.split('\n') ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        if (line.startsWith('# ')) {
          // H1
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else if (line.startsWith('## ')) {
          // H2
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else if (line.startsWith('### ')) {
          // H3
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        } else if (line.trim().startsWith('- ')) {
          // Bullet list
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.trim().substring(2),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        } else if (line.trim().startsWith('* ')) {
          // Bullet list alternative
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.trim().substring(2),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        } else {
          // Normal Text
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          );
        }
      },
    );
  }
}
