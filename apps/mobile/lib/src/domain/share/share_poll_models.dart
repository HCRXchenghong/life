enum SharePollStatus { open, closed, cancelled, expired }

enum ShareVoteResponse { yes, maybe, no }

class SharePollSlotDraft {
  const SharePollSlotDraft({
    required this.startsAtUtc,
    required this.endsAtUtc,
    this.label = '',
  });

  final String label;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;

  void validate() {
    final starts = startsAtUtc.toUtc();
    final ends = endsAtUtc.toUtc();
    final duration = ends.difference(starts);
    if (!ends.isAfter(starts) ||
        duration < const Duration(minutes: 5) ||
        duration > const Duration(hours: 24) ||
        starts.millisecondsSinceEpoch %
                const Duration(minutes: 5).inMilliseconds !=
            0 ||
        ends.millisecondsSinceEpoch %
                const Duration(minutes: 5).inMilliseconds !=
            0) {
      throw ArgumentError('poll time range is invalid');
    }
    if (label.length > 120) throw ArgumentError('poll slot label is too long');
  }

  Map<String, Object?> toJson() => {
    'label': label,
    'startsAt': startsAtUtc.toUtc().toIso8601String(),
    'endsAt': endsAtUtc.toUtc().toIso8601String(),
  };
}

class CreateSharePollDraft {
  const CreateSharePollDraft({
    required this.title,
    required this.timezoneId,
    required this.slots,
    this.description = '',
    this.closesAtUtc,
  });

  final String title;
  final String description;
  final String timezoneId;
  final DateTime? closesAtUtc;
  final List<SharePollSlotDraft> slots;

  void validate() {
    if (title.trim().isEmpty || title.length > 160) {
      throw ArgumentError('poll title must contain 1-160 characters');
    }
    if (description.length > 2000) {
      throw ArgumentError('poll description is too long');
    }
    if (timezoneId.isEmpty || timezoneId.length > 80) {
      throw ArgumentError('poll timezone is invalid');
    }
    if (slots.isEmpty || slots.length > 30) {
      throw ArgumentError('poll must contain 1-30 time ranges');
    }
    final identities = <String>{};
    for (final slot in slots) {
      slot.validate();
      final identity =
          '${slot.startsAtUtc.toUtc().toIso8601String()}/${slot.endsAtUtc.toUtc().toIso8601String()}';
      if (!identities.add(identity)) {
        throw ArgumentError('poll slots must be unique');
      }
    }
    final sorted = [...slots]
      ..sort((left, right) => left.startsAtUtc.compareTo(right.startsAtUtc));
    for (var index = 1; index < sorted.length; index++) {
      if (sorted[index - 1].endsAtUtc.isAfter(sorted[index].startsAtUtc)) {
        throw ArgumentError('poll time ranges must not overlap');
      }
    }
    if (closesAtUtc != null &&
        !closesAtUtc!.toUtc().isBefore(sorted.first.startsAtUtc.toUtc())) {
      throw ArgumentError('poll deadline must be before time ranges');
    }
  }

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'description': description,
    'timezone': timezoneId,
    'closesAt': closesAtUtc?.toUtc().toIso8601String(),
    'slots': slots.map((slot) => slot.toJson()).toList(growable: false),
  };
}

class SharePollSlot {
  const SharePollSlot({
    required this.id,
    required this.startsAtUtc,
    required this.endsAtUtc,
    this.label = '',
  });

  final String id;
  final String label;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;

  factory SharePollSlot.fromJson(Map<String, Object?> json) => SharePollSlot(
    id: _requiredString(json, 'id'),
    label: json['label'] as String? ?? '',
    startsAtUtc: DateTime.parse(_requiredString(json, 'startsAt')).toUtc(),
    endsAtUtc: DateTime.parse(_requiredString(json, 'endsAt')).toUtc(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'startsAt': startsAtUtc.toIso8601String(),
    'endsAt': endsAtUtc.toIso8601String(),
  };
}

class SharePollSummary {
  const SharePollSummary({
    required this.id,
    required this.title,
    required this.timezoneId,
    required this.status,
    required this.version,
    this.description = '',
    this.closesAtUtc,
    this.selectedSlotId,
  });

  final String id;
  final String title;
  final String description;
  final String timezoneId;
  final SharePollStatus status;
  final int version;
  final DateTime? closesAtUtc;
  final String? selectedSlotId;

  factory SharePollSummary.fromJson(Map<String, Object?> json) =>
      SharePollSummary(
        id: _requiredString(json, 'id'),
        title: _requiredString(json, 'title'),
        description: json['description'] as String? ?? '',
        timezoneId: _requiredString(json, 'timezone'),
        status: SharePollStatus.values.byName(_requiredString(json, 'status')),
        version: _requiredInt(json, 'version'),
        closesAtUtc: json['closesAt'] == null
            ? null
            : DateTime.parse(json['closesAt']! as String).toUtc(),
        selectedSlotId: json['selectedSlotId'] as String?,
      );
}

class ManagedSharePollSummary {
  const ManagedSharePollSummary({
    required this.id,
    required this.title,
    required this.timezoneId,
    required this.status,
    required this.version,
    required this.candidateCount,
    required this.participantCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.closesAtUtc,
    this.selectedSlot,
  });

  final String id;
  final String title;
  final String timezoneId;
  final SharePollStatus status;
  final int version;
  final int candidateCount;
  final int participantCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? closesAtUtc;
  final SharePollSlot? selectedSlot;

  factory ManagedSharePollSummary.fromJson(
    Map<String, Object?> json,
  ) => ManagedSharePollSummary(
    id: _requiredString(json, 'id'),
    title: _requiredString(json, 'title'),
    timezoneId: _requiredString(json, 'timezone'),
    status: SharePollStatus.values.byName(_requiredString(json, 'status')),
    version: _requiredInt(json, 'version'),
    candidateCount: _requiredInt(json, 'candidateCount'),
    participantCount: _requiredInt(json, 'participantCount'),
    createdAtUtc: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    updatedAtUtc: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    closesAtUtc: json['closesAt'] == null
        ? null
        : DateTime.parse(json['closesAt']! as String).toUtc(),
    selectedSlot: json['selectedSlot'] == null
        ? null
        : SharePollSlot.fromJson(
            _objectMap(json['selectedSlot'], 'selectedSlot'),
          ),
  );
}

class SharePollParticipant {
  const SharePollParticipant({required this.id, required this.displayName});

  final String id;
  final String displayName;

  factory SharePollParticipant.fromJson(Map<String, Object?> json) =>
      SharePollParticipant(
        id: _requiredString(json, 'id'),
        displayName: _requiredString(json, 'displayName'),
      );
}

class SharePollVote {
  const SharePollVote({
    required this.participantId,
    required this.slotId,
    required this.response,
  });

  final String participantId;
  final String slotId;
  final ShareVoteResponse response;

  factory SharePollVote.fromJson(Map<String, Object?> json) => SharePollVote(
    participantId: _requiredString(json, 'participantId'),
    slotId: _requiredString(json, 'slotId'),
    response: ShareVoteResponse.values.byName(
      _requiredString(json, 'response'),
    ),
  );
}

class SharePollState {
  const SharePollState({
    required this.poll,
    required this.slots,
    required this.participants,
    required this.votes,
  });

  final SharePollSummary poll;
  final List<SharePollSlot> slots;
  final List<SharePollParticipant> participants;
  final List<SharePollVote> votes;

  SharePollSlot? get selectedSlot {
    final selectedId = poll.selectedSlotId;
    if (selectedId == null) return null;
    for (final slot in slots) {
      if (slot.id == selectedId) return slot;
    }
    return null;
  }

  factory SharePollState.fromJson(Map<String, Object?> json) => SharePollState(
    poll: SharePollSummary.fromJson(_requiredMap(json, 'poll')),
    slots: _requiredList(json, 'slots')
        .map((value) => SharePollSlot.fromJson(_objectMap(value, 'slot')))
        .toList(growable: false),
    participants: _requiredList(json, 'participants')
        .map(
          (value) =>
              SharePollParticipant.fromJson(_objectMap(value, 'participant')),
        )
        .toList(growable: false),
    votes: _requiredList(json, 'votes')
        .map((value) => SharePollVote.fromJson(_objectMap(value, 'vote')))
        .toList(growable: false),
  );
}

class CreatedSharePoll {
  const CreatedSharePoll({
    required this.pollId,
    required this.publicToken,
    required this.manageToken,
    required this.inviteUrl,
    required this.status,
    required this.version,
    required this.draft,
  });

  final String pollId;
  final String publicToken;
  final String manageToken;
  final Uri inviteUrl;
  final SharePollStatus status;
  final int version;
  final CreateSharePollDraft draft;
}

class FinalizedSharePoll {
  const FinalizedSharePoll({
    required this.pollId,
    required this.version,
    required this.selectedSlot,
  });

  final String pollId;
  final int version;
  final SharePollSlot selectedSlot;
}

enum FriendInviteStatus { pending, submitted, revoked }

class FriendTimeSelection {
  const FriendTimeSelection({
    required this.startsAtUtc,
    required this.endsAtUtc,
    this.id = '',
  });

  final String id;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;

  factory FriendTimeSelection.fromJson(Map<String, Object?> json) =>
      FriendTimeSelection(
        id: json['id'] as String? ?? '',
        startsAtUtc: DateTime.parse(_requiredString(json, 'startsAt')).toUtc(),
        endsAtUtc: DateTime.parse(_requiredString(json, 'endsAt')).toUtc(),
      );
}

class FriendPollInvite {
  const FriendPollInvite({
    required this.id,
    required this.displayName,
    required this.inviteUrl,
    required this.status,
    required this.selections,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.submittedAtUtc,
  });

  final String id;
  final String displayName;
  final Uri inviteUrl;
  final FriendInviteStatus status;
  final List<FriendTimeSelection> selections;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? submittedAtUtc;

  factory FriendPollInvite.fromJson(
    Map<String, Object?> json,
  ) => FriendPollInvite(
    id: _requiredString(json, 'id'),
    displayName: _requiredString(json, 'displayName'),
    inviteUrl: Uri.parse(_requiredString(json, 'inviteUrl')),
    status: FriendInviteStatus.values.byName(_requiredString(json, 'status')),
    selections: _requiredList(json, 'selections')
        .map(
          (value) =>
              FriendTimeSelection.fromJson(_objectMap(value, 'selection')),
        )
        .toList(growable: false),
    submittedAtUtc: json['submittedAt'] == null
        ? null
        : DateTime.parse(json['submittedAt']! as String).toUtc(),
    createdAtUtc: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    updatedAtUtc: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
  );
}

class FriendTimeSuggestion {
  const FriendTimeSuggestion({
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.peopleCount,
  });

  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final int peopleCount;

  factory FriendTimeSuggestion.fromJson(Map<String, Object?> json) =>
      FriendTimeSuggestion(
        startsAtUtc: DateTime.parse(_requiredString(json, 'startsAt')).toUtc(),
        endsAtUtc: DateTime.parse(_requiredString(json, 'endsAt')).toUtc(),
        peopleCount: _requiredInt(json, 'peopleCount'),
      );
}

class FriendPollDetails {
  const FriendPollDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.timezoneId,
    required this.status,
    required this.version,
    required this.ranges,
    required this.invites,
    required this.suggestions,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.closesAtUtc,
    this.selectedStartsAtUtc,
    this.selectedEndsAtUtc,
  });

  final String id;
  final String title;
  final String description;
  final String timezoneId;
  final SharePollStatus status;
  final int version;
  final List<SharePollSlot> ranges;
  final List<FriendPollInvite> invites;
  final List<FriendTimeSuggestion> suggestions;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? closesAtUtc;
  final DateTime? selectedStartsAtUtc;
  final DateTime? selectedEndsAtUtc;

  factory FriendPollDetails.fromJson(Map<String, Object?> json) {
    final poll = _requiredMap(json, 'poll');
    return FriendPollDetails(
      id: _requiredString(poll, 'id'),
      title: _requiredString(poll, 'title'),
      description: poll['description'] as String? ?? '',
      timezoneId: _requiredString(poll, 'timezone'),
      status: SharePollStatus.values.byName(_requiredString(poll, 'status')),
      version: _requiredInt(poll, 'version'),
      ranges: _requiredList(json, 'ranges')
          .map((value) => SharePollSlot.fromJson(_objectMap(value, 'range')))
          .toList(growable: false),
      invites: _requiredList(json, 'invites')
          .map(
            (value) => FriendPollInvite.fromJson(_objectMap(value, 'invite')),
          )
          .toList(growable: false),
      suggestions: _requiredList(json, 'suggestions')
          .map(
            (value) =>
                FriendTimeSuggestion.fromJson(_objectMap(value, 'suggestion')),
          )
          .toList(growable: false),
      closesAtUtc: _optionalDateTime(poll, 'closesAt'),
      selectedStartsAtUtc: _optionalDateTime(poll, 'selectedStartsAt'),
      selectedEndsAtUtc: _optionalDateTime(poll, 'selectedEndsAt'),
      createdAtUtc: DateTime.parse(_requiredString(poll, 'createdAt')).toUtc(),
      updatedAtUtc: DateTime.parse(_requiredString(poll, 'updatedAt')).toUtc(),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('response field $key must be a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('response field $key must be a number');
  }
  return value.toInt();
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  final value = json[key];
  return value == null ? null : DateTime.parse(value as String).toUtc();
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) =>
    _objectMap(json[key], key);

Map<String, Object?> _objectMap(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('response field $name must be an object');
  }
  return value;
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('response field $key must be an array');
  }
  return value;
}
