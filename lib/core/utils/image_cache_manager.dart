import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../cache/sonic_cache_manager.dart';
import 'logger.dart';

/// Image cache manager with custom caching logic and lazy loading
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  final Logger _logger = Logger('ImageCacheManager');
  final SonicCacheManager _cacheManager = SonicCacheManager();
  final Dio _dio = Dio(
    BaseOptions(
      receiveTimeout: const Duration(seconds: 120),
      connectTimeout: const Duration(seconds: 30),
    ),
  );
  
  bool _cacheDisabled = false;
  bool _initialized = false;

  /// Initialize the manager
  Future<void> initialize() async {
    if (_initialized) return;
    await _cacheManager.initialize();
    _initialized = true;
    _logger.info('ImageCacheManager initialized');
  }

  /// Set cache disabled state
  void setCacheDisabled(bool disabled) {
    _cacheDisabled = disabled;
    _logger.info('Image cache ${disabled ? 'disabled' : 'enabled'}');
  }

  bool get isCacheDisabled => _cacheDisabled;

  /// Get cached image widget with lazy loading
  Widget getCachedImage({
    required String imageUrl,
    required String cacheKey,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (!_initialized) {
      initialize();
    }

    if (imageUrl.isEmpty) {
      return errorWidget ?? _buildErrorWidget(width, height);
    }

    // Use StatefulWidget for lazy loading
    return _LazyImageLoader(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      cacheManager: _cacheManager,
      dio: _dio,
      cacheDisabled: _cacheDisabled,
      logger: _logger,
    );
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await initialize();
    await _cacheManager.clearCache();
  }

  /// Get cache size in MB
  Future<double> getCacheSizeMB() async {
    await initialize();
    return await _cacheManager.getCacheSizeMB();
  }

  Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2D3B4E),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.album,
            color: Colors.white54,
            size: 32,
          ),
          SizedBox(height: 4),
          Text(
            '加载失败',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lazy image loader widget with frame scheduling
class _LazyImageLoader extends StatefulWidget {
  final String imageUrl;
  final String cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final SonicCacheManager cacheManager;
  final Dio dio;
  final bool cacheDisabled;
  final Logger logger;

  const _LazyImageLoader({
    required this.imageUrl,
    required this.cacheKey,
    this.width,
    this.height,
    required this.fit,
    this.placeholder,
    this.errorWidget,
    required this.cacheManager,
    required this.dio,
    required this.cacheDisabled,
    required this.logger,
  });

  @override
  State<_LazyImageLoader> createState() => _LazyImageLoaderState();
}

class _LazyImageLoaderState extends State<_LazyImageLoader> {
  File? _imageFile;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Schedule loading after frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImage();
    });
  }

  Future<void> _loadImage() async {
    if (_isLoading || !mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = await _getImageFile();
      if (mounted) {
        setState(() {
          _imageFile = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      widget.logger.error('Error loading image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<File?> _getImageFile() async {
    // If cache disabled, always download
    if (widget.cacheDisabled) {
      return await _downloadImage(saveToCache: false);
    }

    // Check if already downloading
    if (widget.cacheManager.isDownloading(widget.cacheKey)) {
      widget.logger.debug('Waiting for download: ${widget.cacheKey}');
      await widget.cacheManager.waitForDownload(widget.cacheKey);
      return await widget.cacheManager.getFile(widget.cacheKey);
    }

    // Try to get from cache
    final cachedFile = await widget.cacheManager.getFile(widget.cacheKey);
    if (cachedFile != null) {
      return cachedFile;
    }

    // Download and cache
    return await _downloadImage(saveToCache: true);
  }

  Future<File?> _downloadImage({required bool saveToCache}) async {
    widget.cacheManager.markDownloading(widget.cacheKey);
    
    try {
      widget.logger.debug('Downloading image: ${widget.cacheKey}');
      
      final response = await widget.dio.get(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final bytes = Uint8List.fromList(response.data);
      
      // Check if it's JSON error
      if (_isJsonError(bytes)) {
        final jsonStr = String.fromCharCodes(bytes);
        widget.logger.error('Server returned JSON error: $jsonStr');
        throw Exception('Server error: JSON response');
      }

      // Check if valid image
      if (!_isValidImageData(bytes)) {
        widget.logger.error('Invalid image data received');
        throw Exception('Invalid image data');
      }

      if (saveToCache) {
        await widget.cacheManager.putFile(widget.cacheKey, bytes, widget.imageUrl);
        return await widget.cacheManager.getFile(widget.cacheKey);
      } else {
        // Save to temp file
        final tempDir = await Directory.systemTemp.createTemp('sonic_img_');
        final tempFile = File('${tempDir.path}/image.tmp');
        await tempFile.writeAsBytes(bytes);
        return tempFile;
      }
    } catch (e) {
      widget.logger.error('Error downloading image: $e');
      return null;
    } finally {
      widget.cacheManager.unmarkDownloading(widget.cacheKey);
    }
  }

  bool _isJsonError(Uint8List data) {
    if (data.isEmpty) return false;
    if (data[0] != 0x7B) return false;
    
    try {
      final jsonStr = String.fromCharCodes(data);
      return jsonStr.contains('"error"') || jsonStr.contains('"status":"failed"');
    } catch (_) {
      return false;
    }
  }

  bool _isValidImageData(Uint8List data) {
    if (data.isEmpty) return false;
    
    // JPEG: FF D8 FF
    if (data.length >= 3 && 
        data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return true;
    }
    
    // PNG: 89 50 4E 47
    if (data.length >= 4 && 
        data[0] == 0x89 && data[1] == 0x50 && 
        data[2] == 0x4E && data[3] == 0x47) {
      return true;
    }
    
    // GIF: 47 49 46 38
    if (data.length >= 4 && 
        data[0] == 0x47 && data[1] == 0x49 && 
        data[2] == 0x46 && data[3] == 0x38) {
      return true;
    }
    
    // WebP
    if (data.length >= 12 && 
        data[0] == 0x52 && data[1] == 0x49 && 
        data[8] == 0x57 && data[9] == 0x45) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF2D3B4E),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.album, color: Colors.white54, size: 32),
            SizedBox(height: 4),
            Text('加载失败', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      );
    }

    if (_imageFile == null || _isLoading) {
      return widget.placeholder ?? Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF2D3B4E),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8DD6)),
          ),
        ),
      );
    }

    return Image.file(
      _imageFile!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        widget.logger.error('Error displaying image file: $error');
        return widget.errorWidget ?? Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFF2D3B4E),
          child: const Icon(Icons.album, color: Colors.white54, size: 32),
        );
      },
    );
  }
}
