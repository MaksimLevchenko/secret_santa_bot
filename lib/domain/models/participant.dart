import 'user_id.dart';

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
