import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/logger.dart';
import '../data/models/server_config.dart';
import '../data/services/subsonic/subsonic_api_client.dart';
import '../providers/server_configs_provider.dart';

/// Provider for health check service
final healthCheckServiceProvider = Provider<HealthCheckService>((ref) {
  return HealthCheckService(ref);
});

/// Service for checking server health status
class HealthCheckService {
  final Ref _ref;
  final Logger _logger = Logger('HealthCheckService');
  Timer? _healthCheckTimer;
  bool _isRunning = false;

  static const Duration _checkInterval = Duration(seconds: 30);

  HealthCheckService(this._ref);

  /// Start periodic health checks
  void startHealthChecks() {
    if (_isRunning) return;
    
    _isRunning = true;
    _logger.info('Starting health check service');
    
    // Perform initial check immediately
    _performHealthCheck();
    
    // Schedule periodic checks
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Stop health checks
  void stopHealthChecks() {
    _isRunning = false;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _logger.info('Stopped health check service');
  }

  /// Perform health check on all servers
  Future<void> _performHealthCheck() async {
    try {
      final configsNotifier = _ref.read(serverConfigsProvider.notifier);
      final servers = _ref.read(serverConfigsProvider).servers;
      
      if (servers.isEmpty) return;

      _logger.debug('Performing health check on ${servers.length} servers');

      for (final server in servers) {
        await _checkServerHealth(server, configsNotifier);
      }
    } catch (e) {
      _logger.error('Health check failed: $e');
    }
  }

  /// Check health of a single server
  Future<void> _checkServerHealth(
    ServerConfig server, 
    ServerConfigsNotifier configsNotifier
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Create a temporary API client for this server
      final apiClient = SubsonicApiClient();
      apiClient.setConfig(server);
      
      // Try to ping the server
      final isOnline = await apiClient.ping().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      
      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds;

      // Update server health status
      await configsNotifier.updateServerHealth(
        server.id, 
        isOnline, 
        isOnline ? responseTimeMs : null,
      );

      _logger.debug(
        'Health check for ${server.name}: ${isOnline ? 'ONLINE' : 'OFFLINE'} '
        '(${responseTimeMs}ms)'
      );
    } catch (e) {
      stopwatch.stop();
      
      // Mark as offline on error
      await configsNotifier.updateServerHealth(server.id, false, null);
      
      _logger.warning('Health check failed for ${server.name}: $e');
    }
  }

  /// Manually check a specific server's health
  Future<bool> checkServer(String serverId) async {
    try {
      final configsNotifier = _ref.read(serverConfigsProvider.notifier);
      final servers = _ref.read(serverConfigsProvider).servers;
      
      final server = servers.firstWhere(
        (s) => s.id == serverId,
        orElse: () => throw Exception('Server not found: $serverId'),
      );

      await _checkServerHealth(server, configsNotifier);
      
      // Return the updated status
      final updatedServers = _ref.read(serverConfigsProvider).servers;
      final updatedServer = updatedServers.firstWhere((s) => s.id == serverId);
      return updatedServer.isOnline;
    } catch (e) {
      _logger.error('Manual health check failed: $e');
      return false;
    }
  }

  /// Check if the service is running
  bool get isRunning => _isRunning;

  /// Dispose the service
  void dispose() {
    stopHealthChecks();
  }
}
