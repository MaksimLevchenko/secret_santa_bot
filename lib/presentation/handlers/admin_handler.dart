import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/presentation/ui.dart';
import 'base_handler.dart';

class AdminHandler extends BaseHandler {
  AdminHandler({
    required super.service,
    required super.store,
    required super.adminId,
  });

  Future<void> openAdmin(Ctx ctx) async {
    if (!isAdmin(ctx)) {
      await ctx.reply('🚫 Доступ запрещен.');
      return;
    }

    final participantCount = service.list().length;
    final canDistribute = participantCount >= 3 && !service.state.distributed;

    final statusText =
        '🛠 Админ-панель\n\n'
        '👥 Участников: $participantCount${participantCount >= 3 ? ' ✅' : ' ❌ (нужно минимум 3)'}\n'
        '🎁 Распределено: ${service.state.distributed ? 'Да ✅' : 'Нет ❌'}\n\n'
        '${service.state.distributed
            ? '💡 Для повторного распределения сначала сбросьте результаты'
            : canDistribute
            ? '💡 Все готово для распределения!'
            : '💡 Недостаточно участников для распределения'}';

    try {
      await ctx.editMessageText(
        statusText,
        replyMarkup: UI.adminMenu(canDistribute: canDistribute),
      );
    } catch (_) {
      await ctx.reply(
        statusText,
        replyMarkup: UI.adminMenu(canDistribute: canDistribute),
      );
    }
  }
}
