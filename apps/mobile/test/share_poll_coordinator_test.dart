import 'dart:convert';

import 'package:daylink_mobile/src/application/share_poll_coordinator.dart';
import 'package:daylink_mobile/src/application/share_poll_tools.dart';
import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/schedule_repository.dart';
import 'package:daylink_mobile/src/data/secret_vault.dart';
import 'package:daylink_mobile/src/data/share_poll_client.dart';
import 'package:daylink_mobile/src/data/share_poll_repository.dart';
import 'package:daylink_mobile/src/domain/schedule/schedule_models.dart';
import 'package:daylink_mobile/src/domain/ai/tool_protocol.dart';
import 'package:daylink_mobile/src/domain/share/share_poll_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'create stores only the management token reference and finalizes once',
    () async {
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/polls') {
          expect(request.headers['authorization'], 'Bearer dlk_mobile');
          return http.Response(
            jsonEncode({
              'poll': {
                'id': 'poll-1',
                'publicToken': 'public_token_1234567890',
                'manageToken': 'manage_secret',
                'inviteUrl':
                    'https://daylink.example/poll/public_token_1234567890',
                'status': 'open',
                'version': 1,
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/finalize')) {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['expectedVersion'], 1);
          expect(body['manageToken'], 'manage_secret');
          return http.Response(
            jsonEncode({
              'pollId': 'poll-1',
              'version': 2,
              'selectedSlot': {
                'id': 'slot_123',
                'label': '午后',
                'startsAt': '2026-08-02T06:00:00.000Z',
                'endsAt': '2026-08-02T08:00:00.000Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      final secrets = _MemorySecrets();
      final pollRepository = SharePollRepository(database, secrets);
      final scheduleRepository = ScheduleRepository(database);
      var reconciliations = 0;
      final coordinator = SharePollCoordinator(
        client: SharePollClient(
          apiBaseUri: Uri.parse('https://daylink.example/api/'),
          mobileToken: 'dlk_mobile',
          httpClient: httpClient,
        ),
        polls: pollRepository,
        schedules: scheduleRepository,
        reconcileNotifications: () async => reconciliations++,
      );
      final poll = await coordinator.create(
        CreateSharePollDraft(
          title: '周末去露营',
          timezoneId: 'Asia/Shanghai',
          slots: [
            SharePollSlotDraft(
              startsAtUtc: DateTime.utc(2026, 8, 1, 2),
              endsAtUtc: DateTime.utc(2026, 8, 1, 4),
            ),
            SharePollSlotDraft(
              startsAtUtc: DateTime.utc(2026, 8, 2, 6),
              endsAtUtc: DateTime.utc(2026, 8, 2, 8),
            ),
          ],
        ),
      );

      expect(poll.publicToken, 'public_token_1234567890');
      expect(await secrets.read(poll.manageTokenSecretRef), 'manage_secret');
      expect((await pollRepository.list()).single.inviteUrl, poll.inviteUrl);

      final event = await coordinator.finalizeAndCreateSchedule(
        poll: poll,
        slotId: 'slot_123',
      );
      expect(event.source, ScheduleSource.sharePoll);
      expect(event.startsAtUtc, DateTime.utc(2026, 8, 2, 6));
      expect(event.duration, const Duration(hours: 2));
      expect(reconciliations, 1);
      expect((await pollRepository.get('poll-1')).version, 2);
      expect((await scheduleRepository.activeEvents()).single.id, event.id);
      expect(requests, hasLength(2));
    },
  );

  test('rejects insecure non-loopback share service URLs', () {
    expect(
      () => SharePollClient(
        apiBaseUri: Uri.parse('http://example.com/api/'),
        mobileToken: 'token',
      ),
      throwsArgumentError,
    );
  });

  test(
    'managed poll list is authenticated and parses aggregate counts',
    () async {
      final client = SharePollClient(
        apiBaseUri: Uri.parse('https://daylink.example/api/'),
        mobileToken: 'account-access-token',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/polls');
          expect(
            request.headers['authorization'],
            'Bearer account-access-token',
          );
          return http.Response(
            jsonEncode({
              'polls': [
                {
                  'id': 'poll-managed',
                  'title': '生日聚会',
                  'timezone': 'Asia/Shanghai',
                  'status': 'closed',
                  'closesAt': '2026-07-25T14:00:00Z',
                  'version': 2,
                  'candidateCount': 3,
                  'participantCount': 6,
                  'createdAt': '2026-07-18T02:00:00Z',
                  'updatedAt': '2026-07-18T03:00:00Z',
                  'selectedSlot': {
                    'id': 'slot-final',
                    'label': '',
                    'startsAt': '2026-07-26T10:30:00Z',
                    'endsAt': '2026-07-26T12:30:00Z',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);

      final polls = await client.listManaged();

      expect(polls, hasLength(1));
      expect(polls.single.title, '生日聚会');
      expect(polls.single.status, SharePollStatus.closed);
      expect(polls.single.candidateCount, 3);
      expect(polls.single.participantCount, 6);
      expect(polls.single.selectedSlot?.id, 'slot-final');
    },
  );

  test('AI poll listing never exposes the management token', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final secrets = _MemorySecrets();
    final repository = SharePollRepository(database, secrets);
    await repository.saveCreated(
      CreatedSharePoll(
        pollId: 'poll-safe',
        publicToken: 'public_token_1234567890',
        manageToken: 'never-show-this',
        inviteUrl: Uri.parse(
          'https://daylink.example/poll/public_token_1234567890',
        ),
        status: SharePollStatus.open,
        version: 1,
        draft: CreateSharePollDraft(
          title: '安全投票',
          timezoneId: 'Asia/Shanghai',
          slots: [
            SharePollSlotDraft(
              startsAtUtc: DateTime.utc(2026, 8, 1),
              endsAtUtc: DateTime.utc(2026, 8, 1, 1),
            ),
            SharePollSlotDraft(
              startsAtUtc: DateTime.utc(2026, 8, 2),
              endsAtUtc: DateTime.utc(2026, 8, 2, 1),
            ),
          ],
        ),
      ),
    );
    final unusedClient = SharePollClient(
      apiBaseUri: Uri.parse('https://daylink.example/api/'),
      mobileToken: 'mobile-token',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    final coordinator = SharePollCoordinator(
      client: unusedClient,
      polls: repository,
      schedules: ScheduleRepository(database),
      reconcileNotifications: () async {},
    );
    final registry = ToolRegistry(
      approvals: (_, _) async => ApprovalDecision.accept,
    );
    SharePollTools(
      coordinator: coordinator,
      repository: repository,
    ).register(registry);

    final result = await registry.invoke(
      const ToolCall(
        callId: 'poll-list',
        name: 'daylink_poll_list',
        arguments: {},
      ),
    );

    expect(result.success, isTrue);
    expect(result.output.toString(), isNot(contains('never-show-this')));
    expect(result.output.toString(), contains('安全投票'));
  });
}

class _MemorySecrets implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String reference) async => _values.remove(reference);

  @override
  Future<String?> read(String reference) async => _values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    _values[reference] = secret;
  }
}
