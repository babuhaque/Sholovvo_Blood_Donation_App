import 'package:flutter/material.dart';
import '../locale_controller.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _genders = ['Male', 'Female', 'Other'];
  DateTime? _dateOfBirth;
  DateTime? _lastDonationDate;
  String? _bloodGroup;
  String? _gender;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _dateText(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _chooseDate({required bool isBirthDate}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: isBirthDate ? DateTime(now.year - 18, now.month, now.day) : now,
      firstDate: DateTime(1900),
      lastDate: isBirthDate ? now : now,
      helpText: isBirthDate
          ? appText(context, 'Select date of birth', 'জন্ম তারিখ নির্বাচন করুন')
          : appText(context, 'Select last donation date', 'সর্বশেষ রক্তদানের তারিখ নির্বাচন করুন'),
    );
    if (selected != null && mounted) {
      setState(() {
        if (isBirthDate) {
          _dateOfBirth = selected;
        } else {
          _lastDonationDate = selected;
        }
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null || _bloodGroup == null || _gender == null) {
      setState(() => _errorMessage = appText(
        context,
        'Please select your date of birth, blood group and gender.',
        'জন্ম তারিখ, রক্তের গ্রুপ ও লিঙ্গ নির্বাচন করুন।',
      ));
      return;
    }
    if (_lastDonationDate != null && _lastDonationDate!.isAfter(DateTime.now())) {
      setState(() => _errorMessage = appText(
        context, 'Last donation date cannot be in the future.', 'সর্বশেষ রক্তদানের তারিখ ভবিষ্যতের হতে পারে না।',
      ));
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = appText(context, 'Passwords do not match.', 'পাসওয়ার্ড দুটি মিলছে না।'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _authService.registerWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (user == null) throw Exception('Account creation failed. Please try again.');

      final recentlyDonated = _lastDonationDate != null &&
          _lastDonationDate!.isAfter(DateTime.now().subtract(const Duration(days: 90)));
      await _profileService.saveProfile(UserProfile(
        uid: user.uid,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateText(_dateOfBirth),
        bloodGroup: _bloodGroup!,
        gender: _gender!,
        lastDonationDate: _dateText(_lastDonationDate),
        role: 'donor',
        isAvailable: !recentlyDonated,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appText(context, 'Registration completed!', 'রেজিস্ট্রেশন সম্পন্ন হয়েছে!')),
        backgroundColor: Colors.green,
      ));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.redAccent),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.redAccent),
        title: Text(appText(context, 'Register for Solovvo', 'Solovvo-তে নিবন্ধন করুন'),
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_rounded, size: 60, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(appText(context, 'Create your account', 'আপনার অ্যাকাউন্ট তৈরি করুন'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(height: 8),
                Text(appText(context, 'Your details help donors connect with you.', 'আপনার তথ্য দাতাদের সঙ্গে যোগাযোগ সহজ করবে।'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  ),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(appText(context, 'Full name', 'পূর্ণ নাম'), Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? appText(context, 'Enter your name', 'আপনার নাম লিখুন') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(appText(context, 'Phone number', 'মোবাইল নম্বর'), Icons.phone_outlined),
                  validator: (v) => v == null || v.trim().length < 7
                      ? appText(context, 'Enter a valid phone number', 'সঠিক মোবাইল নম্বর লিখুন') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration(appText(context, 'Email', 'ইমেইল'), Icons.email_outlined),
                  validator: (v) => v == null || !v.trim().contains('@')
                      ? appText(context, 'Enter a valid email address', 'সঠিক ইমেইল লিখুন') : null,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _chooseDate(isBirthDate: true),
                  child: InputDecorator(
                    decoration: _decoration(appText(context, 'Date of birth', 'জন্ম তারিখ'), Icons.calendar_today),
                    child: Text(_dateOfBirth == null
                        ? appText(context, 'Select date', 'তারিখ নির্বাচন করুন') : _dateText(_dateOfBirth)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroup,
                  decoration: _decoration(appText(context, 'Blood group', 'রক্তের গ্রুপ'), Icons.bloodtype),
                  hint: Text(appText(context, 'Select blood group', 'রক্তের গ্রুপ নির্বাচন করুন')),
                  items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _bloodGroup = v),
                  validator: (v) => v == null ? appText(context, 'Select blood group', 'রক্তের গ্রুপ নির্বাচন করুন') : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: _decoration(appText(context, 'Gender', 'লিঙ্গ'), Icons.people_outline),
                  hint: Text(appText(context, 'Select gender', 'লিঙ্গ নির্বাচন করুন')),
                  items: _genders.map((g) => DropdownMenuItem(
                    value: g, child: Text(g == 'Male' ? appText(context, 'Male', 'পুরুষ') :
                      g == 'Female' ? appText(context, 'Female', 'নারী') : appText(context, 'Other', 'অন্যান্য')),
                  )).toList(),
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => v == null ? appText(context, 'Select gender', 'লিঙ্গ নির্বাচন করুন') : null,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _chooseDate(isBirthDate: false),
                  child: InputDecorator(
                    decoration: _decoration(appText(context, 'Last donation date (optional)', 'সর্বশেষ রক্তদানের তারিখ (ঐচ্ছিক)'), Icons.event_available),
                    child: Text(_lastDonationDate == null
                        ? appText(context, 'Not donated yet / skip', 'এখনো রক্তদান করেননি / এড়িয়ে যান')
                        : _dateText(_lastDonationDate)),
                  ),
                ),
                if (_lastDonationDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _lastDonationDate = null),
                      child: Text(appText(context, 'Clear date', 'তারিখ মুছুন')),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _decoration(appText(context, 'Password', 'পাসওয়ার্ড'), Icons.lock_outline),
                  validator: (v) => v == null || v.length < 6
                      ? appText(context, 'At least 6 characters required', 'কমপক্ষে ৬ অক্ষর হতে হবে') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: _decoration(appText(context, 'Confirm password', 'পাসওয়ার্ড নিশ্চিত করুন'), Icons.lock_reset),
                  validator: (v) => v == null || v.isEmpty
                      ? appText(context, 'Confirm your password', 'পাসওয়ার্ড নিশ্চিত করুন') : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(appText(context, 'Create account', 'অ্যাকাউন্ট তৈরি করুন'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
