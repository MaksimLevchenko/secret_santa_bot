import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/domain/models.dart';

class UI {
  static InlineKeyboard mainMenu({required bool isAdmin}) {
    print('🎮 UI.mainMenu вызван с isAdmin: $isAdmin'); // ОТЛАДКА

    if (isAdmin) {
      // Полная клавиатура с админ-кнопкой
      final kb = InlineKeyboard()
          .text('👤 Мои настройки', 'settings')
          .row()
          .text('🎁 Кому я дарю', 'my_assignment')
          .row()
          .text('👥 Участники', 'members')
          .row()
          .text('🛠 Админ', 'admin');

      print('✅ Создана админская клавиатура'); // ОТЛАДКА
      return kb;
    } else {
      // Клавиатура без админ-кнопки
      final kb = InlineKeyboard()
          .text('👤 Мои настройки', 'settings')
          .row()
          .text('🎁 Кому я дарю', 'my_assignment')
          .row()
          .text('👥 Участники', 'members');

      print('👤 Создана обычная клавиатура'); // ОТЛАДКА
      return kb;
    }
  }

  static InlineKeyboard settingsMenu() {
    return InlineKeyboard()
        .text('📝 Вишлист', 'wishlist')
        .row()
        .text('🚫 Блок-лист', 'blocklist')
        .row()
        .text('⬅️ Назад', 'back_main');
  }

  static InlineKeyboard blocklistMenu(List<Participant> all, Participant me) {
    var kb = InlineKeyboard();

    for (final u in all.where((u) => u.id != me.id)) {
      final isBlocked = me.blocked.contains(u.id);
      kb = kb
          .text(
            '${isBlocked ? '✅' : '➕'} ${u.name}',
            'toggle_block_${u.id.value}',
          )
          .row();
    }

    return kb.text('⬅️ Назад', 'settings');
  }

  static InlineKeyboard adminMenu({required bool canDistribute}) {
    return InlineKeyboard()
        .text(
          '🎁 Распределить',
          'admin_distribute_${canDistribute ? 'on' : 'off'}',
        )
        .row()
        .text('♻️ Сбросить результаты', 'admin_reset_assign')
        .row()
        .text('🗑 Полный сброс', 'admin_reset_all')
        .row()
        .text('📤 Экспорт JSON', 'admin_export')
        .row()
        .text('⬅️ Назад', 'back_main');
  }

  // Дополнительные клавиатуры
  static InlineKeyboard backOnlyKeyboard() {
    return InlineKeyboard().text('⬅️ Назад', 'back_main');
  }

  static InlineKeyboard cancelKeyboard() {
    return InlineKeyboard().text('❌ Отменить', 'settings');
  }

  static InlineKeyboard backToSettingsKeyboard() {
    return InlineKeyboard()
        .text('⚙️ Настройки', 'settings')
        .row()
        .text('🏠 Главное меню', 'back_main');
  }

  static InlineKeyboard assignmentKeyboard() {
    return InlineKeyboard()
        .text('🔄 Обновить', 'my_assignment')
        .row()
        .text('⬅️ Назад', 'back_main');
  }

  static String formatMembers(List<Participant> list) {
    if (list.isEmpty) {
      return 'Пока нет участников.\n\n💡 Участники появятся после команды /start';
    }

    final b = StringBuffer('👥 Участники (${list.length}):\n\n');
    for (final u in list) {
      final marker = u.assignedTo != null ? '🎁' : '•';
      final wishlistInfo = u.wishlist.trim().isEmpty ? '' : ' 📝';
      final blockInfo = u.blocked.isNotEmpty ? ' 🚫${u.blocked.length}' : '';
      b.writeln('$marker ${u.name}$wishlistInfo$blockInfo');
    }

    if (list.any((u) => u.assignedTo != null)) {
      b.writeln('\n🎁 - получил назначение');
    }
    b.writeln('📝 - есть вишлист');
    b.writeln('🚫 - количество заблокированных');

    return b.toString();
  }

  static String formatAssignment(Participant receiver) {
    final wl = receiver.wishlist.trim().isEmpty
        ? 'не указан'
        : receiver.wishlist.trim();
    return '🎅 Ваш получатель подарка: ${receiver.name}\n\n📝 Вишлист: $wl';
  }

  // ИСПРАВЛЕНО: добавлен updateTime для предотвращения ошибки 400
  static String formatMyAssignment(
    Participant me,
    Participant? receiver,
    bool distributed, {
    String? updateTime,
  }) {
    if (!distributed) {
      return '🎁 Кому я дарю\n\n'
          '❌ Распределение еще не выполнено\n\n'
          '💡 Дождитесь, когда администратор запустит распределение участников.'
          '${updateTime != null ? '\n\n🕐 Обновлено: $updateTime' : ''}';
    }

    if (receiver == null) {
      return '🎁 Кому я дарю\n\n'
          '❌ Ошибка: назначение не найдено\n\n'
          '💡 Обратитесь к администратору.'
          '${updateTime != null ? '\n\n🕐 Обновлено: $updateTime' : ''}';
    }

    final b = StringBuffer();
    b.writeln('🎁 Ваш получатель подарка');
    b.writeln();
    b.writeln('👤 ${receiver.name}');
    b.writeln();

    if (receiver.wishlist.trim().isNotEmpty) {
      b.writeln('📝 Вишлист:');
      b.writeln(receiver.wishlist.trim());
      b.writeln();
    } else {
      b.writeln('📝 Вишлист: не указан');
      b.writeln();
    }

    if (receiver.blocked.isNotEmpty) {
      b.writeln('🚫 Заблокировал участников: ${receiver.blocked.length}');
      b.writeln();
    }

    b.writeln('💡 Советы:');
    b.writeln('• Подготовьте подарок заранее');
    b.writeln('• Учитывайте вишлист получателя');
    b.writeln('• Сохраните конфиденциальность');

    if (updateTime != null) {
      b.writeln();
      b.writeln('🕐 Обновлено: $updateTime');
    }

    return b.toString();
  }

  // Статический метод для профиля участника (может пригодиться)
  static String formatParticipantProfile(Participant participant) {
    final b = StringBuffer();
    b.writeln('👤 Профиль: ${participant.name}');
    b.writeln();

    if (participant.wishlist.trim().isNotEmpty) {
      b.writeln('📝 Вишлист:');
      b.writeln(participant.wishlist.trim());
    } else {
      b.writeln('📝 Вишлист: не указан');
    }
    b.writeln();

    if (participant.blocked.isNotEmpty) {
      b.writeln('🚫 Заблокировано участников: ${participant.blocked.length}');
    } else {
      b.writeln('🚫 Блокировок нет');
    }

    if (participant.assignedTo != null) {
      b.writeln('🎁 Статус: получил назначение');
    } else {
      b.writeln('🎁 Статус: ожидает распределения');
    }

    return b.toString();
  }
}
