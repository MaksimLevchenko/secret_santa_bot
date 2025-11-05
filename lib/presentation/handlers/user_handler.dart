import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/domain/models.dart';
import 'package:secret_santa_bot/presentation/ui.dart';
import 'base_handler.dart';

class UserHandler extends BaseHandler {
  UserHandler({
    required super.service,
    required super.store,
    required super.adminId,
  });

  Future<void> start(Ctx ctx) async {
    final uid = ctx.from?.id;

    if (uid == null) {
      await ctx.reply('Не удалось получить ваш ID.');
      return;
    }

    final name = [
      ctx.from?.firstName ?? '',
      ctx.from?.lastName ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    final participant = service.register(
      UserId(uid),
      name.isEmpty ? 'Безымянный' : name,
    );
    await saveState();

    final isUserAdmin = isAdmin(ctx);
    final keyboard = UI.mainMenu(isAdmin: isUserAdmin);

    await ctx.reply(
      'Добро пожаловать, ${participant.name}! 🎅\n\nЭто бот для игры в Тайного Санту. Выберите действие:',
      replyMarkup: keyboard,
    );
  }

  Future<void> checkAdmin(Ctx ctx) async {
    final uid = ctx.from?.id;
    final isUserAdmin = isAdmin(ctx);
    await ctx.reply(
      '🔍 Информация о правах:\n\n'
      '👤 Ваш ID: $uid\n'
      '🔑 ID администратора: $adminId\n'
      '🛠 Права админа: ${isUserAdmin ? 'Да ✅' : 'Нет ❌'}\n\n'
      '${isUserAdmin ? 'У вас есть доступ к админ-панели!' : 'Вы обычный участник.'}',
    );
  }

  Future<void> showMyAssignment(Ctx ctx) async {
    final uid = ctx.from?.id;
    if (uid == null) {
      await ctx.reply('Ошибка ID.');
      return;
    }

    final me = service.find(UserId(uid));
    if (me == null) {
      await ctx.reply('Сначала нажмите /start для регистрации.');
      return;
    }

    final receiver = me.assignedTo != null
        ? service.find(me.assignedTo!)
        : null;

    final updateTime = DateTime.now();
    final timeString =
        '${updateTime.hour.toString().padLeft(2, '0')}:${updateTime.minute.toString().padLeft(2, '0')}:${updateTime.second.toString().padLeft(2, '0')}';

    final assignmentText = UI.formatMyAssignment(
      me,
      receiver,
      service.state.distributed,
      updateTime: timeString,
    );

    try {
      await ctx.editMessageText(
        assignmentText,
        replyMarkup: UI.assignmentKeyboard(),
      );
    } catch (e) {
      print('❌ Ошибка редактирования назначения: $e');
      await ctx.reply(assignmentText, replyMarkup: UI.assignmentKeyboard());
    }
  }

  Future<void> showMembers(Ctx ctx) async {
    final membersText = UI.formatMembers(service.list());

    try {
      await ctx.editMessageText(
        membersText,
        replyMarkup: UI.backOnlyKeyboard(),
      );
    } catch (_) {
      await ctx.reply(membersText, replyMarkup: UI.backOnlyKeyboard());
    }
  }

  Future<void> backMain(Ctx ctx) async {
    final isUserAdmin = isAdmin(ctx);

    try {
      await ctx.editMessageText(
        '🏠 Главное меню\n\nВыберите действие:',
        replyMarkup: UI.mainMenu(isAdmin: isUserAdmin),
      );
    } catch (_) {
      await ctx.reply(
        '🏠 Главное меню\n\nВыберите действие:',
        replyMarkup: UI.mainMenu(isAdmin: isUserAdmin),
      );
    }
  }
}
