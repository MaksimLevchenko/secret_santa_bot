import 'user_id.dart';
import 'participant.dart';

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
