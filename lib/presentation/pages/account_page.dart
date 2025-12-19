import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:gardaloto/core/service_locator.dart'; // For accessing dependencies if needed, but Cubit is enough

import 'package:palette_generator/palette_generator.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  List<Color> _gradientColors = [];
  String? _currentBgUrl;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _gradientColors = _generateRandomGradient();

    // Initial check if user is loaded
    final state = context.read<AuthCubit>().state;
    if (state is AuthAuthenticated) {
      _updatePalette(state.user.bgPhotoUrl);
    }

    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _updatePalette(String? url) async {
    if (url == _currentBgUrl) return; // No change
    _currentBgUrl = url;

    if (url == null || url.isEmpty) {
      // Revert to random or keep current?
      // User might want to revert to default if they remove photo.
      // But if they just entered, random is fine.
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        maximumColorCount: 20,
      );

      if (!mounted) return;

      Color? dominant = palette.dominantColor?.color;
      Color? darkVibrant = palette.darkVibrantColor?.color;

      Color? darkMuted = palette.darkMutedColor?.color;

      // Logic to pick harmonious gradient
      // We want a dark-ish background usually.

      List<Color> newColors = [];

      if (dominant != null && darkVibrant != null) {
        newColors = [dominant, darkVibrant];
      } else if (dominant != null) {
        newColors = [
          dominant,
          dominant.withValues(alpha: 0.6),
        ]; // Darker shade?
      } else if (darkMuted != null) {
        newColors = [darkMuted, Colors.black];
      }

      // Ensure it's not too bright if we want dark theme consistency?
      // Use HSL to darken if needed?
      // For now, let's just use what we found but darken them for background use.

      if (newColors.isNotEmpty) {
        setState(() {
          _gradientColors =
              newColors.map((c) {
                // Make sure it's not too bright.
                final hsl = HSLColor.fromColor(c);
                if (hsl.lightness > 0.4) {
                  return hsl.withLightness(0.2).toColor(); // Darken it
                }
                return c;
              }).toList();

          // Ensure at least 2 colors for gradient
          if (_gradientColors.length == 1) {
            _gradientColors.add(Colors.black);
          }
        });
      }
    } catch (e) {
      print('Error generating palette: $e');
    }
  }

  List<Color> _generateRandomGradient() {
    final random = Random();
    // Vibrant colors suitable for dark themes
    final colors = [
      const Color(0xFF0F2027), // Depths
      const Color(0xFF203A43), // Turquoise
      const Color(0xFF2C5364), // Blue-Grey
      const Color(0xFF232526), // Midnight
      const Color(0xFF414345), // Obsidian
      const Color(0xFF00416A), // Cobalt
      const Color(0xFFE4E5E6), // Silver
      const Color(0xFF004e92), // Cosmic Blue
      const Color(0xFF50cc7f), // Emerald
      const Color(0xFFf5af19), // Sunset
      const Color(0xFF8E2DE2), // Purple
      const Color(0xFF4A00E0), // Violet
    ];

    Color c1 = colors[random.nextInt(colors.length)];
    Color c2 = colors[random.nextInt(colors.length)];
    if (c1 == c2) c2 = colors[(colors.indexOf(c1) + 1) % colors.length];

    return [c1, c2];
  }

  void _viewPhoto(String url) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: PhotoView(
                imageProvider: CachedNetworkImageProvider(url),
                heroAttributes: const PhotoViewHeroAttributes(
                  tag: 'photo_view',
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _changePhoto(bool isBg) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      if (!mounted) return;
      context.read<AuthCubit>().updatePhoto(File(image.path), isBg);
    }
  }

  void _deletePhoto(bool isBg) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Photo?'),
            content: const Text('Are you sure you want to remove this photo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<AuthCubit>().deletePhoto(isBg);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showPhotoOptions(String? currentUrl, bool isBg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C5364),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUrl != null && currentUrl.isNotEmpty)
                    ListTile(
                      leading: const Icon(
                        Icons.visibility,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'View Full Photo',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _viewPhoto(currentUrl);
                      },
                    ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Change Photo',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _changePhoto(isBg);
                    },
                  ),
                  if (currentUrl != null && currentUrl.isNotEmpty)
                    ListTile(
                      leading: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'Delete Photo',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _deletePhoto(isBg);
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 30% height for header as requested by USER manually
    final screenHeight = MediaQuery.of(context).size.height;
    final topHeight = screenHeight * 0.30;
    const avatarRadius = 60.0;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _updatePalette(state.user.bgPhotoUrl);
        }
      },
      builder: (context, state) {
        String? photoUrl;
        String? bgPhotoUrl;
        String name = 'User';
        String nrp = '-';
        String email = '-';
        String position = '-';
        String sid = '-';

        if (state is AuthAuthenticated) {
          final u = state.user;
          photoUrl = u.photoUrl;
          bgPhotoUrl = u.bgPhotoUrl;
          name = u.nama ?? 'User';
          nrp = u.nrp ?? '-';
          email = u.email;
          position = u.positionDescription ?? (u.position?.toString() ?? '-');
          sid = u.sidCode ?? '-';
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          body: Stack(
            children: [
              // LAYER 1: Full Screen Gradient Background (Always Visible)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _gradientColors,
                    ),
                  ),
                ),
              ),

              // Loading Indicator
              if (state is AuthLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // LAYER 2: Scrollable Content
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Header Composite (Image + Avatar)
                            SizedBox(
                              height: topHeight + avatarRadius,
                              child: Stack(
                                children: [
                                  // 1. Header Background Area
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: topHeight,
                                    child: GestureDetector(
                                      onTap:
                                          () => _showPhotoOptions(
                                            bgPhotoUrl,
                                            true,
                                          ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              bgPhotoUrl != null &&
                                                      bgPhotoUrl!.isNotEmpty
                                                  ? Colors.black
                                                  : Colors.white.withOpacity(
                                                    0.1,
                                                  ),
                                          image:
                                              bgPhotoUrl != null &&
                                                      bgPhotoUrl!.isNotEmpty
                                                  ? DecorationImage(
                                                    image:
                                                        CachedNetworkImageProvider(
                                                          bgPhotoUrl!,
                                                        ),
                                                    fit: BoxFit.cover,
                                                  )
                                                  : null,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        child:
                                            bgPhotoUrl == null ||
                                                    bgPhotoUrl!.isEmpty
                                                ? Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.add_a_photo,
                                                        color: Colors.white
                                                            .withOpacity(0.5),
                                                        size: 32,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Add Cover Photo",
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(0.5),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                                : null,
                                      ),
                                    ),
                                  ),

                                  // 2. Avatar
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap:
                                            () => _showPhotoOptions(
                                              photoUrl,
                                              false,
                                            ),
                                        child: Hero(
                                          tag: 'profile-avatar',
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ), // Ring
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: avatarRadius,
                                              backgroundColor: Colors.grey[800],
                                              child: ClipOval(
                                                child:
                                                    photoUrl != null &&
                                                            photoUrl!.isNotEmpty
                                                        ? CachedNetworkImage(
                                                          imageUrl: photoUrl!,
                                                          width:
                                                              avatarRadius * 2,
                                                          height:
                                                              avatarRadius * 2,
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (
                                                                context,
                                                                url,
                                                              ) => Shimmer.fromColors(
                                                                baseColor:
                                                                    Colors
                                                                        .grey[700]!,
                                                                highlightColor:
                                                                    Colors
                                                                        .grey[500]!,
                                                                child: Container(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                              ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                err,
                                                              ) => const Icon(
                                                                Icons.person,
                                                                size: 60,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                        )
                                                        : const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.white,
                                                        ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Content Below
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 24),
                            const Divider(
                              color: Colors.white24,
                              indent: 32,
                              endIndent: 32,
                            ),
                            const SizedBox(height: 16),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRow(Icons.badge, 'NRP', nrp),
                                  _buildDetailRow(
                                    Icons.work,
                                    'Position',
                                    position,
                                  ),
                                  _buildDetailRow(
                                    Icons.fingerprint,
                                    'SID Code',
                                    sid,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Fixed Footer
                    Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                        top: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: 0.8,
                            child: Image.asset(
                              'assets/logo.png',
                              height: 32, // Smaller
                              width: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 8),
                          if (_version.isNotEmpty)
                            Text(
                              "v$_version",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          const SizedBox(height: 4),
                          const Text(
                            "Built by Scalar Coding",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10, // Smaller font
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
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
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // White frost
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
