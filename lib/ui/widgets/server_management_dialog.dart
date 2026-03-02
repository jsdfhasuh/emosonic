import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../data/models/server_config.dart';
import '../../providers/providers.dart';
import 'server_form_dialog.dart';
import 'server_switch_dialog.dart';

class ServerManagementDialog extends ConsumerWidget {
  const ServerManagementDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverConfigsProvider);
    final servers = serverState.servers;
    final activeServer = serverState.activeServer;
    final colorTheme = ref.watch(colorThemeProvider);

    return Dialog(
      backgroundColor: colorTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withAlpha(26)),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '服务器管理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: colorTheme.accentColor),
                    onPressed: () => _showAddServerDialog(context, ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Server list
            Flexible(
              child: servers.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无服务器配置',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: servers.length,
                      itemBuilder: (context, index) {
                        final server = servers[index];
                        final isActive = server.id == activeServer?.id;
                        return _buildServerItem(
                          context,
                          ref,
                          server,
                          isActive,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerItem(
    BuildContext context,
    WidgetRef ref,
    ServerConfig server,
    bool isActive,
  ) {
    final colorTheme = ref.watch(colorThemeProvider);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(13)),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: server.isOnline ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                server.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? colorTheme.accentColor : Colors.white,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorTheme.accentColor.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '使用中',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorTheme.accentColor,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          server.url,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withAlpha(153),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.white54),
              onPressed: () => _showEditServerDialog(context, ref, server),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, ref, server),
            ),
          ],
        ),
        onTap: () {
          if (!isActive) {
            _confirmSwitchServer(context, ref, server);
          }
        },
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const ServerFormDialog(),
    );
  }

  void _showEditServerDialog(BuildContext context, WidgetRef ref, ServerConfig server) {
    showDialog(
      context: context,
      builder: (context) => ServerFormDialog(server: server),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ServerConfig server) {
    final colorTheme = ref.read(colorThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorTheme.surfaceColor,
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器 "${server.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(serverConfigsProvider.notifier).removeServer(server.id);
              if (context.mounted) {
                Navigator.pop(context);
                showTopSnackBar(context, message: '服务器已删除');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmSwitchServer(BuildContext context, WidgetRef ref, ServerConfig server) {
    showDialog(
      context: context,
      builder: (context) => ServerSwitchDialog(
        serverName: server.name,
        onConfirm: () async {
          await ref.read(serverConfigsProvider.notifier).switchServer(server.id);
          if (context.mounted) {
            Navigator.pop(context);
            showTopSnackBar(context, message: '已切换到服务器: ${server.name}');
          }
        },
      ),
    );
  }
}
