import 'dart:io';
import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/domain/models.dart';
import 'package:secret_santa_bot/domain/repositories.dart';
import 'package:secret_santa_bot/presentation/ui.dart';
import 'package:secret_santa_bot/app/secret_santa_service.dart';

typedef Ctx = Context;

class Handlers {
  final SecretSantaServiceImpl service;
  final StateStore store;
  final int adminId;
  final int maxAttempts;
  final Set<int> _waitingForWishlist = {};

  Handlers({
    required this.service,
    required this.store,
    required this.adminId,
    this.maxAttempts = 2000,
  });

  bool _isAdmin(Ctx ctx) => (ctx.from?.id ?? 0) == adminId;

  Future<void> _saveState() async {
    await store.save(service.state);
  }

  Future<int> _notifyAllParticipants(Ctx ctx, String message) async {
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
    await _saveState();

    final isAdmin = _isAdmin(ctx);
    final keyboard = UI.mainMenu(isAdmin: isAdmin);

    await ctx.reply(
      'Добро пожаловать, ${participant.name}! 🎅\n\nЭто бот для игры в Тайного Санту. Выберите действие:',
      replyMarkup: keyboard,
    );
  }

  Future<void> checkAdmin(Ctx ctx) async {
    final uid = ctx.from?.id;
    final isAdmin = _isAdmin(ctx);
    await ctx.reply(
      '🔍 Информация о правах:\n\n'
      '👤 Ваш ID: $uid\n'
      '🔑 ID администратора: $adminId\n'
      '🛠 Права админа: ${isAdmin ? 'Да ✅' : 'Нет ❌'}\n\n'
      '${isAdmin ? 'У вас есть доступ к админ-панели!' : 'Вы обычный участник.'}',
    );
  }

  // ИСПРАВЛЕНО: добавляем timestamp для избежания ошибки 400
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

    // Добавляем timestamp чтобы контент всегда был разный
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
      // Fallback - отправляем новое сообщение
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

  Future<void> backMain(Ctx ctx) async {
    final uid = ctx.from?.id;
    if (uid != null) {
      _waitingForWishlist.remove(uid);
    }

    final isAdmin = _isAdmin(ctx);

    try {
      await ctx.editMessageText(
        '🏠 Главное меню\n\nВыберите действие:',
        replyMarkup: UI.mainMenu(isAdmin: isAdmin),
      );
    } catch (_) {
      await ctx.reply(
        '🏠 Главное меню\n\nВыберите действие:',
        replyMarkup: UI.mainMenu(isAdmin: isAdmin),
      );
    }
  }

  Future<void> openAdmin(Ctx ctx) async {
    if (!_isAdmin(ctx)) {
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

  // Остальные методы остаются без изменений...
  Future<void> distribute(Ctx ctx, {required bool enabled}) async {
    if (!_isAdmin(ctx)) {
      await ctx.reply('🚫 Доступ запрещен.');
      return;
    }

    if (service.state.distributed) {
      try {
        await ctx.editMessageText(
          '❌ Распределение уже выполнено!\n\n'
          '💡 Для повторного распределения сначала сбросьте результаты.',
          replyMarkup: UI.adminMenu(canDistribute: false),
        );
      } catch (_) {
        await ctx.reply(
          '❌ Распределение уже выполнено. Сначала сбросьте результаты.',
        );
      }
      return;
    }

    if (!enabled) {
      try {
        await ctx.editMessageText(
          '❌ Недостаточно участников для распределения\n\nНужно минимум 3 участника.',
          replyMarkup: UI.adminMenu(canDistribute: false),
        );
      } catch (_) {
        await ctx.reply('❌ Недостаточно участников (минимум 3).');
      }
      return;
    }

    try {
      await ctx.editMessageText(
        '⏳ Выполняю распределение...\n\nПожалуйста, подождите.',
      );
    } catch (_) {
      await ctx.reply('⏳ Выполняю распределение...');
    }

    final ok = service.distribute(maxAttempts: maxAttempts);
    if (!ok) {
      try {
        await ctx.editMessageText(
          '❌ Не удалось распределить!\n\n'
          'Блок-листы участников делают распределение невозможным.\n\n'
          '💡 Попросите участников пересмотреть свои блок-листы.',
          replyMarkup: UI.adminMenu(canDistribute: true),
        );
      } catch (_) {
        await ctx.reply('❌ Не удалось распределить. Проверьте блок-листы.');
      }
      return;
    }

    await _saveState();

    final participantCount = service.list().length;

    try {
      await ctx.editMessageText(
        '📤 Рассылаю уведомления участникам...\n\nПожалуйста, подождите.',
      );
    } catch (_) {}

    int assignmentSuccessCount = 0;
    for (final u in service.list()) {
      final to = u.assignedTo;
      if (to == null) continue;
      final recv = service.find(to)!;
      try {
        await ctx.api.sendMessage(
          ChatID(u.id.value),
          UI.formatAssignment(recv),
        );
        assignmentSuccessCount++;
      } catch (_) {
        // Пользователь не открыл диалог с ботом
      }
    }

    final generalNotificationText =
        '🎉 Распределение "Тайный Санта" завершено!\n\n'
        '✅ Игра началась!\n'
        '🎁 Проверьте ваше назначение в разделе "Кому я дарю"\n\n'
        '💡 Помните: это тайна! Не рассказывайте другим участникам кому дарите подарки.';

    final generalNotificationCount = await _notifyAllParticipants(
      ctx,
      generalNotificationText,
    );

    try {
      await ctx.editMessageText(
        '🎉 Распределение выполнено успешно!\n\n'
        '✅ Назначения отправлены: $assignmentSuccessCount/$participantCount\n'
        '📢 Общих уведомлений: $generalNotificationCount/$participantCount\n\n'
        '${assignmentSuccessCount < participantCount ? '⚠️ Некоторые участники не получили личные назначения.\n' : ''}'
        '${generalNotificationCount < participantCount ? '⚠️ Некоторые участники не получили общее уведомление.\n' : ''}'
        '\n💡 Если кто-то не получил сообщения - попросите написать /start боту в личку.',
        replyMarkup: UI.adminMenu(canDistribute: false),
      );
    } catch (_) {
      await ctx.reply(
        '🎉 Распределение выполнено!\n\n✅ Назначения: $assignmentSuccessCount/$participantCount\n📢 Уведомления: $generalNotificationCount/$participantCount',
      );
    }
  }

  Future<void> resetAssignments(Ctx ctx) async {
    if (!_isAdmin(ctx)) {
      await ctx.reply('🚫 Доступ запрещен.');
      return;
    }

    final wasDistributed = service.state.distributed;
    final participantCount = service.list().length;

    if (!wasDistributed) {
      try {
        await ctx.editMessageText(
          '💡 Назначений для сброса нет\n\nРаспределение еще не было выполнено.',
          replyMarkup: UI.adminMenu(canDistribute: participantCount >= 3),
        );
      } catch (_) {
        await ctx.reply('💡 Назначений для сброса нет.');
      }
      return;
    }

    try {
      await ctx.editMessageText(
        '📤 Сбрасываю результаты и оповещаю участников...\n\nПожалуйста, подождите.',
      );
    } catch (_) {}

    service.resetAssignments();
    await _saveState();

    final resetNotificationText =
        '♻️ Результаты распределения сброшены!\n\n'
        '🔄 Администратор перезапустил игру\n'
        '⏳ Ожидайте нового распределения\n\n'
        '💡 Ваши вишлисты и настройки сохранены.';

    final notificationCount = await _notifyAllParticipants(
      ctx,
      resetNotificationText,
    );

    try {
      await ctx.editMessageText(
        '♻️ Результаты распределения сброшены!\n\n'
        '✅ Предыдущие назначения удалены\n'
        '📢 Уведомлений отправлено: $notificationCount/$participantCount\n\n'
        '🎯 Теперь можно запустить новое распределение\n'
        '${notificationCount < participantCount ? '\n⚠️ Некоторые участники не получили уведомление - попросите их написать /start боту в личку.' : ''}',
        replyMarkup: UI.adminMenu(canDistribute: participantCount >= 3),
      );
    } catch (_) {
      await ctx.reply(
        '♻️ Назначения сброшены. Уведомлений отправлено: $notificationCount/$participantCount',
      );
    }
  }

  Future<void> resetAll(Ctx ctx) async {
    if (!_isAdmin(ctx)) {
      await ctx.reply('🚫 Доступ запрещен.');
      return;
    }

    final participantCount = service.list().length;

    if (participantCount == 0) {
      try {
        await ctx.editMessageText(
          '💡 Нет участников для удаления\n\nБот уже пустой.',
          replyMarkup: UI.adminMenu(canDistribute: false),
        );
      } catch (_) {
        await ctx.reply('💡 Нет участников для удаления.');
      }
      return;
    }

    try {
      await ctx.editMessageText(
        '📤 Выполняю полный сброс и оповещаю участников...\n\nПожалуйста, подождите.',
      );
    } catch (_) {}

    final resetAllNotificationText =
        '🗑 Полный сброс игры "Тайный Санта"!\n\n'
        '❌ Все данные удалены\n'
        '❌ Регистрация сброшена\n'
        '❌ Вишлисты и блок-листы очищены\n\n'
        '💡 Для участия в новой игре отправьте /start';

    final notificationCount = await _notifyAllParticipants(
      ctx,
      resetAllNotificationText,
    );

    service.resetAll();
    await _saveState();

    try {
      await ctx.editMessageText(
        '🗑 Полный сброс выполнен!\n\n'
        '❌ Удалено участников: $participantCount\n'
        '📢 Уведомлений отправлено: $notificationCount/$participantCount\n\n'
        '💡 Участники должны заново зарегистрироваться через /start\n'
        '${notificationCount < participantCount ? '\n⚠️ Некоторые участники не получили уведомление.' : ''}',
        replyMarkup: UI.adminMenu(canDistribute: false),
      );
    } catch (_) {
      await ctx.reply(
        '🗑 Полный сброс выполнен. Уведомлений: $notificationCount/$participantCount',
      );
    }
  }

  // Остальные методы остаются без изменений...
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
      await _saveState();

      await ctx.reply(
        '✅ Вишлист сохранен!\n\n📝 Ваш вишлист:\n${text.length > 200 ? '${text.substring(0, 200)}...' : text}',
        replyMarkup: UI.backToSettingsKeyboard(),
      );
      return;
    }

    if (!text.startsWith('/')) {
      await ctx.reply(
        'Используйте меню или команду /start.',
        replyMarkup: UI.mainMenu(isAdmin: _isAdmin(ctx)),
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
    await _saveState();

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
    if (!_isAdmin(ctx)) {
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
