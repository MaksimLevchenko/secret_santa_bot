import 'dart:math';
import 'package:secret_santa_bot/domain/models.dart';
import 'package:secret_santa_bot/domain/repositories.dart';

class SecretSantaServiceImpl implements SecretSantaService {
  AppState _state;

  SecretSantaServiceImpl(this._state);

  @override
  AppState get state => _state;

  @override
  Participant register(UserId id, String name) {
    final trimmed = name.trim().isEmpty ? 'Безымянный' : name.trim();
    final existing = _state.users[id];
    final updated =
        (existing?.copyWith(name: trimmed)) ??
        Participant(id: id, name: trimmed);
    final next = Map<UserId, Participant>.from(_state.users)..[id] = updated;
    _state = _state.copyWith(users: next);
    return updated;
  }

  @override
  Participant? find(UserId id) => _state.users[id];

  @override
  List<Participant> list() =>
      _state.users.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  @override
  void setWishlist(UserId id, String wishlist) {
    final u = _state.users[id];
    if (u == null) return;

    // ИСПРАВЛЕНО: Явно сохраняем все поля, включая assignedTo
    final nextU = u.copyWith(
      wishlist: wishlist.trim(),
      // Важно! Явно передаем assignedTo чтобы оно не стало null
      assignedTo: u.assignedTo,
      // Также сохраняем другие поля
      blocked: u.blocked,
    );

    final next = Map<UserId, Participant>.from(_state.users)..[id] = nextU;
    _state = _state.copyWith(users: next);
  }

  @override
  bool toggleBlock(UserId owner, UserId target) {
    if (owner == target) return false;
    final me = _state.users[owner];
    if (me == null || !_state.users.containsKey(target)) return false;
    final blocked = Set<UserId>.from(me.blocked);
    final nowBlocked = blocked.contains(target) ? false : true;
    if (nowBlocked) {
      blocked.add(target);
    } else {
      blocked.remove(target);
    }

    // ИСПРАВЛЕНО: Явно сохраняем assignedTo при изменении блок-листа
    final updated = me.copyWith(
      blocked: blocked,
      assignedTo: me.assignedTo, // Сохраняем назначение
    );

    final next = Map<UserId, Participant>.from(_state.users)..[owner] = updated;
    _state = _state.copyWith(users: next);
    return nowBlocked;
  }

  @override
  void resetAssignments() {
    final next = <UserId, Participant>{};
    for (final e in _state.users.entries) {
      // Сбрасываем только assignedTo, остальное сохраняем
      next[e.key] = e.value.copyWith(
        assignedTo: null,
        // Явно сохраняем остальные поля
        wishlist: e.value.wishlist,
        blocked: e.value.blocked,
      );
    }
    _state = _state.copyWith(users: next, distributed: false);
  }

  @override
  void resetAll() {
    _state = AppState.empty();
  }

  @override
  bool distribute({int maxAttempts = 2000}) {
    final users = list();
    if (users.length < 3) return false;

    final ids = users.map((e) => e.id).toList();
    final rng = Random();

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      ids.shuffle(rng);
      var valid = true;

      for (int i = 0; i < ids.length; i++) {
        final giver = _state.users[ids[i]]!;
        final receiverId = ids[(i + 1) % ids.length];
        if (giver.id == receiverId || giver.blocked.contains(receiverId)) {
          valid = false;
          break;
        }
      }
      if (!valid) continue;

      final next = <UserId, Participant>{};
      for (int i = 0; i < ids.length; i++) {
        final giver = _state.users[ids[i]]!;
        final receiverId = ids[(i + 1) % ids.length];

        // ИСПРАВЛЕНО: Явно сохраняем все поля при назначении
        next[giver.id] = giver.copyWith(
          assignedTo: receiverId,
          wishlist: giver.wishlist, // Сохраняем вишлист
          blocked: giver.blocked, // Сохраняем блок-лист
        );
      }
      _state = _state.copyWith(
        users: {..._state.users, ...next},
        distributed: true,
      );
      return true;
    }
    return false;
  }

  void updateState(AppState newState) {
    _state = newState;
  }
}
