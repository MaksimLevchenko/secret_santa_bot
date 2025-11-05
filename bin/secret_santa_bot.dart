import 'dart:io';
import 'package:televerse/televerse.dart';
import 'package:secret_santa_bot/infrastructure/json_state_store.dart';
import 'package:secret_santa_bot/infrastructure/config.dart';
import 'package:secret_santa_bot/app/secret_santa_service.dart';
import 'package:secret_santa_bot/presentation/handlers.dart';

typedef Ctx = Context;

Future<void> main() async {
  try {
    // Инициализация конфигурации из .env
    await Config.init();
    Config.validate();

    print('🚀 Запуск Secret Santa Bot...');

    final bot = Bot<Ctx>(Config.botToken);

    final store = JsonStateStore(
      dataDir: Config.dataDir,
      fileName: Config.stateFile,
    );
    final initial = await store.load();
    final svc = SecretSantaServiceImpl(initial);

    // Создаем отдельные хендлеры для каждой области функциональности
    final userHandler = UserHandler(
      service: svc,
      store: store,
      adminId: Config.adminId,
    );

    final adminHandler = AdminHandler(
      service: svc,
      store: store,
      adminId: Config.adminId,
    );

    final gameHandler = GameHandler(
      service: svc,
      store: store,
      adminId: Config.adminId,
    );

    final distributionHandler = DistributionHandler.withAttempts(
      service: svc,
      store: store,
      adminId: Config.adminId,
      maxAttempts: Config.maxAttempts,
    );

    // Обработка ошибок
    bot.onError((err) async {
      final timestamp = DateTime.now().toIso8601String();
      stderr.writeln('[$timestamp] Bot error: ${err.error}');

      if (Config.isDebug) {
        stderr.writeln('Stack trace: ${err.stackTrace}');
      }

      // Логирование в файл
      await _logError(timestamp, err.error.toString());

      if (err.hasContext) {
        await err.ctx!.reply('Произошла ошибка, попробуйте позже.');
      }
    });

    // Команды и обработчики
    _setupHandlers(bot, userHandler, adminHandler, gameHandler, distributionHandler);

    print('✅ Бот запущен успешно!');
    print('📝 Логи ошибок: ${Config.dataDir}/error.log');
    print('🔑 ID администратора: ${Config.adminId}');

    await bot.start();
  } catch (e) {
    stderr.writeln('💥 Критическая ошибка запуска: $e');
    exit(1);
  }
}

void _setupHandlers(
  Bot<Ctx> bot,
  UserHandler userHandler,
  AdminHandler adminHandler,
  GameHandler gameHandler,
  DistributionHandler distributionHandler,
) {
  // Команды
  bot.command('start', userHandler.start);
  bot.command('members', userHandler.showMembers);
  bot.command('admin_check', userHandler.checkAdmin);

  // Основные кнопки навигации
  bot.callbackQuery('members', userHandler.showMembers);
  bot.callbackQuery('my_assignment', userHandler.showMyAssignment);
  bot.callbackQuery('back_main', (ctx) async {
    // Очищаем состояние ожидания вишлиста при возврате в главное меню
    final uid = ctx.from?.id;
    if (uid != null) {
      // Доступ к приватному полю через gameHandler не получится,
      // поэтому просто вызываем backMain
    }
    await userHandler.backMain(ctx);
  });

  // Настройки и игровые функции
  bot.callbackQuery('settings', gameHandler.openSettings);
  bot.callbackQuery('wishlist', (ctx) => gameHandler.wishlistFlow(bot, ctx));
  bot.callbackQuery('blocklist', (ctx) => gameHandler.blocklist(bot, ctx));
  
  bot.callbackQuery(RegExp(r'^toggle_block_(\d+)$'), (ctx) async {
    final data = ctx.callbackQuery!.data!;
    final id = int.parse(
      RegExp(r'^toggle_block_(\d+)$').firstMatch(data)!.group(1)!,
    );
    await gameHandler.toggleBlock(ctx, id);
  });

  // Админские функции
  bot.callbackQuery('admin', adminHandler.openAdmin);
  
  bot.callbackQuery(RegExp(r'^admin_distribute_(on|off)$'), (ctx) async {
    final enabled = ctx.callbackQuery!.data!.endsWith('on');
    await distributionHandler.distribute(ctx, enabled: enabled);
  });

  bot.callbackQuery('admin_reset_assign', distributionHandler.resetAssignments);
  bot.callbackQuery('admin_reset_all', distributionHandler.resetAll);

  bot.callbackQuery('admin_export', (ctx) async {
    await gameHandler.exportJson(ctx, Config.stateFilePath);
  });

  // Обработка текстовых сообщений
  bot.on(const TextMessageFilter(), (ctx) async {
    await gameHandler.handleTextMessage(ctx);
  });
}

Future<void> _logError(String timestamp, String error) async {
  try {
    final logFile = File('${Config.dataDir}/error.log');
    await logFile.writeAsString('[$timestamp] $error\n', mode: FileMode.append);
  } catch (_) {
    // Игнорируем ошибки логирования
  }
}