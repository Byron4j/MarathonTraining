import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';

/// 手动录入活动表单
class ActivityEditPage extends StatefulWidget {
  const ActivityEditPage({super.key});

  @override
  State<ActivityEditPage> createState() => _ActivityEditPageState();
}

class _ActivityEditPageState extends State<ActivityEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durH = TextEditingController(text: '0');
  final TextEditingController _durM = TextEditingController();
  final TextEditingController _durS = TextEditingController();
  final TextEditingController _avgHrController = TextEditingController();
  final TextEditingController _maxHrController = TextEditingController();
  final TextEditingController _cadenceController = TextEditingController();
  final TextEditingController _elevationController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();

  String _sport = 'run';
  DateTime _start = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _distanceController.dispose();
    _durH.dispose();
    _durM.dispose();
    _durS.dispose();
    _avgHrController.dispose();
    _maxHrController.dispose();
    _cadenceController.dispose();
    _elevationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted || date == null) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (!mounted) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _start.hour,
        time?.minute ?? _start.minute,
      );
    });
  }

  int? _optionalInt(TextEditingController c) {
    final String t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final double distanceKm = double.parse(_distanceController.text.trim());
    final int durationSec = (int.tryParse(_durH.text.trim()) ?? 0) * 3600 +
        (int.tryParse(_durM.text.trim()) ?? 0) * 60 +
        (int.tryParse(_durS.text.trim()) ?? 0);
    if (durationSec <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的时长')),
      );
      return;
    }
    setState(() => _saving = true);
    final Map<String, dynamic> body = <String, dynamic>{
      'sport': _sport,
      'startTime': _start.millisecondsSinceEpoch,
      'durationSec': durationSec,
      'distanceM': (distanceKm * 1000).round(),
      if (_optionalInt(_avgHrController) != null)
        'avgHr': _optionalInt(_avgHrController),
      if (_optionalInt(_maxHrController) != null)
        'maxHr': _optionalInt(_maxHrController),
      if (_optionalInt(_cadenceController) != null)
        'avgCadence': _optionalInt(_cadenceController),
      if (_optionalInt(_elevationController) != null)
        'elevationGainM': _optionalInt(_elevationController),
      if (_optionalInt(_caloriesController) != null)
        'calories': _optionalInt(_caloriesController),
    };
    final ActivitiesProvider provider = context.read<ActivitiesProvider>();
    final Activity? created = await provider.createManual(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (created != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? '保存失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动录入活动')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<String>(
              value: _sport,
              decoration: const InputDecoration(
                labelText: '运动类型',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'run', child: Text('跑步')),
                DropdownMenuItem<String>(
                    value: 'trail_run', child: Text('越野跑')),
                DropdownMenuItem<String>(
                    value: 'treadmill', child: Text('跑步机')),
              ],
              onChanged: (String? v) =>
                  setState(() => _sport = v ?? 'run'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.event),
              label: Text('开始时间：${formatDateTime(_start.millisecondsSinceEpoch)}'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _distanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '距离（公里）',
                border: OutlineInputBorder(),
              ),
              validator: (String? v) {
                final double? d = double.tryParse((v ?? '').trim());
                if (d == null || d <= 0) return '请输入有效距离';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _durH,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _durM,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '分',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? v) {
                      if ((v ?? '').trim().isEmpty) return '必填';
                      final int? m = int.tryParse(v!.trim());
                      if (m == null || m < 0 || m > 59) return '0–59';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _durS,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '秒',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? v) {
                      if ((v ?? '').trim().isEmpty) return '必填';
                      final int? s = int.tryParse(v!.trim());
                      if (s == null || s < 0 || s > 59) return '0–59';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _avgHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '平均心率（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _maxHrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最大心率（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _cadenceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '步频 spm（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _elevationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '爬升 m（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '热量 kcal（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
