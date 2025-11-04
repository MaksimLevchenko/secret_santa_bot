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
    final h = Handlers(
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
    _setupHandlers(bot, h);

    print('✅ Бот запущен успешно!');
    print('📝 Логи ошибок: ${Config.dataDir}/error.log');
    print('🔑 ID администратора: ${Config.adminId}'); // ОТЛАДКА

    await bot.start();
  } catch (e) {
    stderr.writeln('💥 Критическая ошибка запуска: $e');
    exit(1);
  }
}

void _setupHandlers(Bot<Ctx> bot, Handlers h) {
  // Команды
  bot.command('start', h.start);
  bot.command('members', h.showMembers);
  bot.command('admin_check', h.checkAdmin); // НОВАЯ КОМАНДА ДЛЯ ОТЛАДКИ

  // Кнопки
  bot.callbackQuery('members', h.showMembers);
  bot.callbackQuery('my_assignment', h.showMyAssignment);
  bot.callbackQuery('settings', h.openSettings);
  bot.callbackQuery('back_main', h.backMain);

  bot.callbackQuery('wishlist', (ctx) => h.wishlistFlow(bot, ctx));

  bot.callbackQuery('blocklist', (ctx) => h.blocklist(bot, ctx));
  bot.callbackQuery(RegExp(r'^toggle_block_(\d+)$'), (ctx) async {
    final data = ctx.callbackQuery!.data!;
    final id = int.parse(
      RegExp(r'^toggle_block_(\d+)$').firstMatch(data)!.group(1)!,
    );
    await h.toggleBlock(ctx, id);
  });

  bot.callbackQuery('admin', h.openAdmin);

  bot.callbackQuery(RegExp(r'^admin_distribute_(on|off)$'), (ctx) async {
    final enabled = ctx.callbackQuery!.data!.endsWith('on');
    await h.distribute(ctx, enabled: enabled);
  });

  bot.callbackQuery('admin_reset_assign', h.resetAssignments);
  bot.callbackQuery('admin_reset_all', h.resetAll);

  bot.callbackQuery('admin_export', (ctx) async {
    await h.exportJson(ctx, Config.stateFilePath);
  });

  // Обработка текстовых сообщений
  bot.on(const TextMessageFilter(), (ctx) async {
    await h.handleTextMessage(ctx);
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
