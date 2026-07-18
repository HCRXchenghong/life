import '../data/app_session_monitor.dart';
import '../data/share_poll_client.dart';
import '../domain/share/share_poll_models.dart';
import 'daylink_services.dart';

abstract interface class FriendScheduleListSource {
  Future<List<ManagedSharePollSummary>> loadFriendSchedules();
}

abstract interface class FriendScheduleCreationSource
    implements FriendScheduleListSource {
  Future<String> loadFriendScheduleTimezoneId();

  Future<void> createFriendSchedule(CreateSharePollDraft draft);
}

class FriendScheduleListException implements Exception {
  const FriendScheduleListException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DaylinkFriendSchedules implements FriendScheduleCreationSource {
  const DaylinkFriendSchedules({
    required this.services,
    required this.apiBaseUri,
    required this.accessToken,
    required this.refreshAccessToken,
  });

  final DaylinkServices services;
  final Uri apiBaseUri;
  final AccessTokenProvider accessToken;
  final SessionRefreshCallback refreshAccessToken;

  @override
  Future<String> loadFriendScheduleTimezoneId() =>
      services.notifications.localTimezoneIdentifier();

  @override
  Future<void> createFriendSchedule(CreateSharePollDraft draft) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requiredToken();
      final configured = services.configureShare(
        apiBaseUri: apiBaseUri,
        mobileToken: token,
      );
      try {
        await configured.coordinator.create(draft);
        return;
      } on ShareApiException catch (error) {
        if (error.statusCode == 401 && attempt == 0 && await _refreshOnce()) {
          continue;
        }
        if (error.statusCode == 401) {
          throw const FriendScheduleListException('登录已失效，请重新登录');
        }
        if (error.statusCode == 429) {
          throw const FriendScheduleListException('创建过于频繁，请稍后重试');
        }
        throw const FriendScheduleListException('暂时无法创建，请稍后重试');
      } on ArgumentError {
        throw const FriendScheduleListException('选时间内容不符合要求');
      } on FriendScheduleListException {
        rethrow;
      } on Object {
        throw const FriendScheduleListException('暂时无法创建，请稍后重试');
      } finally {
        configured.close();
      }
    }
  }

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await _requiredToken();
      final client = SharePollClient(
        apiBaseUri: apiBaseUri,
        mobileToken: token,
      );
      try {
        return await client.listManaged();
      } on ShareApiException catch (error) {
        if (error.statusCode == 401 && attempt == 0 && await _refreshOnce()) {
          continue;
        }
        if (error.statusCode == 401) {
          throw const FriendScheduleListException('登录已失效，请重新登录');
        }
        throw const FriendScheduleListException('暂时无法加载，请稍后重试');
      } on FriendScheduleListException {
        rethrow;
      } on Object {
        throw const FriendScheduleListException('暂时无法加载，请稍后重试');
      } finally {
        client.close();
      }
    }
    throw const FriendScheduleListException('暂时无法加载，请稍后重试');
  }

  Future<String> _requiredToken() async {
    final token = await accessToken();
    if (token == null) {
      throw const FriendScheduleListException('登录已失效，请重新登录');
    }
    return token;
  }

  Future<bool> _refreshOnce() async {
    try {
      return await refreshAccessToken();
    } on Object {
      return false;
    }
  }
}
