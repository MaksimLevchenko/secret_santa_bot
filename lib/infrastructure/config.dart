import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as p;

class Config {
  static DotEnv? _env;

  static Future<void> init({String envPath = '.env'}) async {
    _env = DotEnv()..load([envPath]);
  }

  static String get botToken {
    final token = _env?['BOT_TOKEN'] ?? Platform.environment['BOT_TOKEN'] ?? '';
    if (token.isEmpty) {
      throw StateError(
        'BOT_TOKEN не установлен в .env или переменных окружения',
      );
    }
    return token;
  }

  static int get adminId {
    final id = _env?['ADMIN_ID'] ?? Platform.environment['ADMIN_ID'] ?? '';
    if (id.isEmpty) {
      throw StateError(
        'ADMIN_ID не установлен в .env или переменных окружения',
      );
    }
    final parsed = int.tryParse(id);
    if (parsed == null) {
      throw StateError('ADMIN_ID должен быть числом: $id');
    }
    return parsed;
  }

  static String get dataDir {
    final dir = _env?['DATA_DIR'] ?? Platform.environment['DATA_DIR'] ?? 'data';
    return p.isAbsolute(dir) ? dir : p.join(Directory.current.path, dir);
  }

  static String get stateFile {
    return _env?['STATE_FILE'] ??
        Platform.environment['STATE_FILE'] ??
        'state.json';
  }

  static int get maxAttempts {
    final attempts =
        _env?['MAX_ATTEMPTS'] ?? Platform.environment['MAX_ATTEMPTS'] ?? '2000';
    return int.tryParse(attempts) ?? 2000;
  }

  static String get logLevel {
    return _env?['LOG_LEVEL'] ?? Platform.environment['LOG_LEVEL'] ?? 'info';
  }

  static String get stateFilePath => p.join(dataDir, stateFile);

  // Для разных окружений
  static bool get isProduction =>
      (_env?['ENVIRONMENT'] ??
          Platform.environment['ENVIRONMENT'] ??
          'development') ==
      'production';

  static bool get isDebug => !isProduction;

  // Валидация конфигурации
  static void validate() {
    try {
      botToken; // Проверяем наличие токена
      adminId; // Проверяем наличие admin ID
      print('✅ Конфигурация валидна');
      if (isDebug) {
        print('🔧 Режим: разработка');
        print('📁 Директория данных: $dataDir');
        print('👤 Admin ID: $adminId');
      }
    } catch (e) {
      print('❌ Ошибка конфигурации: $e');
      rethrow;
    }
  }
}
