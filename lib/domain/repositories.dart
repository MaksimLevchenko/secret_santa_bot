import 'models.dart';

abstract interface class StateStore {
  Future<AppState> load();
  Future<void> save(AppState state);
}

abstract interface class SecretSantaService {
  AppState get state;

  Participant register(UserId id, String name);
  Participant? find(UserId id);
  List<Participant> list();

  void setWishlist(UserId id, String wishlist);
  bool toggleBlock(UserId owner, UserId target); // true = теперь заблокирован
  void resetAssignments();
  void resetAll();

  bool distribute({int maxAttempts = 2000});
}
