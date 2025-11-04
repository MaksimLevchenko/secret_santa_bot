class UserId {
  final int value;
  const UserId(this.value);
  @override
  String toString() => value.toString();
  @override
  bool operator ==(Object other) => other is UserId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class Participant {
  final UserId id;
  final String name;
  final Set<UserId> blocked;
  final String wishlist;
  final UserId? assignedTo;

  const Participant({
    required this.id,
    required this.name,
    this.blocked = const {},
    this.wishlist = '',
    this.assignedTo,
  });

  Participant copyWith({
    String? name,
    Set<UserId>? blocked,
    String? wishlist,
    UserId? assignedTo,
  }) {
    return Participant(
      id: id,
      name: name ?? this.name,
      blocked: blocked ?? this.blocked,
      wishlist: wishlist ?? this.wishlist,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.value,
    'name': name,
    'blocked': blocked.map((e) => e.value).toList(),
    'wishlist': wishlist,
    'assignedTo': assignedTo?.value,
  };

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: UserId(json['id'] as int),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Безымянный',
      blocked: ((json['blocked'] as List?) ?? const [])
          .map((e) => UserId(e as int))
          .toSet(),
      wishlist: (json['wishlist'] as String?) ?? '',
      assignedTo: (json['assignedTo'] != null)
          ? UserId(json['assignedTo'] as int)
          : null,
    );
  }
}

class AppState {
  final Map<UserId, Participant> users;
  final bool distributed;
  final DateTime updatedAt;

  const AppState({
    required this.users,
    required this.distributed,
    required this.updatedAt,
  });

  factory AppState.empty() =>
      AppState(users: const {}, distributed: false, updatedAt: DateTime.now());

  AppState copyWith({
    Map<UserId, Participant>? users,
    bool? distributed,
    DateTime? updatedAt,
  }) {
    return AppState(
      users: users ?? this.users,
      distributed: distributed ?? this.distributed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'users': users.map((k, v) => MapEntry(k.value.toString(), v.toJson())),
    'distributed': distributed,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AppState.fromJson(Map<String, dynamic> json) {
    final raw = (json['users'] as Map?)?.cast<String, dynamic>() ?? {};
    final map = <UserId, Participant>{};
    for (final e in raw.entries) {
      map[UserId(int.parse(e.key))] = Participant.fromJson(
        (e.value as Map).cast<String, dynamic>(),
      );
    }
    return AppState(
      users: map,
      distributed: json['distributed'] as bool? ?? false,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
