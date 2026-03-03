import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final Logger _logger = Logger('ServerConfigScreen');

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    _logger.info('Attempting to connect to server: $url');
    _logger.info('Username: $username');

    try {
      final config = ServerConfig(
        id: '',
        name: '主服务器',
        url: url,
        username: username,
        password: password,
      );

      _logger.info('Creating API client...');
      final apiClient = ref.read(apiClientProvider);
      apiClient.setConfig(config);
      _logger.info('API client configured successfully');

      _logger.info('Sending ping request...');
      final isConnected = await apiClient.ping();
      _logger.info('Ping result: $isConnected');

      if (isConnected) {
        _logger.info('Connection successful, saving config...');
        await ref.read(serverConfigsProvider.notifier).addServer(config);
        _logger.info('Config saved successfully');
      } else {
        _logger.error('Ping returned false - server rejected connection');
        setState(() {
          _errorMessage = '无法连接到服务器，请检查配置';
        });
      }
    } on DioException catch (e) {
      _logger.error('DioException during connection: ${e.message ?? "Unknown error"}');
      _logger.error('Request URL: ${e.requestOptions.uri.toString()}');
      _logger.error('Response status: ${e.response?.statusCode ?? "No response"}');
      _logger.error('Error type: ${e.type}');
      _logger.error('Error: ${e.error}');
      
      String errorMsg;
      if (e.type == DioExceptionType.connectionError) {
        errorMsg = '无法连接到服务器\n请检查：\n1. 服务器地址是否正确\n2. 网络连接是否正常\n3. 服务器是否运行';
      } else if (e.type == DioExceptionType.badResponse) {
        errorMsg = '服务器响应错误: ${e.response?.statusCode ?? "Unknown"}';
      } else if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        errorMsg = '连接超时，请检查网络';
      } else {
        errorMsg = '网络错误: ${e.message ?? "Unknown error"}';
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
    } catch (e, stackTrace) {
      _logger.error('Exception during connection: $e');
      _logger.error('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = '连接错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLogsDialog() async {
    final logPaths = await Logger.getLogPaths();
    String currentLog = '';
    String previousLog = '';
    final colorTheme = ref.read(colorThemeProvider);
    
    try {
      final currentFile = File(logPaths['current']!);
      if (await currentFile.exists()) {
        currentLog = await currentFile.readAsString();
      }
    } catch (e) {
      currentLog = '无法读取当前日志: $e';
    }
    
    try {
      final previousFile = File(logPaths['previous']!);
      if (await previousFile.exists()) {
        previousLog = await previousFile.readAsString();
      }
    } catch (e) {
      previousLog = '无法读取上次日志: $e';
    }
    
    final dialogContext = context;
    if (!dialogContext.mounted) return;
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorTheme.backgroundColor,
        title: const Text('应用日志'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '当前日志'),
                    Tab(text: '上次日志'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: SelectableText(
                          currentLog.isEmpty ? '暂无日志' : currentLog,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        child: SelectableText(
                          previousLog.isEmpty ? '暂无日志' : previousLog,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Logger.clearLogs();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('清空日志'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonic Player'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.article),
            tooltip: '查看日志',
            onPressed: _showLogsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '连接到 Subsonic 服务器',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'http://192.168.100.74:5000',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入服务器地址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testConnection,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              '连接',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Author info
                  Text(
                    'Made with ❤️ by cjh & kimi & opencode',
                    style: TextStyle(
                      color: Colors.white.withAlpha(128),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
