import 'package:flutter/material.dart';

class AppPreloaderScreen extends StatefulWidget {
  final Widget child;
  const AppPreloaderScreen({super.key, required this.child});

  @override
  State<AppPreloaderScreen> createState() => _AppPreloaderScreenState();
}

class _AppPreloaderScreenState extends State<AppPreloaderScreen> {
  bool _isReady = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAssets();
    });
  }

  Future<void> _preloadAssets() async {
    try {
      // 1. Tải trước dữ liệu cục bộ từ bộ nhớ
      setState(() => _progress = 0.1);
      await Future<void>.delayed(const Duration(milliseconds: 300)); // Giả lập đọc cấu hình

      // 2. Tải trước các hình ảnh nặng (đã được nén sang webp)
      final assetsToPrecache = [
        'assets/images/island/safety-island.webp',
        'assets/images/inslandBackground.webp',
        'assets/images/mascot/mascot-cat-singing.webp',
        'assets/images/mascot/mascot-cat-happy.webp',
        'assets/images/mascot/mascot-cat-happy-wave.webp',
        'assets/images/mascot/mascot-cat-speaking.webp',
        'assets/images/logo/logo smartstep-01.webp',
      ];

      double stepValue = 0.8 / assetsToPrecache.length;
      for (var asset in assetsToPrecache) {
        if (!mounted) return;
        try {
          await precacheImage(AssetImage(asset), context);
        } catch (e) {
          debugPrint("Không thể pre-cache hình ảnh $asset: $e");
        }
        setState(() {
          _progress = (_progress + stepValue).clamp(0.0, 0.9);
        });
      }

      setState(() => _progress = 1.0);
    } catch (e) {
      debugPrint("Lỗi nạp tài nguyên prefetch: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF1B5), // Đồng bộ màu nền DuoColors.background
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Đang chuẩn bị màn chơi... ${(_progress * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF25324B),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
