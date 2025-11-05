import 'dart:io';
import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/domain/models.dart';
import 'package:secret_santa_bot/presentation/ui.dart';
import 'base_handler.dart';

class GameHandler extends BaseHandler {
  GameHandler({
    required super.service,
    required super.store,
    required super.adminId,
  });

  final Set<int> _waitingForWishlist = {};

  Future<void> openSettings(Ctx ctx) async {
    final uid = ctx.from?.id;
    if (uid == null || service.find(UserId(uid)) == null) {
      await ctx.reply('Сначала нажмите /start для регистрации.');
      return;
    }

    try {
      await ctx.editMessageText(
        '⚙️ Настройки\n\nВыберите раздел:',
        replyMarkup: UI.settingsMenu(),
      );
    } catch (_) {
      await ctx.reply(
        '⚙️ Настройки\n\nВыберите раздел:',
        replyMarkup: UI.settingsMenu(),
      );
    }
  }

  Future<void> wishlistFlow(Bot<Ctx> bot, Ctx ctx) async {
    final uid = ctx.from?.id;
    if (uid == null) {
      await ctx.reply('Ошибка ID.');
      return;
    }

    _waitingForWishlist.add(uid);

    try {
      await ctx.editMessageText(
        '📝 Вишлист\n\nОтправьте текст вашего вишлиста одним сообщением:\n\n💡 Чтобы отменить, нажмите "Отменить"',
        replyMarkup: UI.cancelKeyboard(),
      );
    } catch (_) {
      await ctx.reply(
        '📝 Вишлист\n\nОтправьте текст вашего вишлиста одним сообщением:\n\n💡 Чтобы отменить, нажмите "Отменить"',
        replyMarkup: UI.cancelKeyboard(),
      );
    }

    Future.delayed(Duration(minutes: 10), () {
      _waitingForWishlist.remove(uid);
    });
  }

  Future<void> handleTextMessage(Ctx ctx) async {
    final uid = ctx.from?.id;
    final text = ctx.text;

    if (uid == null || text == null) return;

    if (_waitingForWishlist.contains(uid)) {
      if (text.startsWith('/')) return;

      _waitingForWishlist.remove(uid);

      if (text.trim().isEmpty) {
        await ctx.reply('❌ Пустой вишлист не сохранен.');
        return;
      }

      service.setWishlist(UserId(uid), text);
      await saveState();

      await ctx.reply(
        '✅ Вишлист сохранен!\n\n📝 Ваш вишлист:\n${text.length > 200 ? text.substring(0, 200) + '...' : text}',
        replyMarkup: UI.backToSettingsKeyboard(),
      );
      return;
    }

    if (!text.startsWith('/')) {
      await ctx.reply(
        'Используйте меню или команду /start.',
        replyMarkup: UI.mainMenu(isAdmin: isAdmin(ctx)),
      );
    }
  }

  Future<void> blocklist(Bot<Ctx> bot, Ctx ctx) async {
    final uid = ctx.from?.id;
    if (uid == null) {
      await ctx.reply('Ошибка ID.');
      return;
    }
    final me = service.find(UserId(uid));
    if (me == null) {
      await ctx.reply('Сначала /start.');
      return;
    }

    try {
      await ctx.editMessageText(
        '🚫 Блок-лист\n\nНажимайте на участников, чтобы переключать блокировку:',
        replyMarkup: UI.blocklistMenu(service.list(), me),
      );
    } catch (_) {
      await ctx.reply(
        '🚫 Блок-лист\n\nНажимайте на участников, чтобы переключать блокировку:',
        replyMarkup: UI.blocklistMenu(service.list(), me),
      );
    }
  }

  Future<void> toggleBlock(Ctx ctx, int targetId) async {
    final uid = ctx.from?.id;
    if (uid == null) return;

    final changedToBlocked = service.toggleBlock(UserId(uid), UserId(targetId));
    await saveState();

    final me = service.find(UserId(uid));
    if (me == null) return;

    final targetUser = service.find(UserId(targetId));
    final targetName = targetUser?.name ?? 'Неизвестный';

    try {
      await ctx.editMessageText(
        '🚫 Блок-лист\n\n${changedToBlocked ? '✅ Добавлен' : '❌ Удален'} из блок-листа: $targetName\n\nНажимайте на участников, чтобы переключать блокировку:',
        replyMarkup: UI.blocklistMenu(service.list(), me),
      );
    } catch (_) {
      await ctx.reply(
        '🚫 Блок-лист обновлен\n\n${changedToBlocked ? '✅ Добавлен' : '❌ Удален'}: $targetName',
        replyMarkup: UI.blocklistMenu(service.list(), me),
      );
    }
  }

  Future<void> exportJson(Ctx ctx, String path) async {
    if (!isAdmin(ctx)) {
      await ctx.reply('🚫 Доступ запрещен.');
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      await ctx.reply('📁 Файл состояния не найден.');
      return;
    }
    try {
      await ctx.replyWithDocument(
        InputFile.fromFile(file),
        caption: '📤 Экспорт состояния бота',
      );
    } catch (e) {
      await ctx.reply('❌ Ошибка при отправке файла.');
    }
  }
}
