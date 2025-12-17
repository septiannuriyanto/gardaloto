import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class FullScreenGallery extends StatefulWidget {
  final List<LotoEntity> records;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.records,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late ScrollController _scrollController;
  late int _currentIndex;
  bool _showArrows = true;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _scrollController = ScrollController();
    
    // Initial scroll to center active item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_currentIndex);
    });
    
    _startFadeTimer();
  }

  void _scrollToIndex(int index) {
    if (_scrollController.hasClients) {
      double itemWidth = 68.0; // 60 width + 8 margin
      double screenWidth = MediaQuery.of(context).size.width;
      double offset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
      
      // Clamp offset logic is handled by ScrollController mostly, but good to be safe?
      // animateTo clamps automatically.
      
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    setState(() => _showArrows = true);
    _fadeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showArrows = false);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollToIndex(index);
    _startFadeTimer(); // Reset timer on swipe
  }

  void _onTap() {
    // Toggle or reset timer on tap
    if (_showArrows) {
      // If showing, maybe hide immediately or just reset? 
      // User said "transparan saat 2 detik pertama di zoom yang akan fade out".
      // Usually tapping toggles visibility.
      _startFadeTimer();
    } else {
      _startFadeTimer();
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.records.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Gallery
          GestureDetector(
            onTap: _onTap,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                final record = widget.records[index];
                final isLocal = !record.photoPath.startsWith('http');
                final imageProvider = isLocal
                    ? FileImage(File(record.photoPath))
                    : CachedNetworkImageProvider(record.photoPath);

                return PhotoViewGalleryPageOptions(
                  imageProvider: imageProvider as ImageProvider,
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: record.photoPath),
                );
              },
              itemCount: widget.records.length,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
            ),
          ),

          // Left Arrow
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              child: AnimatedOpacity(
                opacity: _showArrows ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 48),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    _startFadeTimer();
                  },
                ),
              ),
            ),

          // Right Arrow
          if (_currentIndex < widget.records.length - 1)
            Positioned(
              right: 16,
              child: AnimatedOpacity(
                opacity: _showArrows ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 48),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    _startFadeTimer();
                  },
                ),
              ),
            ),
            
          // Bottom Controls (Thumbnails & Caption)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showArrows ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thumbnail Strip
                    Container(
                      height: 80,
                      alignment: Alignment.center,
                      child: ListView.builder(
                        shrinkWrap: true, // Center if few items
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.records.length,
                        itemBuilder: (context, index) {
                          final record = widget.records[index];
                          final isLocal = !record.photoPath.startsWith('http');
                          final isSelected = _currentIndex == index;
                          
                          return GestureDetector(
                            onTap: () {
                              _pageController.jumpToPage(index);
                              _startFadeTimer();
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: isLocal
                                    ? Image.file(
                                        File(record.photoPath),
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: record.photoPath,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey[800]),
                                        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Caption
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.records[_currentIndex].codeNumber,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
