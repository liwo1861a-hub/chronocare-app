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

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.identity()..scale(2.5);
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _goToPage(_currentIndex - 1);
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imagePaths.length - 1) {
      _goToPage(_currentIndex + 1);
    }
  }

  void _goToPage(int targetIndex) {
    _transformController.value = Matrix4.identity();
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
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

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          children: [
            // 核心图片展示区域：彻底禁用滑动翻页，将全部手势完全赋予平移与自由缩放拖动
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              // 禁用手势滑动切换，防止误触与抢占放大拖动
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _transformController.value = Matrix4.identity();
                });
                final path = widget.imagePaths[idx];
                final cat = widget.imageCategoryMap?[path];
                if (widget.onPageChanged != null) {
                  widget.onPageChanged!(idx, cat);
                }
              },
              itemBuilder: (context, index) {
                final imgFile = File(widget.imagePaths[index]);
                return GestureDetector(
                  onDoubleTap: _onDoubleTap,
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: index == _currentIndex ? _transformController : null,
                      clipBehavior: Clip.none,
                      minScale: 0.5,
                      maxScale: 8.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      // 提供充足的平移边距，确保放大后可以 360° 拖动看到化验单每个边缘角落
                      boundaryMargin: const EdgeInsets.symmetric(horizontal: 1000, vertical: 1000),
                      child: imgFile.existsSync()
                          ? Image.file(
                              imgFile,
                              fit: BoxFit.contain,
                            )
                          : const Center(
                              child: Text('化验单图片不存在或已被移除', style: TextStyle(color: Colors.white70)),
                            ),
                    ),
                  ),
                );
              },
            ),

            // 左右两侧显眼半透明悬浮切换箭头 (专为大图浏览打造，完全解决滑动手势冲突)
            if (widget.imagePaths.length > 1) ...[
              // 左箭头：上一张
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showControls && _currentIndex > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _currentIndex > 0 ? _goToPrevious : null,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
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

              // 右箭头：下一张
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showControls && _currentIndex < widget.imagePaths.length - 1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _currentIndex < widget.imagePaths.length - 1 ? _goToNext : null,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
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
            ],

            // 顶部导航栏与快捷操作
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.8),
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
                          const SizedBox(width: 8),
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
                            tooltip: '重置缩放',
                            onPressed: () {
                              _transformController.value = Matrix4.identity();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 底部悬浮信息条与缩放操作提示
            if (_showControls)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.touch_app, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            '双指缩放 · 自由拖动看边缘',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '点击两侧箭头切图',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
