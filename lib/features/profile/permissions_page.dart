import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme/pace_theme.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/pace_page_scaffold.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});
  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  LocationPermission? permission;
  bool? enabled;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final value = await Geolocator.checkPermission();
      final service = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          permission = value;
          enabled = service;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    return PacePageScaffold(
      title: 'Разрешения',
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Геолокация',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Text(
              failed
                  ? 'Не удалось прочитать настройки геолокации.'
                  : permission == null
                  ? 'Проверяем настройки…'
                  : 'Доступ к геолокации: ${allowed ? 'разрешён' : 'не разрешён'}\n'
                        'Геолокация устройства: ${enabled == true ? 'включена' : 'выключена'}',
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Для записи маршрута PACE нужен доступ к геолокации. '
            'Разрешения можно изменить в настройках устройства.',
            style: TextStyle(color: muted, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              try {
                final opened = await Geolocator.openAppSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Открой настройки приложения на устройстве.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Открой настройки приложения на устройстве.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Настройки устройства'),
          ),
          TextButton(onPressed: _refresh, child: const Text('Проверить снова')),
          const SizedBox(height: 20),
          const Text(
            'Фоновая запись пока не подключена. Во время тренировки держи приложение открытым.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
