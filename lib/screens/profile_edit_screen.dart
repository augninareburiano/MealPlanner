import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/app_events.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../widgets/glass.dart';

/// Edits the signed-in user's profile. Saving updates `user_profile` and fires
/// [AppEvents.bumpProfile] so the daily targets recompute across the app.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _activityLevels = [
    'sedentary',
    'light',
    'moderate',
    'active',
    'extra active',
  ];
  static const _goals = ['lose weight', 'maintain', 'gain muscle'];

  final _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dietController = TextEditingController();
  final _allergiesController = TextEditingController();

  String _gender = 'female';
  String _activity = 'sedentary';
  String _goal = 'maintain';

  bool _loading = true;
  bool _saving = false;
  late final String _userId;
  String? _email;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _userId = user?.uid ?? '';
    _email = user?.email;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dietController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await _db.getUserProfile(_userId);
    if (p != null) {
      _nameController.text = p.name ?? '';
      _contactController.text = p.contactNumber ?? '';
      _ageController.text = p.age?.toString() ?? '';
      _heightController.text = p.heightCm?.round().toString() ?? '';
      _weightController.text = p.weightKg?.round().toString() ?? '';
      _dietController.text = p.dietaryPreferences ?? '';
      _allergiesController.text = p.allergies ?? '';
      if (p.gender != null && (p.gender == 'male' || p.gender == 'female')) {
        _gender = p.gender!;
      }
      if (_activityLevels.contains(p.activityLevel)) _activity = p.activityLevel!;
      if (_goals.contains(p.healthGoal)) _goal = p.healthGoal!;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final profile = UserProfile(
      userId: _userId,
      name: _nameController.text.trim(),
      email: _email,
      contactNumber: _contactController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      gender: _gender,
      heightCm: double.tryParse(_heightController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      activityLevel: _activity,
      dietaryPreferences: _dietController.text.trim().isEmpty
          ? null
          : _dietController.text.trim(),
      allergies: _allergiesController.text.trim().isEmpty
          ? null
          : _allergiesController.text.trim(),
      healthGoal: _goal,
    );
    await _db.upsertUserProfile(profile);
    AppEvents.instance.bumpProfile();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved — targets updated.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('Personal Information'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      child: Column(
                        children: [
                          _field(_nameController, 'Name'),
                          _field(_contactController, 'Contact number',
                              keyboard: TextInputType.phone),
                          Row(
                            children: [
                              Expanded(
                                child: _field(_ageController, 'Age',
                                    keyboard: TextInputType.number,
                                    required: true),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(_heightController, 'Height (cm)',
                                    keyboard: TextInputType.number,
                                    required: true),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(_weightController, 'Weight (kg)',
                                    keyboard: TextInputType.number,
                                    required: true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Gender',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'female', label: Text('Female')),
                              ButtonSegment(value: 'male', label: Text('Male')),
                            ],
                            selected: {_gender},
                            onSelectionChanged: (s) =>
                                setState(() => _gender = s.first),
                          ),
                          const SizedBox(height: 16),
                          _dropdown('Activity level', _activity,
                              _activityLevels, (v) => _activity = v),
                          const SizedBox(height: 12),
                          _dropdown(
                              'Goal', _goal, _goals, (v) => _goal = v),
                          const SizedBox(height: 12),
                          _field(_dietController,
                              'Dietary preferences (optional)'),
                          _field(_allergiesController,
                              'Allergies (optional)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Save profile'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(_titleCase(o))),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
