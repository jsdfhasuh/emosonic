import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../data/models/server_config.dart';
import '../../data/services/subsonic/subsonic_api_client.dart';
import '../../providers/providers.dart';

class ServerFormDialog extends ConsumerStatefulWidget {
  final ServerConfig? server;

  const ServerFormDialog({super.key, this.server});

  @override
  ConsumerState<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends ConsumerState<ServerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.server != null) {
      _nameController.text = widget.server!.name;
      _urlController.text = widget.server!.url;
      _usernameController.text = widget.server!.username;
      _passwordController.text = widget.server!.password;
      debugPrint('[DEBUG] ServerFormDialog.initState: server=${widget.server!.name}, password=${widget.server!.password}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.server != null;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? '编辑服务器' : '添加服务器',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '服务器名称',
                  hintText: '例如：家庭服务器',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入服务器名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: '例如：https://music.example.com',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入服务器地址';
                  }
                  if (!value.startsWith('http://') && !value.startsWith('https://')) {
                    return '地址必须以 http:// 或 https:// 开头';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    TextButton(
                      onPressed: _testConnection,
                      child: const Text('测试连接'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saveServer,
                      child: Text(isEditing ? '保存' : '添加'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = SubsonicApiClient();
      final config = ServerConfig(
        id: widget.server?.id ?? '',
        name: _nameController.text,
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      apiClient.setConfig(config);

      final success = await apiClient.ping().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        showTopSnackBar(
          context,
          message: success ? '连接成功' : '连接失败',
          backgroundColor: success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopSnackBar(
          context,
          message: '连接测试失败: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = ServerConfig(
        id: widget.server?.id ?? '',
        name: _nameController.text,
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        isActive: widget.server?.isActive ?? false,
      );

      if (widget.server != null) {
        await ref.read(serverConfigsProvider.notifier).updateServer(
          widget.server!.id,
          config,
        );
      } else {
        await ref.read(serverConfigsProvider.notifier).addServer(config);
      }

      if (mounted) {
        Navigator.pop(context);
        showTopSnackBar(
          context,
          message: widget.server != null ? '服务器已更新' : '服务器已添加',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopSnackBar(
          context,
          message: '保存失败: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }
}
