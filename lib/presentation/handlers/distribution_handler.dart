import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/presentation/ui.dart';
import 'base_handler.dart';

class DistributionHandler extends BaseHandler {
  final int maxAttempts;

  DistributionHandler({
    required super.service,
    required super.store,
    required super.adminId,
    this.maxAttempts = 2000,
  });

  Future<void> distribute(Ctx ctx, {required bool enabled}) async {
    if (!isAdmin(ctx)) {
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

    await saveState();

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
      } catch (_) {}
    }

    final generalNotificationText =
        '🎉 Распределение "Тайный Санта" завершено!\n\n'
        '✅ Игра началась!\n'
        '🎁 Проверьте ваше назначение в разделе "Кому я дарю"\n\n'
        '💡 Помните: это тайна! Не рассказывайте другим участникам кому дарите подарки.';

    final generalNotificationCount = await notifyAllParticipants(
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
    if (!isAdmin(ctx)) {
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
    await saveState();

    final resetNotificationText =
        '♻️ Результаты распределения сброшены!\n\n'
        '🔄 Администратор перезапустил игру\n'
        '⏳ Ожидайте нового распределения\n\n'
        '💡 Ваши вишлисты и настройки сохранены.';

    final notificationCount = await notifyAllParticipants(
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
    if (!isAdmin(ctx)) {
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

    final notificationCount = await notifyAllParticipants(
      ctx,
      resetAllNotificationText,
    );

    service.resetAll();
    await saveState();

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
}
