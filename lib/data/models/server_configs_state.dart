import 'package:freezed_annotation/freezed_annotation.dart';
import 'server_config.dart';

part 'server_configs_state.freezed.dart';

@freezed
class ServerConfigsState with _$ServerConfigsState {
  const factory ServerConfigsState({
    @Default([]) List<ServerConfig> servers,
    ServerConfig? activeServer,
    @Default(false) bool isLoading,
    String? error,
    DateTime? lastHealthCheck,
  }) = _ServerConfigsState;

  const ServerConfigsState._();

  /// Get the number of servers
  int get serverCount => servers.length;

  /// Check if there are any servers configured
  bool get hasServers => servers.isNotEmpty;

  /// Get online servers count
  int get onlineServersCount => servers.where((s) => s.isOnline).length;

  /// Get offline servers count
  int get offlineServersCount => servers.where((s) => !s.isOnline).length;
}
