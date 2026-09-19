import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhotoGalleryViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final Map<String, String>? imageCategoryMap; // 图片路径 -> 栏目名称映射
  final Function(int newIndex, String? categoryName)? onPageChanged;

  const PhotoGalleryViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.imageCategoryMap,
    this.onPageChanged,
  });

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _showControls = true;
  late TransformationController _transformController;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _transformController = TransformationController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _transformController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      // 以双击位置为中心进行 2.5 倍缩放
      _transformController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
    setState(() {});
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _changeImage(_currentIndex - 1);
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imagePaths.length - 1) {
      _changeImage(_currentIndex + 1);
    }
  }

  void _changeImage(int newIndex) {
    setState(() {
      _currentIndex = newIndex;
      _transformController.value = Matrix4.identity();
    });
    final path = widget.imagePaths[newIndex];
    final cat = widget.imageCategoryMap?[path];
    if (widget.onPageChanged != null) {
      widget.onPageChanged!(newIndex, cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: const Center(child: Text('没有可查看的图片', style: TextStyle(color: Colors.white))),
      );
    }

    final currentImgPath = widget.imagePaths[_currentIndex];
    final currentCatName = widget.imageCategoryMap?[currentImgPath] ?? '';
    final currentImgFile = File(currentImgPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 核心图片显示区：手势完全由底层独占，彻底杜绝外层手势竞争导致的双指缩放失效
          GestureDetector(
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: _onDoubleTap,
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: InteractiveViewer(
                key: ValueKey('img_viewer_$_currentIndex'),
                transformationController: _transformController,
                clipBehavior: Clip.none,
                minScale: 0.5,
                maxScale: 10.0,
                panEnabled: true,
                scaleEnabled: true,
                panAxis: PanAxis.free,
                // 超大平移边界，让放大后化验单的任何边缘角落均可自由拖拽到屏幕中央
                boundaryMargin: const EdgeInsets.symmetric(horizontal: 1200, vertical: 1200),
                child: Center(
                  child: currentImgFile.existsSync()
                      ? Image.file(
                          currentImgFile,
                          fit: BoxFit.contain,
                        )
                      : const Center(
                          child: Text('化验单图片不存在或已被移除', style: TextStyle(color: Colors.white70)),
                        ),
                ),
              ),
            ),
          ),

          // 2. 左右独立半透明悬浮切图控制箭头
          if (widget.imagePaths.length > 1) ...[
            // 左箭头：上一张
            Positioned(
              left: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showControls && _currentIndex > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls || _currentIndex == 0,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToPrevious,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 右箭头：下一张
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showControls && _currentIndex < widget.imagePaths.length - 1 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls || _currentIndex >= widget.imagePaths.length - 1,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToNext,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // 3. 顶部导航与快捷控制栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                left: 14,
                right: 14,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '化验单原图 (${_currentIndex + 1}/${widget.imagePaths.length})',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (currentCatName.isNotEmpty)
                            Text(
                              '所属单据: $currentCatName',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.white70),
                        tooltip: '还原尺寸',
                        onPressed: () {
                          setState(() {
                            _transformController.value = Matrix4.identity();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. 底部状态与操作说明栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 24 : -100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pinch, color: Colors.lightBlueAccent, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '双指放大缩小 · 自由拖动看边缘',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    '双击可快速放大',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
