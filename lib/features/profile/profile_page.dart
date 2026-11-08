import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../data/storage/profile_storage_service.dart';
import '../../models/specialization.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/pace_page_scaffold.dart';
import '../auth/sign_in_page.dart';
import 'permissions_page.dart';
import 'specialization_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.sports,
    required this.sportIcons,
    required this.selectedSport,
    required this.tracking,
    required this.onSelectSport,
  });
  final List<String> sports;
  final List<IconData> sportIcons;
  final int selectedSport;
  final bool tracking;
  final ValueChanged<int> onSelectSport;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final storage = ProfileStorageService();
  Map<String, dynamic> profile = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await storage.load();
      if (mounted) {
        setState(() {
          profile = value;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить профиль.')),
        );
      }
    }
  }

  Future<void> _edit({bool personal = false}) async {
    final value = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ProfileEditor(
          profile: profile,
          personal: personal,
          storage: storage,
        ),
      ),
    );
    if (value != null && mounted) setState(() => profile = value);
  }

  Future<void> _chooseSpecialization() async {
    final value = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => SpecializationPage(storage: storage)),
    );
    if (value != null && mounted) setState(() => profile = value);
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'BODYA';
    final bio = profile['bio'] as String? ?? 'Универсальный атлет';
    final city = profile['city'] as String? ?? '';
    final specialization = Specialization.fromId(profile['specializationId']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 140),
      children: [
        const Text(
          'Профиль',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 28),
        const CircleAvatar(
          radius: 42,
          backgroundColor: panel,
          child: Icon(CupertinoIcons.person, size: 44, color: lime),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 15),
          ),
        ],
        if (city.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            city,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 14),
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: loading ? null : () => _edit(),
          child: const Text('Редактировать профиль'),
        ),
        if (specialization != null) ...[
          Text(
            specialization.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: lime, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const SignInPage())),
          icon: const Icon(CupertinoIcons.person_crop_circle),
          label: const Text('Войти в аккаунт'),
        ),
        const SizedBox(height: 28),
        sectionTitle('ЛИЧНЫЕ НАСТРОЙКИ'),
        const SizedBox(height: 12),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                key: const ValueKey('profile-specialization'),
                leading: Icon(
                  specialization?.icon ?? Icons.auto_awesome_rounded,
                  color: lime,
                ),
                title: const Text('Специализация'),
                subtitle: Text(
                  specialization?.title ?? 'Выбери своего спортсмена',
                ),
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: muted,
                ),
                onTap: loading ? null : _chooseSpecialization,
              ),
              const Divider(height: 1, indent: 18, endIndent: 18),
              ListTile(
                leading: const Icon(CupertinoIcons.person, color: muted),
                title: const Text('Личные параметры'),
                subtitle: const Text('Рост, вес, дата рождения, пол'),
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: muted,
                ),
                onTap: loading ? null : () => _edit(personal: true),
              ),
              const Divider(height: 1, indent: 18, endIndent: 18),
              ListTile(
                leading: const Icon(CupertinoIcons.location, color: muted),
                title: const Text('Разрешения'),
                subtitle: const Text('Доступ к геолокации'),
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: muted,
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const PermissionsPage()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        sectionTitle('СПОРТ ПО УМОЛЧАНИЮ'),
        const SizedBox(height: 12),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(widget.sportIcons[widget.selectedSport], color: lime),
            title: Text(widget.sports[widget.selectedSport]),
            subtitle: widget.tracking
                ? const Text('Недоступно во время записи')
                : null,
            trailing: const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: muted,
            ),
            onTap: widget.tracking
                ? null
                : () async {
                    final selected = await showModalBottomSheet<int>(
                      context: context,
                      backgroundColor: panel,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.65,
                          child: ListView(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'Спорт по умолчанию',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              for (var i = 0; i < widget.sports.length; i++)
                                ListTile(
                                  title: Text(widget.sports[i]),
                                  leading: Icon(
                                    widget.sportIcons[i],
                                    color: i == widget.selectedSport
                                        ? lime
                                        : muted,
                                  ),
                                  trailing: i == widget.selectedSport
                                      ? const Icon(
                                          CupertinoIcons.check_mark,
                                          color: lime,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(context, i),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (selected != null && mounted && !widget.tracking) {
                      widget.onSelectSport(selected);
                    }
                  },
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Прогресс и параметры сохраняются на этом устройстве.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.profile,
    required this.personal,
    required this.storage,
  });
  final Map<String, dynamic> profile;
  final bool personal;
  final ProfileStorageService storage;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, bio, city, height, weight, birthday;
  String sex = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.profile['name'] as String? ?? 'BODYA',
    );
    bio = TextEditingController(
      text: widget.profile['bio'] as String? ?? 'Универсальный атлет',
    );
    city = TextEditingController(text: widget.profile['city'] as String? ?? '');
    height = TextEditingController(
      text: widget.profile['height']?.toString() ?? '',
    );
    weight = TextEditingController(
      text: widget.profile['weight']?.toString() ?? '',
    );
    birthday = TextEditingController(
      text: widget.profile['birthday'] as String? ?? '',
    );
    sex = widget.profile['sex'] as String? ?? '';
  }

  @override
  void dispose() {
    for (final controller in [name, bio, city, height, weight, birthday]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _number(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value == null || !value.isFinite || value <= 0 || value > 1000
        ? 'Укажи положительное число'
        : null;
  }

  String? _birthday(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.trim().split('.');
    if (parts.length != 3 || parts[2].length != 4) return 'Формат: ДД.ММ.ГГГГ';
    final day = int.tryParse(parts[0]),
        month = int.tryParse(parts[1]),
        year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return 'Проверь дату';
    final date = DateTime(year, month, day);
    if (year < 1900 ||
        date.day != day ||
        date.month != month ||
        date.isAfter(DateTime.now())) {
      return 'Проверь дату';
    }
    return null;
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final value = Map<String, dynamic>.from(widget.profile);
    if (widget.personal) {
      value['birthday'] = birthday.text.trim();
      value['sex'] = sex;
      for (final entry in {'height': height, 'weight': weight}.entries) {
        final number = double.tryParse(entry.value.text.replaceAll(',', '.'));
        if (number == null) {
          value.remove(entry.key);
        } else {
          value[entry.key] = number;
        }
      }
    } else {
      value['name'] = name.text.trim();
      value['bio'] = bio.text.trim();
      value['city'] = city.text.trim();
    }
    try {
      await widget.storage.save(value);
      if (mounted) Navigator.pop(context, value);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить профиль. Попробуй снова.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: PacePageScaffold(
        title: widget.personal ? 'Личные параметры' : 'Редактирование',
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              if (widget.personal) ...[
                TextFormField(
                  controller: height,
                  decoration: const InputDecoration(labelText: 'Рост, см'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: weight,
                  decoration: const InputDecoration(labelText: 'Вес, кг'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _number,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: birthday,
                  decoration: const InputDecoration(
                    labelText: 'Дата рождения',
                    hintText: 'ДД.ММ.ГГГГ',
                  ),
                  keyboardType: TextInputType.datetime,
                  validator: _birthday,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'Пол'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Не указан')),
                    DropdownMenuItem(value: 'male', child: Text('Мужской')),
                    DropdownMenuItem(value: 'female', child: Text('Женский')),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => sex = value ?? ''),
                ),
              ] else ...[
                TextFormField(
                  controller: name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Имя'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Укажи имя'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: city,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Город'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: bio,
                  maxLength: 160,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'О себе'),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Сохраняем…' : 'Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
