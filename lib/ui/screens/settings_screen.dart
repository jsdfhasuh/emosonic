import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/cache/audio_cache_manager.dart';
import '../../providers/providers.dart';
import '../widgets/server_management_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // Server Status
          _buildSectionHeader('服务器状态'),
          _buildServerStatusCard(context, ref),
          
          // Transmission and Download
          _buildSectionHeader('传输与下载'),
          _buildSwitchTile(
            '移动网络播放',
            '允许使用移动数据流式播放音乐',
            true,
            (value) {},
          ),
          Consumer(
            builder: (context, ref, child) {
              final cacheEnabled = ref.watch(audioCacheEnabledProvider);
              return _buildSwitchTile(
                '边听边存',
                '播放时自动缓存到本地',
                cacheEnabled,
                (value) async {
                  await ref.read(audioCacheEnabledProvider.notifier).setEnabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已开启边听边存' : '已关闭边听边存',
                    );
                  }
                },
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final cachePlaybackEnabled = ref.watch(audioCachePlaybackEnabledProvider);
              return _buildSwitchTile(
                '使用缓存播放',
                '优先使用本地缓存文件播放（关闭则始终使用网络流）',
                cachePlaybackEnabled,
                (value) async {
                  await ref.read(audioCachePlaybackEnabledProvider.notifier).setEnabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已开启缓存播放' : '已关闭缓存播放，将使用网络流',
                    );
                  }
                },
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final cacheSize = ref.watch(audioCacheSizeProvider);
              return _buildListTile(
                '缓存限额',
                '${(cacheSize / 1024).toStringAsFixed(1)} GB',
                Icons.storage,
                () => _showCacheSizeDialog(context, ref, cacheSize),
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final cacheCoverEnabled = ref.watch(cacheCoverImageProvider);
              return _buildSwitchTile(
                '缓存歌曲封面',
                '同时缓存歌曲封面图片（占用额外空间）',
                cacheCoverEnabled,
                (value) async {
                  await ref.read(cacheCoverImageProvider.notifier).setEnabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已开启缓存封面' : '已关闭缓存封面',
                    );
                  }
                },
              );
            },
          ),
          _buildListTile(
            '音质选择',
            '自动 (根据网络调整)',
            Icons.high_quality,
            () {},
          ),

          // Window Close Behavior (Windows only)
          if (Platform.isWindows) ...[
            _buildSectionHeader('窗口行为'),
            Consumer(
              builder: (context, ref, child) {
                final closeBehavior = ref.watch(windowCloseBehaviorProvider);
                String behaviorText;
                switch (closeBehavior) {
                  case 'minimize':
                    behaviorText = '最小化到托盘';
                    break;
                  case 'exit':
                    behaviorText = '直接退出';
                    break;
                  case 'ask':
                  default:
                    behaviorText = '每次询问';
                    break;
                }
                return _buildListTile(
                  '关闭窗口时',
                  behaviorText,
                  Icons.close,
                  () => _showCloseBehaviorDialog(context, ref, closeBehavior),
                );
              },
            ),
          ],

          // Playback Control
          _buildSectionHeader('播放控制'),
          _buildSwitchTile(
            '循环播放',
            '播放完队列后自动重复',
            false,
            (value) {},
          ),
          Consumer(
            builder: (context, ref, child) {
              final autoResumeEnabled = ref.watch(autoResumePlaybackProvider);
              return _buildSwitchTile(
                '启动自动播放',
                '应用启动时继续上次播放',
                autoResumeEnabled,
                (value) async {
                  await ref
                      .read(autoResumePlaybackProvider.notifier)
                      .setEnabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已开启启动自动播放' : '已关闭启动自动播放',
                    );
                  }
                },
              );
            },
          ),
          _buildListTile(
            '定时停止',
            '未设置',
            Icons.timer,
            () {},
          ),
          _buildSwitchTile(
            '音量标准化',
            '统一不同歌曲的音量',
            true,
            (value) {},
          ),
          
          // System Integration
          _buildSectionHeader('系统集成'),
          _buildListTile(
            '个性化主题',
            '深海蓝',
            Icons.palette,
            () {},
          ),
          Consumer(
            builder: (context, ref, child) {
              final cacheStatsAsync = ref.watch(audioCacheStatsProvider);
              return cacheStatsAsync.when(
                data: (stats) => _buildListTile(
                  '存储空间管理',
                  '${stats['fileCount']} 首歌曲, ${stats['totalSizeMB']} MB',
                  Icons.folder,
                  () => _showCacheManagementDialog(context, ref),
                ),
                loading: () => _buildListTile(
                  '存储空间管理',
                  '加载中...',
                  Icons.folder,
                  () {},
                ),
                error: (_, __) => _buildListTile(
                  '存储空间管理',
                  '无法加载',
                  Icons.folder,
                  () {},
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final cacheDisabled = ref.watch(imageCacheDisabledProvider);
              return _buildSwitchTile(
                '不使用图片缓存',
                '每次从服务器重新加载图片',
                cacheDisabled,
                (value) async {
                  await ref.read(imageCacheDisabledProvider.notifier).setDisabled(value);
                  ImageCacheManager().setCacheDisabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已禁用图片缓存' : '已启用图片缓存',
                    );
                  }
                },
              );
            },
          ),
          _buildListTile(
            '清除图片缓存',
            '释放本地存储空间',
            Icons.image,
            () => _clearImageCache(context),
          ),
          
          // Account
          _buildSectionHeader('账户'),
          Consumer(
            builder: (context, ref, child) {
              final serverState = ref.watch(serverConfigsProvider);
              final activeServer = serverState.activeServer;
              final apiEndpoint = activeServer?.apiEndpoint ?? 'rest';
              
              return _buildListTile(
                '自定义 API 端点',
                '当前: $apiEndpoint',
                Icons.api,
                () => _showApiEndpointDialog(context, ref),
              );
            },
          ),
          _buildListTile(
            '查看日志',
            '查看应用运行日志',
            Icons.article,
            () => _showLogsDialog(context),
          ),
          _buildListTile(
            '日志等级',
            '当前: ${Logger.getLogLevel().name.toUpperCase()}',
            Icons.bug_report,
            () => _showLogLevelDialog(context),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                _showLogoutDialog(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(51),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('退出登录'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Version Info
          Center(
            child: Column(
              children: [
                Text(
                  'Sonic Player v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withAlpha(128),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
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
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B8DD6),
        ),
      ),
    );
  }

  Widget _buildServerStatusCard(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverConfigsProvider);
    final activeServer = serverState.activeServer;
    final serverCount = serverState.serverCount;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showServerManagementDialog(context, ref),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF2D3B4E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6B8DD6).withAlpha(51),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B8DD6).withAlpha(26),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: activeServer?.isOnline ?? false ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    activeServer?.isOnline ?? false ? '已连接' : '未连接',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$serverCount 个服务器',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                activeServer?.name ?? '未配置',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(179),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activeServer?.url ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(128),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '用户: ${activeServer?.username ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(128),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const ServerManagementDialog(),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withAlpha(153),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withAlpha(153),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF6B8DD6),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('确认退出'),
        content: const Text('确定要退出当前服务器连接吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(serverConfigsProvider.notifier).clearAllConfigs();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showLogsDialog(BuildContext context) async {
    final logPaths = await Logger.getLogPaths();
    String currentLog = '';
    String previousLog = '';
    
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
    
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('应用日志'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy current log button
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: '复制当前日志',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: currentLog));
                            if (context.mounted) {
                              showTopSnackBar(
                                context,
                                message: '当前日志已复制',
                              );
                            }
                          },
                        ),
                        // Copy previous log button
                        IconButton(
                          icon: const Icon(Icons.copy_all, size: 20),
                          tooltip: '复制上次日志',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: previousLog));
                            if (context.mounted) {
                              showTopSnackBar(
                                context,
                                message: '上次日志已复制',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('清空日志'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  void _clearImageCache(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('清除图片缓存'),
        content: const Text('确定要清除所有本地图片缓存吗？这将释放存储空间，但下次加载图片时需要重新下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await ImageCacheManager().clearCache();
              if (context.mounted) {
                Navigator.pop(context);
                showTopSnackBar(
                  context,
                  message: '图片缓存已清除',
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLogLevelDialog(BuildContext context) {
    final levels = [
      {'name': 'DEBUG', 'level': LogLevel.debug, 'desc': '最详细，包含所有调试信息'},
      {'name': 'INFO', 'level': LogLevel.info, 'desc': '一般信息，默认级别'},
      {'name': 'WARNING', 'level': LogLevel.warning, 'desc': '仅警告和错误'},
      {'name': 'ERROR', 'level': LogLevel.error, 'desc': '仅错误信息'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('设置日志等级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: levels.map((item) {
            final isSelected = Logger.getLogLevel() == item['level'];
            return ListTile(
              title: Text(
                item['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF6B8DD6) : Colors.white,
                ),
              ),
              subtitle: Text(
                item['desc'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(179),
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF6B8DD6))
                  : null,
              onTap: () async {
                await Logger.setLogLevel(item['level'] as LogLevel);
                if (context.mounted) {
                  Navigator.pop(context);
                  showTopSnackBar(
                    context,
                    message: '日志等级已设置为 ${item['name']}',
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showCacheSizeDialog(BuildContext context, WidgetRef ref, int currentSize) {
    final options = [512, 1024, 2048, 4096, 8192]; // 512MB to 8GB

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('选择缓存限额'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((size) {
            final isSelected = size == currentSize;
            return ListTile(
              title: Text(
                '${(size / 1024).toStringAsFixed(1)} GB',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF6B8DD6) : Colors.white,
                ),
              ),
              subtitle: Text(
                '$size MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(179),
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF6B8DD6))
                  : null,
              onTap: () async {
                await ref.read(audioCacheSizeProvider.notifier).setSize(size);
                if (context.mounted) {
                  Navigator.pop(context);
                  showTopSnackBar(
                    context,
                    message: '缓存限额已设置为 ${(size / 1024).toStringAsFixed(1)} GB',
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showCloseBehaviorDialog(BuildContext context, WidgetRef ref, String currentBehavior) {
    final options = [
      {'value': 'ask', 'label': '每次询问', 'desc': '关闭时弹出确认对话框'},
      {'value': 'minimize', 'label': '最小化到托盘', 'desc': '直接最小化到系统托盘'},
      {'value': 'exit', 'label': '直接退出', 'desc': '直接退出应用'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('关闭窗口时'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final isSelected = option['value'] == currentBehavior;
            return ListTile(
              title: Text(
                option['label']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF6B8DD6) : Colors.white,
                ),
              ),
              subtitle: Text(
                option['desc']!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(179),
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF6B8DD6))
                  : null,
              onTap: () async {
                await ref.read(windowCloseBehaviorProvider.notifier).setBehavior(option['value']!);
                if (context.mounted) {
                  Navigator.pop(context);
                  showTopSnackBar(
                    context,
                    message: '关闭行为已设置为 ${option['label']}',
                  );
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showCacheManagementDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('存储空间管理'),
        content: Consumer(
          builder: (context, ref, child) {
            final cacheStatsAsync = ref.watch(audioCacheStatsProvider);
            return cacheStatsAsync.when(
              data: (stats) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已缓存歌曲: ${stats['fileCount']} 首'),
                  Text('占用空间: ${stats['totalSizeMB']} MB'),
                  Text('缓存限额: ${stats['maxSizeMB']} MB'),
                  const SizedBox(height: 16),
                  const Text(
                    '提示: 收藏的歌曲会保留更长时间 (90天)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('无法加载缓存信息'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('确认清空'),
                  content: const Text('确定要清空所有缓存的歌曲吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清空', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await AudioCacheManager().clearCache();
                ref.invalidate(audioCacheStatsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  showTopSnackBar(
                    context,
                    message: '缓存已清空',
                  );
                }
              }
            },
            child: const Text('清空缓存', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showApiEndpointDialog(BuildContext context, WidgetRef ref) {
    final serverState = ref.read(serverConfigsProvider);
    final activeServer = serverState.activeServer;
    
    if (activeServer == null) {
      showTopSnackBar(context, message: '请先配置服务器');
      return;
    }

    final controller = TextEditingController(text: activeServer.apiEndpoint);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('自定义 API 端点'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subsonic API 端点路径',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'rest',
                prefixText: '/',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '默认值为 "rest"，如果你的服务器使用不同的端点路径（如 "test"），请在此修改。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withAlpha(179),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newEndpoint = controller.text.trim();
              if (newEndpoint.isEmpty) {
                showTopSnackBar(context, message: '端点不能为空');
                return;
              }

              // Update server config with new endpoint
              final updatedConfig = activeServer.copyWith(apiEndpoint: newEndpoint);
              await ref.read(serverConfigsProvider.notifier).updateServer(activeServer.id, updatedConfig);
              
              // Update API client
              final apiClient = ref.read(apiClientProvider);
              apiClient.setConfig(updatedConfig);

              if (context.mounted) {
                Navigator.pop(context);
                showTopSnackBar(context, message: 'API 端点已更新为: $newEndpoint');
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
