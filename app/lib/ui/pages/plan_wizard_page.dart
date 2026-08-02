import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/plan.dart';
import '../../providers/plan_provider.dart';

/// 计划生成向导（3 步）：目标 → 成绩/周期 → 每周次数 + 实时 VDOT/配速区预览。
class PlanWizardPage extends StatefulWidget {
  const PlanWizardPage({super.key});

  @override
  State<PlanWizardPage> createState() => _PlanWizardPageState();
}

class _PlanWizardPageState extends State<PlanWizardPage> {
  int _step = 0;
  String _raceType = 'full';

  bool _hasGoal = true;
  final TextEditingController _goalH = TextEditingController(text: '4');
  final TextEditingController _goalM = TextEditingController(text: '00');
  final TextEditingController _goalS = TextEditingController(text: '00');

  bool _byRaceDate = false;
  double _weeks = 18;
  DateTime? _raceDate;
  DateTime? _startDate;

  int _sessions = 4;
  final TextEditingController _vdotController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _creating = false;

  static const List<String> _stepTitles = <String>['目标距离', '成绩与周期', '每周次数'];

  @override
  void dispose() {
    _goalH.dispose();
    _goalM.dispose();
    _goalS.dispose();
    _vdotController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  int? _goalTimeSec() {
    if (!_hasGoal) return null;
    final int h = int.tryParse(_goalH.text.trim()) ?? 0;
    final int m = int.tryParse(_goalM.text.trim()) ?? 0;
    final int s = int.tryParse(_goalS.text.trim()) ?? 0;
    final int total = h * 3600 + m * 60 + s;
    return total > 0 ? total : null;
  }

  PlanParams _buildParams() {
    return PlanParams(
      raceType: _raceType,
      goalTimeSec: _goalTimeSec(),
      weeks: _byRaceDate ? null : _weeks.round(),
      raceDate:
          _byRaceDate && _raceDate != null ? toApiDate(_raceDate!) : null,
      sessionsPerWeek: _sessions,
      vdot: double.tryParse(_vdotController.text.trim()),
      startDate: _startDate != null ? toApiDate(_startDate!) : null,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _next() {
    if (_step == 1) {
      if (_hasGoal && _goalTimeSec() == null) {
        _snack('请填写有效的目标成绩（时:分:秒）');
        return;
      }
      if (_byRaceDate && _raceDate == null) {
        _snack('请选择比赛日');
        return;
      }
      setState(() => _step = 2);
      _runPreview();
      return;
    }
    setState(() => _step += 1);
  }

  Future<void> _runPreview() {
    return context.read<PlanProvider>().runPreview(_buildParams());
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    final PlanProvider provider = context.read<PlanProvider>();
    final TrainingPlan? plan = await provider.createPlan(_buildParams());
    if (!mounted) return;
    setState(() => _creating = false);
    if (plan != null) {
      Navigator.of(context).pop(true);
    } else {
      _snack(provider.error ?? '生成失败，请稍后重试');
    }
  }

  Future<void> _pickRaceDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 126)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (!mounted || picked == null) return;
    setState(() => _raceDate = picked);
  }

  Future<void> _pickStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('生成训练计划')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: List<Widget>.generate(3, (int i) {
                final bool active = i == _step;
                final bool done = i < _step;
                return Expanded(
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: active || done
                              ? AppColors.primary
                              : AppColors.surfaceDarkHigh,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${i + 1}. ${_stepTitles[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: active ? AppColors.primary : null,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _step == 0
                  ? _buildStepGoal()
                  : _step == 1
                      ? _buildStepTime()
                      : _buildStepSessions(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('上一步'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed:
                        _creating ? null : (_step < 2 ? _next : _create),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step < 2 ? '下一步' : '生成计划'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepGoal() {
    const Map<String, String> distances = <String, String>{
      '5k': '5 公里',
      '10k': '10 公里',
      'half': '21.0975 公里',
      'full': '42.195 公里',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('你的比赛目标？', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: distances.entries.map((MapEntry<String, String> e) {
            final bool selected = _raceType == e.key;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _raceType = e.key),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            raceTypeLabel(e.key),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.primary : null,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle,
                              size: 18, color: AppColors.primary),
                      ],
                    ),
                    Text(e.value,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('设定目标成绩'),
          subtitle: const Text('关闭则以「完赛」为目标'),
          value: _hasGoal,
          onChanged: (bool v) => setState(() => _hasGoal = v),
        ),
        if (_hasGoal)
          Row(
            children: <Widget>[
              _timeField(_goalH, '时'),
              const SizedBox(width: 8),
              _timeField(_goalM, '分'),
              const SizedBox(width: 8),
              _timeField(_goalS, '秒'),
            ],
          ),
        const SizedBox(height: 20),
        Text('训练周期', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('按周数')),
            ButtonSegment<bool>(value: true, label: Text('按比赛日')),
          ],
          selected: <bool>{_byRaceDate},
          onSelectionChanged: (Set<bool> s) =>
              setState(() => _byRaceDate = s.first),
        ),
        const SizedBox(height: 12),
        if (!_byRaceDate)
          Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  value: _weeks,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  label: '${_weeks.round()} 周',
                  onChanged: (double v) => setState(() => _weeks = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text('${_weeks.round()} 周',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _pickRaceDate,
            icon: const Icon(Icons.event),
            label: Text(_raceDate == null
                ? '选择比赛日'
                : '比赛日：${toApiDate(_raceDate!)}'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickStartDate,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(_startDate == null
              ? '开始日期（默认下周一）'
              : '开始：${toApiDate(_startDate!)}'),
        ),
      ],
    );
  }

  Widget _timeField(TextEditingController controller, String hint) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildStepSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('每周可训练次数', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const <ButtonSegment<int>>[
            ButtonSegment<int>(value: 3, label: Text('3')),
            ButtonSegment<int>(value: 4, label: Text('4')),
            ButtonSegment<int>(value: 5, label: Text('5')),
            ButtonSegment<int>(value: 6, label: Text('6')),
            ButtonSegment<int>(value: 7, label: Text('7')),
          ],
          selected: <int>{_sessions},
          onSelectionChanged: (Set<int> s) =>
              setState(() => _sessions = s.first),
        ),
        if (_sessions == 7)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('每周 7 练恢复风险较高，建议不超过 6 次。',
                style: TextStyle(color: AppColors.secondary, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _vdotController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'VDOT（可选，留空自动推断）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '计划名称（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Text('实时试算', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: _runPreview,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新预览'),
            ),
          ],
        ),
        const _PreviewPanel(),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (BuildContext context, PlanProvider provider, _) {
        if (provider.previewLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.previewError != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('试算失败：${provider.previewError}'),
            ),
          );
        }
        final PlanPreview? preview = provider.preview;
        if (preview == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('点击「刷新预览」查看 VDOT 与配速区间。'),
            ),
          );
        }
        final List<String> zoneOrder = <String>['E', 'M', 'T', 'I', 'R'];
        final double peakKm = preview.weeks.fold<double>(
          0,
          (double m, PlanPreviewWeek w) => w.targetKm > m ? w.targetKm : m,
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.speed, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'VDOT ${preview.vdot?.toStringAsFixed(1) ?? '--'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (preview.weeks.isNotEmpty)
                      Text(
                        '共 ${preview.weeks.length} 周 · 峰值 ${peakKm.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...zoneOrder
                    .where((String k) => preview.paceZones.containsKey(k))
                    .map((String k) {
                  final PaceZoneRange range = preview.paceZones[k]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 24,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: workoutTypeColor(k),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            k,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(workoutTypeLabel(k),
                                style:
                                    Theme.of(context).textTheme.bodySmall)),
                        Text(
                          '${formatPace(range.minSec)} – ${formatPace(range.maxSec)} /km',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }),
                if (preview.warnings.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ...preview.warnings.map(
                    (String w) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.warning_amber,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
