import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/domain/models.dart';
import 'package:secret_santa_bot/domain/repositories.dart';
import 'package:secret_santa_bot/app/secret_santa_service.dart';

typedef Ctx = Context;

abstract class BaseHandler {
  final SecretSantaServiceImpl service;
  final StateStore store;
  final int adminId;

  BaseHandler({
    required this.service,
    required this.store,
    required this.adminId,
  });

  bool isAdmin(Ctx ctx) => (ctx.from?.id ?? 0) == adminId;

  Future<void> saveState() async {
    await store.save(service.state);
  }

  Future<int> notifyAllParticipants(Ctx ctx, String message) async {
    int successCount = 0;

    for (final participant in service.list()) {
      try {
        await ctx.api.sendMessage(ChatID(participant.id.value), message);
        successCount++;
      } catch (e) {
        print(
          '❌ Не удалось отправить сообщение пользователю ${participant.name} (${participant.id.value}): $e',
        );
      }
    }

    return successCount;
  }
}
