import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

/// Collects the personal details that drive the app's nutrition math and saves
/// them to the local `user_profile` table.
///
/// Values are loaded when the screen opens (so the user can review/edit), and
/// written back on Save. Multi-select dietary preferences are stored as a
/// comma-separated string in the single `dietary_preferences` column.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // Dropdown options.
  static const activityLevels = <String>[
    'Sedentary (little or no exercise)',
    'Lightly active (1-3 days/week)',
    'Moderately active (3-5 days/week)',
    'Very active (6-7 days/week)',
    'Extra active (hard exercise / physical job)',
  ];

  static const healthGoals = <String>[
    'Lose weight',
    'Maintain weight',
    'Gain muscle',
  ];

  static const genders = <String>[
    'Female',
    'Male',
    'Prefer not to say',
  ];

  // Multi-select dietary preferences / restrictions.
  static const dietaryOptions = <String>[
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Low-carb',
    'Keto',
    'High-protein',
    'Dairy-free',
    'Gluten-free',
    'Nut allergy',
    'Shellfish allergy',
    'Halal',
  ];

  // Realistic input ranges (used for validation).
  static const minAge = 13;
  static const maxAge = 120;
  static const minHeightCm = 50.0;
  static const maxHeightCm = 250.0;
  static const minWeightKg = 20.0;
  static const maxWeightKg = 400.0;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _gender;
  String? _activityLevel;
  String? _healthGoal;
  final Set<String> _dietaryPreferences = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Loads any previously saved profile so the form reopens pre-filled.
  Future<void> _loadProfile() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final profile = await _db.getUserProfile(userId);
    if (!mounted) return;

    if (profile != null) {
      _nameController.text = profile.name ?? '';
      _ageController.text = profile.age?.toString() ?? '';
      _heightController.text = profile.heightCm?.toString() ?? '';
      _weightController.text = profile.weightKg?.toString() ?? '';
      _gender = profile.gender;
      _activityLevel = profile.activityLevel;
      _healthGoal = profile.healthGoal;
      _dietaryPreferences
        ..clear()
        ..addAll(_splitPreferences(profile.dietaryPreferences));
    }

    setState(() => _isLoading = false);
  }

  static List<String> _splitPreferences(String? stored) {
    if (stored == null || stored.trim().isEmpty) return const [];
    return stored
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      _showSnack('You must be signed in to save your profile.');
      return;
    }

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final dietary = _dietaryPreferences.toList()..sort();

    final profile = UserProfile(
      userId: userId,
      name: name.isEmpty ? null : name,
      email: _authService.currentUser?.email,
      age: int.tryParse(_ageController.text.trim()),
      gender: _gender,
      heightCm: double.tryParse(_heightController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      activityLevel: _activityLevel,
      dietaryPreferences: dietary.isEmpty ? null : dietary.join(', '),
      healthGoal: _healthGoal,
    );

    try {
      await _db.upsertUserProfile(profile);
      if (!mounted) return;
      _showSnack('Profile saved.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Validators ---------------------------------------------------------

  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your age';
    final age = int.tryParse(text);
    if (age == null) return 'Enter a whole number';
    if (age < ProfileScreen.minAge || age > ProfileScreen.maxAge) {
      return 'Age must be between ${ProfileScreen.minAge} '
          'and ${ProfileScreen.maxAge}';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your height';
    final height = double.tryParse(text);
    if (height == null) return 'Enter a number';
    if (height < ProfileScreen.minHeightCm ||
        height > ProfileScreen.maxHeightCm) {
      return 'Height must be between ${ProfileScreen.minHeightCm.toInt()} '
          'and ${ProfileScreen.maxHeightCm.toInt()} cm';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your weight';
    final weight = double.tryParse(text);
    if (weight == null) return 'Enter a number';
    if (weight < ProfileScreen.minWeightKg ||
        weight > ProfileScreen.maxWeightKg) {
      return 'Weight must be between ${ProfileScreen.minWeightKg.toInt()} '
          'and ${ProfileScreen.maxWeightKg.toInt()} kg';
    }
    return null;
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateAge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final g in ProfileScreen.genders)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (value) => setState(() => _gender = value),
                      validator: (value) =>
                          value == null ? 'Select your gender' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateHeight,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateWeight,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _activityLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Activity level',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final level in ProfileScreen.activityLevels)
                          DropdownMenuItem(value: level, child: Text(level)),
                      ],
                      onChanged: (value) =>
                          setState(() => _activityLevel = value),
                      validator: (value) =>
                          value == null ? 'Select your activity level' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _healthGoal,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Health goal',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final goal in ProfileScreen.healthGoals)
                          DropdownMenuItem(value: goal, child: Text(goal)),
                      ],
                      onChanged: (value) => setState(() => _healthGoal = value),
                      validator: (value) =>
                          value == null ? 'Select your health goal' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dietary preferences & restrictions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select any that apply.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in ProfileScreen.dietaryOptions)
                          FilterChip(
                            label: Text(option),
                            selected: _dietaryPreferences.contains(option),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _dietaryPreferences.add(option);
                              } else {
                                _dietaryPreferences.remove(option);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save profile'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _PrivacyNotice(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Short note on what personal data is collected, per the Data Privacy Act
/// of 2012 (RA 10173).
class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Data Privacy: The personal details above (age, gender, height, '
              'weight, activity level, dietary preferences, and health goal) '
              'are collected only to calculate your nutrition needs. They are '
              'stored on this device and are not shared with third parties, in '
              'line with the Data Privacy Act of 2012 (RA 10173).',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
