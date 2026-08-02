import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/profile.dart';
import '../../providers/profile_provider.dart';

/// 个人档案编辑（全部字段；心率区间保存后由后端自动重算）
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _restingHr = TextEditingController();
  final TextEditingController _maxHr = TextEditingController();
  final TextEditingController _weeklyKm = TextEditingController();
  final TextEditingController _years = TextEditingController();
  final TextEditingController _pb5k = TextEditingController();
  final TextEditingController _pb10k = TextEditingController();
  final TextEditingController _pbHalf = TextEditingController();
  final TextEditingController _pbFull = TextEditingController();

  String? _gender;
  DateTime? _birthDate;
  bool _initialized = false;

  @override
  void dispose() {
    _nickname.dispose();
    _height.dispose();
    _weight.dispose();
    _restingHr.dispose();
    _maxHr.dispose();
    _weeklyKm.dispose();
    _years.dispose();
    _pb5k.dispose();
    _pb10k.dispose();
    _pbHalf.dispose();
    _pbFull.dispose();
    super.dispose();
  }

  void _initFromProfile(Profile? p) {
    if (_initialized || p == null) return;
    _initialized = true;
    _nickname.text = p.nickname ?? '';
    _gender = p.gender;
    if (p.birthDate != null) _birthDate = DateTime.tryParse(p.birthDate!);
    if (p.heightCm != null) _height.text = p.heightCm!.toStringAsFixed(0);
    if (p.weightKg != null) _weight.text = p.weightKg!.toStringAsFixed(1);
    if (p.restingHr != null) _restingHr.text = '${p.restingHr}';
    if (p.maxHr != null) _maxHr.text = '${p.maxHr}';
    if (p.weeklyKm != null) _weeklyKm.text = p.weeklyKm!.toStringAsFixed(0);
    if (p.yearsRunning != null) {
      _years.text = p.yearsRunning!.toStringAsFixed(1);
    }
    _pb5k.text = formatDurationHms(p.pb5kSec);
    _pb10k.text = formatDurationHms(p.pb10kSec);
    _pbHalf.text = formatDurationHms(p.pbHalfSec);
    _pbFull.text = formatDurationHms(p.pbFullSec);
  }

  double? _double(TextEditingController c) =>
      double.tryParse(c.text.trim());

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  String? _validatePb(String? v) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (parseDurationText(t) == null) {
      return '格式：时:分:秒 或 分:秒';
    }
    return null;
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1930),
      lastDate: now,
    );
    if (!mounted || picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ProfileProvider provider = context.read<ProfileProvider>();
    final Profile updated = Profile(
      nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
      gender: _gender,
      birthDate: _birthDate != null ? toApiDate(_birthDate!) : null,
      heightCm: _double(_height),
      weightKg: _double(_weight),
      restingHr: _int(_restingHr),
      maxHr: _int(_maxHr),
      weeklyKm: _double(_weeklyKm),
      yearsRunning: _double(_years),
      pb5kSec: parseDurationText(_pb5k.text),
      pb10kSec: parseDurationText(_pb10k.text),
      pbHalfSec: parseDurationText(_pbHalf.text),
      pbFullSec: parseDurationText(_pbFull.text),
    );
    final bool ok = await provider.save(updated);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('档案已保存，心率区间已自动重算')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? '保存失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileProvider provider = context.watch<ProfileProvider>();
    _initFromProfile(provider.profile);
    return Scaffold(
      appBar: AppBar(title: const Text('编辑档案')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nickname,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: '性别',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                          value: 'male', child: Text('男')),
                      DropdownMenuItem<String>(
                          value: 'female', child: Text('女')),
                      DropdownMenuItem<String>(
                          value: 'other', child: Text('其他')),
                    ],
                    onChanged: (String? v) => setState(() => _gender = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickBirthDate,
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(_birthDate == null
                        ? '出生日期'
                        : toApiDate(_birthDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numField(_height, '身高 cm'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(_weight, '体重 kg'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numField(_restingHr, '静息心率'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(_maxHr, '最大心率'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numField(_weeklyKm, '当前周跑量 km'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(_years, '跑龄（年）'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('个人最好成绩（PB，格式 时:分:秒）',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: _pbField(_pb5k, '5K')),
                const SizedBox(width: 8),
                Expanded(child: _pbField(_pb10k, '10K')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: _pbField(_pbHalf, '半马')),
                const SizedBox(width: 8),
                Expanded(child: _pbField(_pbFull, '全马')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: provider.saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: provider.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(provider.saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (String? v) {
        final String t = (v ?? '').trim();
        if (t.isEmpty) return null;
        if (double.tryParse(t) == null) return '请输入数字';
        return null;
      },
    );
  }

  Widget _pbField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0:20:00',
        border: const OutlineInputBorder(),
      ),
      validator: _validatePb,
    );
  }
}
