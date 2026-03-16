import 'package:flutter/material.dart';
import 'training_plan_model.dart';
import 'plan_storage.dart';
import 'auth_storage.dart';

// ─────────────────────────────────────────────
//  CreateTrainingPlanScreen
//
//  Manual inputs:   Name · Age Group · Weight (kg) · Height (cm) · Experience Level
//                   Calorie Intake (pre-filled with recommendation, user can change)
//  Auto-calculated: BMI → Body Type
// ─────────────────────────────────────────────

class CreateTrainingPlanScreen extends StatefulWidget {
  const CreateTrainingPlanScreen({super.key});

  @override
  State<CreateTrainingPlanScreen> createState() => _CreateTrainingPlanScreenState();
}

class _CreateTrainingPlanScreenState extends State<CreateTrainingPlanScreen> {
  final _nameController   = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  AgeGroup        _age = AgeGroup.adult;
  ExperienceLevel _exp = ExperienceLevel.beginner;

  /// Starts null — gets set to recommendation as soon as weight+height are valid.
  /// User can then freely change it.
  CalorieIntake? _calorieIntake;

  /// Tracks the last recommendation so we can show the "Recommended" badge.
  CalorieIntake? _lastRecommendation;

  bool _generating = false;

  // Live-computed from weight + height fields
  BodyMetrics? get _metrics {
    final w = double.tryParse(_weightController.text);
    final h = double.tryParse(_heightController.text);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return BodyMetrics(weightKg: w, heightCm: h);
  }

  void _onMeasurementChanged() {
    setState(() {
      final m = _metrics;
      if (m != null) {
        final rec = m.recommendedCalorieIntake;
        // Auto-fill only if the user hasn't manually deviated yet
        if (_calorieIntake == null || _calorieIntake == _lastRecommendation) {
          _calorieIntake = rec;
        }
        _lastRecommendation = rec;
      } else {
        _calorieIntake = null;
        _lastRecommendation = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_onMeasurementChanged);
    _heightController.addListener(_onMeasurementChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final name = _nameController.text.trim();
    final m    = _metrics;

    if (name.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }
    if (m == null) {
      _showSnack('Please enter a valid weight and height');
      return;
    }
    if (_calorieIntake == null) {
      _showSnack('Please select a calorie intake');
      return;
    }

    setState(() => _generating = true);

    final profile = UserProfile(
      name: name,
      ageGroup: _age,
      experienceLevel: _exp,
      metrics: m,
      calorieIntake: _calorieIntake!,
    );

    final today  = DateTime.now();
    final start  = DateTime(today.year, today.month, today.day);
    final userId = await AuthStorage.getUserId();
    final plan   = TrainingPlanGenerator.generate(
      profile,
      start,
      ownerId: userId ?? TrainingPlan.ownerOffline,
    );
    await PlanStorage.save(plan);

    setState(() => _generating = false);
    if (!mounted) return;
    Navigator.pop(context, plan);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─── UI helpers ────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black45,
        letterSpacing: 1.0,
      ),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required String suffix,
    TextInputType keyboardType = TextInputType.number,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix.isNotEmpty ? suffix : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _chipRow<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required void Function(T) onSelect,
    T? recommended,
  }) =>
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: values.map((v) {
          final isSel = v == selected;
          final isRec = v == recommended;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ChoiceChip(
                label: Text(label(v)),
                selected: isSel,
                onSelected: (_) => setState(() => onSelect(v)),
                selectedColor: Colors.black,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                side: BorderSide(
                  color: isRec && !isSel
                      ? Colors.green.shade400
                      : isSel
                      ? Colors.black
                      : Colors.grey.shade300,
                  width: isRec && !isSel ? 1.5 : 1.0,
                ),
              ),
              // "Recommended" badge
              if (isRec)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Rec.',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      );

  // ─── Auto-calculated BMI + body type card ──

  Widget _autoResultCard(BodyMetrics m) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AUTO-CALCULATED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white54,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _autoRow(Icons.monitor_weight_outlined, 'BMI',
            m.bmi.toStringAsFixed(1)),
        const SizedBox(height: 8),
        _autoRow(Icons.accessibility_new, 'Body Type', m.bodyTypeLabel),
      ],
    ),
  );

  Widget _autoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.white70),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(fontSize: 13, color: Colors.white60)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    ],
  );

  // ─── TIM preview ───────────────────────────

  Widget _timCard(BodyMetrics m) {
    if (_calorieIntake == null) return const SizedBox.shrink();
    final profile = UserProfile(
      name: '',
      ageGroup: _age,
      experienceLevel: _exp,
      metrics: m,
      calorieIntake: _calorieIntake!,
    );
    final tim = TrainingPlanGenerator.computeTIM(profile);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                'Intensity Multiplier (TIM): ${tim.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_timDescription(tim),
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m   = _metrics;
    final rec = m?.recommendedCalorieIntake;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Create Training Plan',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Name
                  _sectionTitle('YOUR NAME'),
                  _textField(
                    controller: _nameController,
                    hint: 'Enter your name',
                    suffix: '',
                    keyboardType: TextInputType.name,
                  ),

                  // Age Group
                  _sectionTitle('AGE GROUP'),
                  _chipRow<AgeGroup>(
                    values: AgeGroup.values,
                    selected: _age,
                    label: (v) => v.name[0].toUpperCase() + v.name.substring(1),
                    onSelect: (v) => _age = v,
                  ),

                  // Weight
                  _sectionTitle('WEIGHT'),
                  _textField(
                      controller: _weightController,
                      hint: 'e.g. 70',
                      suffix: 'kg'),

                  // Height
                  _sectionTitle('HEIGHT'),
                  _textField(
                      controller: _heightController,
                      hint: 'e.g. 170',
                      suffix: 'cm'),

                  // Auto-calculated BMI + body type
                  if (m != null) ...[
                    _sectionTitle('CALCULATED FOR YOU'),
                    _autoResultCard(m),
                  ],

                  // Experience Level
                  _sectionTitle('EXPERIENCE LEVEL'),
                  _chipRow<ExperienceLevel>(
                    values: ExperienceLevel.values,
                    selected: _exp,
                    label: (v) => v.name[0].toUpperCase() + v.name.substring(1),
                    onSelect: (v) => _exp = v,
                  ),

                  // Calorie Intake — recommended pre-selected, user can override
                  _sectionTitle('CALORIE INTAKE'),
                  if (rec != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 14, color: Colors.green),
                          const SizedBox(width: 5),
                          Text(
                            'Recommended: ${_calLabel(rec)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  _chipRow<CalorieIntake>(
                    values: CalorieIntake.values,
                    selected: _calorieIntake,
                    recommended: rec,
                    label: _calLabel,
                    onSelect: (v) => _calorieIntake = v,
                  ),

                  // TIM preview
                  if (m != null && _calorieIntake != null) ...[
                    const SizedBox(height: 20),
                    _timCard(m),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                    : const Text('Generate 1 Month Plan',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Your plan starts today and runs for 4 weeks.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calLabel(CalorieIntake v) {
    switch (v) {
      case CalorieIntake.deficit:     return 'Deficit';
      case CalorieIntake.maintenance: return 'Maintenance';
      case CalorieIntake.surplus:     return 'Surplus';
    }
  }

  String _timDescription(double tim) {
    if (tim < 0.80) return 'Light intensity — gentle progressive plan.';
    if (tim < 1.00) return 'Moderate-light intensity — building a solid base.';
    if (tim < 1.20) return 'Moderate intensity — balanced aerobic development.';
    if (tim < 1.35) return 'Moderate-high intensity — strong endurance focus.';
    return 'High intensity — advanced load. Ensure adequate recovery.';
  }
}