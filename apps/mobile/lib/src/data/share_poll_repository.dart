import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/share/share_poll_models.dart';
import 'app_database.dart';
import 'secret_vault.dart';

class LocalSharePollRef {
  const LocalSharePollRef({
    required this.id,
    required this.title,
    required this.inviteUrl,
    required this.publicToken,
    required this.timezoneId,
    required this.status,
    required this.version,
    required this.manageTokenSecretRef,
    this.selectedSlot,
  });

  final String id;
  final String title;
  final Uri inviteUrl;
  final String publicToken;
  final String timezoneId;
  final SharePollStatus status;
  final int version;
  final String manageTokenSecretRef;
  final SharePollSlot? selectedSlot;
}

class SharePollRepository {
  SharePollRepository(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  Future<LocalSharePollRef> saveCreated(CreatedSharePoll created) async {
    final secretRef = 'share-poll-manage:${created.pollId}';
    await _secrets.write(secretRef, created.manageToken);
    try {
      await _db
          .into(_db.sharePollRefs)
          .insertOnConflictUpdate(
            SharePollRefsCompanion.insert(
              id: created.pollId,
              title: created.draft.title.trim(),
              inviteUrl: created.inviteUrl.toString(),
              publicToken: Value(created.publicToken),
              timezoneId: Value(created.draft.timezoneId),
              manageTokenSecretRef: secretRef,
              status: created.status.name,
              version: Value(created.version),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
    } on Object {
      await _secrets.delete(secretRef);
      rethrow;
    }
    return LocalSharePollRef(
      id: created.pollId,
      title: created.draft.title.trim(),
      inviteUrl: created.inviteUrl,
      publicToken: created.publicToken,
      timezoneId: created.draft.timezoneId,
      status: created.status,
      version: created.version,
      manageTokenSecretRef: secretRef,
    );
  }

  Future<List<LocalSharePollRef>> list() async {
    final rows = await (_db.select(
      _db.sharePollRefs,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<LocalSharePollRef> get(String id) async {
    final row = await (_db.select(
      _db.sharePollRefs,
    )..where((table) => table.id.equals(id))).getSingle();
    return _fromRow(row);
  }

  Future<String> loadManageToken(LocalSharePollRef poll) async {
    final token = await _secrets.read(poll.manageTokenSecretRef);
    if (token == null) {
      throw StateError('share poll management token is missing');
    }
    return token;
  }

  Future<void> markFinalized(FinalizedSharePoll finalized) async {
    final changed =
        await (_db.update(
          _db.sharePollRefs,
        )..where((row) => row.id.equals(finalized.pollId))).write(
          SharePollRefsCompanion(
            status: Value(SharePollStatus.closed.name),
            version: Value(finalized.version),
            selectedSlotJson: Value(
              jsonEncode(finalized.selectedSlot.toJson()),
            ),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) throw StateError('local share poll reference not found');
  }

  LocalSharePollRef _fromRow(SharePollRef row) {
    final publicToken = row.publicToken ?? _tokenFromInviteUrl(row.inviteUrl);
    return LocalSharePollRef(
      id: row.id,
      title: row.title,
      inviteUrl: Uri.parse(row.inviteUrl),
      publicToken: publicToken,
      timezoneId: row.timezoneId,
      status: SharePollStatus.values.byName(row.status),
      version: row.version,
      manageTokenSecretRef: row.manageTokenSecretRef,
      selectedSlot: row.selectedSlotJson == null
          ? null
          : SharePollSlot.fromJson(
              jsonDecode(row.selectedSlotJson!) as Map<String, Object?>,
            ),
    );
  }
}

String _tokenFromInviteUrl(String value) {
  final uri = Uri.parse(value);
  if (uri.pathSegments.length < 2 ||
      uri.pathSegments[uri.pathSegments.length - 2] != 'poll') {
    throw const FormatException('stored poll invite URL has no public token');
  }
  return uri.pathSegments.last;
}
