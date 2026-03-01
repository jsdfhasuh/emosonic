import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/encryption_service.dart';
import '../core/utils/logger.dart';
import '../data/models/server_config.dart';
import '../data/models/server_configs_state.dart';



/// Provider for server configurations management
final serverConfigsProvider = StateNotifierProvider<ServerConfigsNotifier, ServerConfigsState>((ref) {
  return ServerConfigsNotifier(ref);
});

/// Provider to get the active server
final activeServerProvider = Provider<ServerConfig?>((ref) {
  return ref.watch(serverConfigsProvider).activeServer;
});

/// Provider to check if a specific server is active
final isServerActiveProvider = Provider.family<bool, String>((ref, serverId) {
  final activeServer = ref.watch(activeServerProvider);
  return activeServer?.id == serverId;
});

class ServerConfigsNotifier extends StateNotifier<ServerConfigsState> {
  final Logger _logger = Logger('ServerConfigsNotifier');
  final _uuid = const Uuid();
  EncryptionService? _encryptionService;

  static const String _serversStorageKey = 'server_configs';
  static const String _activeServerIdKey = 'active_server_id';

  ServerConfigsNotifier(Ref ref) : super(const ServerConfigsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    _encryptionService = await EncryptionService.getInstance();
    await _loadConfigs();
  }

  /// Load server configurations from storage
  Future<void> _loadConfigs() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final prefs = await SharedPreferences.getInstance();
      final serversJson = prefs.getString(_serversStorageKey);
      final activeServerId = prefs.getString(_activeServerIdKey);

      if (serversJson != null) {
        final List<dynamic> decoded = jsonDecode(serversJson);
        final servers = decoded.map((json) {
          // Handle password decryption
          if (json['password'] != null && _encryptionService != null) {
            final pwd = json['password'];
            
            // Check if it's the new format (ENCv2:)
            if (_encryptionService!.isEncrypted(pwd)) {
              try {
                json['password'] = _encryptionService!.decryptString(pwd);
              } catch (e) {
                _logger.warning('Failed to decrypt password for server ${json['name']}: $e');
                // Keep encrypted value - will need re-entry
              }
            } else if (_encryptionService!.isOldFormat(pwd)) {
              // Old format detected - mark for re-entry
              _logger.info('Old encryption format detected for server ${json['name']}, password needs re-entry');
              // Keep the old value but it won't work - user will need to edit and re-save
            }
            // If plaintext, keep as is
          }
          return ServerConfig.fromJson(json);
        }).toList();

        ServerConfig? activeServer;
        if (activeServerId != null) {
          try {
            activeServer = servers.firstWhere(
              (s) => s.id == activeServerId,
            );
          } catch (e) {
            activeServer = servers.isNotEmpty ? servers.first : null;
          }
        } else if (servers.isNotEmpty) {
          activeServer = servers.first;
        }

        // Ensure only one server is marked as active
        final updatedServers = servers.map((s) => 
          s.copyWith(isActive: s.id == activeServer?.id)
        ).toList();

        state = state.copyWith(
          servers: updatedServers,
          activeServer: activeServer,
          isLoading: false,
        );

        _logger.info('Loaded ${servers.length} server configurations');
      } else {
        // Check for legacy single server config and migrate
        await _migrateLegacyConfig();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to load server configs: $e, $stackTrace');
      state = state.copyWith(
        isLoading: false,
        error: '加载服务器配置失败: $e',
      );
    }
  }

  /// Migrate legacy single server configuration to multi-server format
  Future<void> _migrateLegacyConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('server_url');
      final username = prefs.getString('server_username');
      final password = prefs.getString('server_password');

      if (url != null && username != null && password != null) {
        _logger.info('Migrating legacy server configuration');
        
        final server = ServerConfig(
          id: _uuid.v4(),
          name: '主服务器',
          url: url,
          username: username,
          password: password,
          isActive: true,
        );

        await addServer(server);
        
        // Clear legacy config
        await prefs.remove('server_url');
        await prefs.remove('server_username');
        await prefs.remove('server_password');
        
        _logger.info('Legacy configuration migrated successfully');
      }
    } catch (e) {
      _logger.error('Failed to migrate legacy config: $e');
    }
  }

  /// Save server configurations to storage
  Future<void> _saveConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Encrypt passwords before saving
      final serversToSave = state.servers.map((server) {
        final json = server.toJson();
        if (_encryptionService != null) {
          try {
            // Only encrypt if not already encrypted with new format
            if (!_encryptionService!.isEncrypted(json['password'])) {
              json['password'] = _encryptionService!.encryptString(json['password']);
            }
          } catch (e) {
            _logger.warning('Failed to encrypt password for server ${server.name}: $e');
          }
        }
        return json;
      }).toList();

      await prefs.setString(_serversStorageKey, jsonEncode(serversToSave));
      
      if (state.activeServer != null) {
        await prefs.setString(_activeServerIdKey, state.activeServer!.id);
      }

      _logger.debug('Saved ${state.servers.length} server configurations');
    } catch (e, stackTrace) {
      _logger.error('Failed to save server configs: $e, $stackTrace');
      throw Exception('保存服务器配置失败: $e');
    }
  }

  /// Add a new server
  Future<void> addServer(ServerConfig config) async {
    try {
      // Generate ID if not provided
      final server = config.id.isEmpty 
        ? config.copyWith(id: _uuid.v4())
        : config;

      // If this is the first server, make it active
      final isFirstServer = state.servers.isEmpty;
      final serverToAdd = isFirstServer 
        ? server.copyWith(isActive: true)
        : server;

      final updatedServers = [...state.servers, serverToAdd];
      
      state = state.copyWith(
        servers: updatedServers,
        activeServer: isFirstServer ? serverToAdd : state.activeServer,
      );

      await _saveConfigs();
      _logger.info('Added server: ${serverToAdd.name}');
    } catch (e) {
      _logger.error('Failed to add server: $e');
      rethrow;
    }
  }

  /// Update an existing server
  Future<void> updateServer(String id, ServerConfig config) async {
    try {
      final index = state.servers.indexWhere((s) => s.id == id);
      if (index == -1) {
        throw Exception('Server not found: $id');
      }

      final updatedServers = [...state.servers];
      updatedServers[index] = config;

      state = state.copyWith(
        servers: updatedServers,
        activeServer: state.activeServer?.id == id ? config : state.activeServer,
      );

      await _saveConfigs();
      _logger.info('Updated server: ${config.name}');
    } catch (e) {
      _logger.error('Failed to update server: $e');
      rethrow;
    }
  }

  /// Remove a server
  Future<void> removeServer(String id) async {
    try {
      final serverToRemove = state.servers.firstWhere((s) => s.id == id);
      final updatedServers = state.servers.where((s) => s.id != id).toList();

      ServerConfig? newActiveServer = state.activeServer;
      
      // If removing the active server, set a new one
      if (state.activeServer?.id == id) {
        newActiveServer = updatedServers.isNotEmpty ? updatedServers.first : null;
        if (newActiveServer != null) {
          final activeIndex = updatedServers.indexWhere((s) => s.id == newActiveServer!.id);
          updatedServers[activeIndex] = newActiveServer.copyWith(isActive: true);
        }
      }

      state = state.copyWith(
        servers: updatedServers,
        activeServer: newActiveServer,
      );

      await _saveConfigs();
      _logger.info('Removed server: ${serverToRemove.name}');
    } catch (e) {
      _logger.error('Failed to remove server: $e');
      rethrow;
    }
  }

  /// Set active server
  Future<void> setActiveServer(String id) async {
    try {
      final server = state.servers.firstWhere(
        (s) => s.id == id,
        orElse: () => throw Exception('Server not found: $id'),
      );
      // Update isActive flag for all servers
      final updatedServers = state.servers.map((s) => 
        s.copyWith(isActive: s.id == id)
      ).toList();

      state = state.copyWith(
        servers: updatedServers,
        activeServer: server.copyWith(isActive: true),
      );

      await _saveConfigs();

      _logger.info('Set active server: ${server.name}');
    } catch (e) {
      _logger.error('Failed to set active server: $e');
      rethrow;
    }
  }

  /// Switch to a different server
  /// Note: Callers should handle playback cleanup (stop and clear queue) before calling this
  Future<void> switchServer(String id) async {
    try {
      _logger.info('Switching to server: $id');

      // Set new active server
      await setActiveServer(id);

      _logger.info('Server switch completed');
    } catch (e) {
      _logger.error('Failed to switch server: $e');
      rethrow;
    }
  }

  /// Get active server
  ServerConfig? getActiveServer() {
    return state.activeServer;
  }

  /// Update server health status
  Future<void> updateServerHealth(String id, bool isOnline, int? responseTimeMs) async {
    try {
      final index = state.servers.indexWhere((s) => s.id == id);
      if (index == -1) return;

      final updatedServers = [...state.servers];
      updatedServers[index] = state.servers[index].copyWith(
        isOnline: isOnline,
        responseTimeMs: responseTimeMs,
        lastChecked: DateTime.now(),
      );

      state = state.copyWith(
        servers: updatedServers,
        lastHealthCheck: DateTime.now(),
        activeServer: state.activeServer?.id == id 
          ? updatedServers[index] 
          : state.activeServer,
      );

      await _saveConfigs();
    } catch (e) {
      _logger.error('Failed to update server health: $e');
    }
  }

  /// Clear all configurations
  Future<void> clearAllConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_serversStorageKey);
      await prefs.remove(_activeServerIdKey);

      state = const ServerConfigsState();

      _logger.info('All server configurations cleared');
    } catch (e) {
      _logger.error('Failed to clear configs: $e');
      rethrow;
    }
  }
}
