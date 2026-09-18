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
  bool _showAppBar = true;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // 进入全屏沉浸模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    // 退出时恢复系统 UI 状态
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
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.6),
              foregroundColor: Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_currentIndex + 1} / ${widget.imagePaths.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (currentCatName.isNotEmpty)
                    Text(
                      '所属栏目: $currentCatName',
                      style: const TextStyle(fontSize: 12, color: Colors.lightBlueAccent),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '重置缩放',
                  onPressed: () {
                    _transformController.value = Matrix4.identity();
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showAppBar = !_showAppBar;
          });
        },
        child: Stack(
          children: [
            // PageView 实现左右无缝横滑切换图片
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
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
                      clipBehavior: Clip.none, // 彻底消除黑边遮挡问题，放大全屏自由拖拽
                      minScale: 0.8,
                      maxScale: 6.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: imgFile.existsSync()
                          ? Image.file(
                              imgFile,
                              fit: BoxFit.contain,
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height,
                            )
                          : const Center(
                              child: Text('化验单图片不存在或已被移除', style: TextStyle(color: Colors.white70)),
                            ),
                    ),
                  ),
                );
              },
            ),

            // 底部悬浮快捷栏目指示与切换条
            if (_showAppBar && widget.imageCategoryMap != null)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science, color: Colors.lightBlueAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            currentCatName.isNotEmpty ? currentCatName : '化验单原图',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const Text(
                        '左右滑动切图 · 双指/双击放大',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
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
