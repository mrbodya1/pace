import 'dart:io';
import 'dart:math';

/// Seed only a fresh temporary test database; never the working backend.
Future<void> preparePocketBaseTest(
  String executable,
  Directory temporary,
) async {
  final data = '${temporary.path}/data';
  if (!await temporary.exists() || await Directory(data).exists()) {
    throw StateError('Expected a fresh temporary test directory');
  }
  final random = Random.secure();
  final password = List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final result = await Process.run(executable, [
    'superuser',
    'create',
    'bootstrap@invalid.example',
    password,
    '--dir=$data',
    '--migrationsDir=${Directory.current.path}/server/pb_migrations',
    '--hooksDir=${Directory.current.path}/server/pb_hooks',
  ]).timeout(const Duration(seconds: 30));
  if (result.exitCode != 0) {
    throw StateError(
      'Temporary PocketBase bootstrap failed (private output suppressed)',
    );
  }
}
