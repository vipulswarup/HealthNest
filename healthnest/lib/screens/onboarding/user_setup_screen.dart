import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'patient_setup_screen.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({super.key});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  List<TextEditingController> _emailControllers = [TextEditingController()];
  List<Map<String, TextEditingController>> _mobileControllers = [
    {
      'countryCode': TextEditingController(text: '+91'),
      'number': TextEditingController(),
    }
  ];

  bool _showAdvancedNameFields = false;

  @override
  void dispose() {
    _titleController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    for (var c in _emailControllers) c.dispose();
    for (var m in _mobileControllers) {
      m['countryCode']?.dispose();
      m['number']?.dispose();
    }
    super.dispose();
  }

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final emails = _emailControllers
            .map((c) => c.text.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final mobileNumbers = _mobileControllers
            .where((m) => m['number']!.text.trim().isNotEmpty)
            .map((m) => {
                  'countryCode': m['countryCode']!.text.trim(),
                  'number': m['number']!.text.trim(),
                })
            .toList();
        await userProvider.createUser(
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          title: _titleController.text.trim(),
          suffix: _suffixController.text.trim(),
          emails: emails,
          mobileNumbers: mobileNumbers,
        );
        
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const PatientSetupScreen(),
            fullscreenDialog: true,
          ),
        );
      } catch (e) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Error creating user: $e'),
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
        middle: Text('Setup Your Profile'),
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
                          color: CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_circle,
                          size: 30,
                          color: CupertinoColors.systemBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tell us about yourself',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This information helps us personalize your experience',
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
                      if (_showAdvancedNameFields) ...[
                        _buildTextField(
                          controller: _titleController,
                          label: 'Title (Optional)',
                          icon: CupertinoIcons.person,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        icon: CupertinoIcons.person,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_showAdvancedNameFields) ...[
                        _buildTextField(
                          controller: _middleNameController,
                          label: 'Middle Name (Optional)',
                          icon: CupertinoIcons.person,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name (Optional)',
                        icon: CupertinoIcons.person,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      if (_showAdvancedNameFields) ...[
                        _buildTextField(
                          controller: _suffixController,
                          label: 'Suffix (Optional)',
                          icon: CupertinoIcons.person,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _showAdvancedNameFields = !_showAdvancedNameFields;
                            });
                          },
                          child: Text(_showAdvancedNameFields ? 'Hide additional name fields' : 'Add title/middle/suffix'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildEmailFields(),
                      const SizedBox(height: 20),
                      _buildMobileFields(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _saveUser,
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          placeholder: 'Enter your $label',
          decoration: BoxDecoration(
            border: Border.all(
              color: CupertinoColors.systemGrey4,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
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

  Widget _buildEmailFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.mail, size: 20, color: CupertinoColors.systemBlue),
            const SizedBox(width: 8),
            const Text('Email Addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add_circled, size: 22),
              onPressed: () {
                setState(() {
                  _emailControllers.add(TextEditingController());
                });
              },
            ),
          ],
        ),
        ...List.generate(_emailControllers.length, (i) => Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _emailControllers[i],
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enableSuggestions: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                placeholder: 'Email Address',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (_emailControllers.length > 1)
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.minus_circled, color: CupertinoColors.systemRed, size: 22),
                onPressed: () {
                  setState(() {
                    _emailControllers.removeAt(i);
                  });
                },
              ),
          ],
        )),
      ],
    );
  }

  Widget _buildMobileFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.phone, size: 20, color: CupertinoColors.systemBlue),
            const SizedBox(width: 8),
            const Text('Mobile Numbers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add_circled, size: 22),
              onPressed: () {
                setState(() {
                  _mobileControllers.add({
                    'countryCode': TextEditingController(text: '+91'),
                    'number': TextEditingController(),
                  });
                });
              },
            ),
          ],
        ),
        ...List.generate(_mobileControllers.length, (i) => Row(
          children: [
            SizedBox(
              width: 70,
              child: CupertinoTextField(
                controller: _mobileControllers[i]['countryCode'],
                placeholder: '+91',
                keyboardType: TextInputType.phone,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CupertinoTextField(
                controller: _mobileControllers[i]['number'],
                placeholder: 'Mobile Number',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (_mobileControllers.length > 1)
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.minus_circled, color: CupertinoColors.systemRed, size: 22),
                onPressed: () {
                  setState(() {
                    _mobileControllers.removeAt(i);
                  });
                },
              ),
          ],
        )),
      ],
    );
  }
} 