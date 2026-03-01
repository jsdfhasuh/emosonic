import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_config.freezed.dart';
part 'server_config.g.dart';

@freezed
class ServerConfig with _$ServerConfig {
  const factory ServerConfig({
    required String id,
    required String name,
    required String url,
    required String username,
    required String password,
    @Default(false) bool isActive,
    DateTime? lastChecked,
    @Default(true) bool isOnline,
    int? responseTimeMs,
    @Default('rest') String apiEndpoint,
  }) = _ServerConfig;

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);
}
