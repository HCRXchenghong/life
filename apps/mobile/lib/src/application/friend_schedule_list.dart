import '../data/app_session_monitor.dart';
import '../data/share_poll_client.dart';
import '../domain/share/share_poll_models.dart';

abstract interface class FriendScheduleListSource {
  Future<List<ManagedSharePollSummary>> loadFriendSchedules();
}

class FriendScheduleListException implements Exception {
  const FriendScheduleListException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DaylinkFriendSchedules implements FriendScheduleListSource {
  const DaylinkFriendSchedules({
    required this.apiBaseUri,
    required this.accessToken,
  });

  final Uri apiBaseUri;
  final AccessTokenProvider accessToken;

  @override
  Future<List<ManagedSharePollSummary>> loadFriendSchedules() async {
    final token = await accessToken();
    if (token == null) {
      throw const FriendScheduleListException('登录已失效，请重新登录');
    }
    final client = SharePollClient(apiBaseUri: apiBaseUri, mobileToken: token);
    try {
      return await client.listManaged();
    } on ShareApiException catch (error) {
      if (error.statusCode == 401) {
        throw const FriendScheduleListException('登录已失效，请重新登录');
      }
      throw const FriendScheduleListException('暂时无法加载，请稍后重试');
    } on Object {
      throw const FriendScheduleListException('暂时无法加载，请稍后重试');
    } finally {
      client.close();
    }
  }
}
