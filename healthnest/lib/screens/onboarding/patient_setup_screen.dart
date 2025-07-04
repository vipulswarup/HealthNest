import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../providers/user_provider.dart';
import 'onboarding_complete_screen.dart';

class PatientSetupScreen extends StatefulWidget {
  const PatientSetupScreen({super.key});

  @override
  State<PatientSetupScreen> createState() => _PatientSetupScreenState();
}

class _PatientSetupScreenState extends State<PatientSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  String _selectedGender = 'Male';
  final _bloodGroupController = TextEditingController();
  final _abhaController = TextEditingController();

  DateTime? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _bloodGroupController.dispose();
    _abhaController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground,
          child: Column(
            children: [
              Container(
                height: 40,
                color: CupertinoColors.systemGrey6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () => Navigator.pop(context, _selectedDate ?? DateTime.now()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? DateTime.now(),
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(1900),
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      _selectedDate = newDate;
                      _dateController.text = '${newDate.day}/${newDate.month}/${newDate.year}';
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _savePatient() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      try {
        final patient = Patient(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          dateOfBirth: _selectedDate!,
          gender: _selectedGender,
          abhaNumber: _abhaController.text.trim().isEmpty ? null : _abhaController.text.trim(),
          bloodGroup: _bloodGroupController.text.trim().isEmpty ? null : _bloodGroupController.text.trim(),
          emergencyContacts: [],
          preferences: {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          hospitalIdentifiers: [],
          mobileNumbers: [],
        );

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.addPatient(patient);
        
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => const OnboardingCompleteScreen(),
            fullscreenDialog: true,
          ),
        );
      } catch (e) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Error creating patient: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Add First Patient'),
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_add,
                          size: 30,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add your first patient profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This could be yourself or a family member',
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Form Fields
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: CupertinoIcons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildDateField(),
                      const SizedBox(height: 20),
                      _buildGenderField(),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _bloodGroupController,
                        label: 'Blood Group (Optional)',
                        icon: CupertinoIcons.drop,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _abhaController,
                        label: 'ABHA Number (Optional)',
                        icon: CupertinoIcons.heart,
                        helperText: 'Ayushman Bharat Health Account Number',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _savePatient,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: 'Enter $label',
          decoration: BoxDecoration(
            border: Border.all(
              color: CupertinoColors.systemGrey4,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.tertiaryLabel,
            ),
          ),
        ],
        if (validator != null) ...[
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final error = validator(controller.text);
              if (error != null) {
                return Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemRed,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              size: 20,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(width: 8),
            const Text(
              'Date of Birth',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: CupertinoColors.systemGrey4,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateController.text.isEmpty ? 'Select date of birth' : _dateController.text,
                    style: TextStyle(
                      color: _dateController.text.isEmpty 
                          ? CupertinoColors.placeholderText 
                          : CupertinoColors.label,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ),
          ),
        ),
        if (_dateController.text.isEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Please select date of birth',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.person_crop_circle,
              size: 20,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(width: 8),
            const Text(
              'Gender',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: CupertinoColors.systemGrey4,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: _selectedGender,
            children: const {
              'Male': Text('Male'),
              'Female': Text('Female'),
              'Other': Text('Other'),
            },
            onValueChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _selectedGender = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }
} 