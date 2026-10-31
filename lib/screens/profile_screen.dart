import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';
import '../models/donation_record.dart';
import '../services/profile_service.dart';
import '../services/location_service.dart';
import '../services/donation_history_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final DonationHistoryService _donationHistoryService = DonationHistoryService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _dobController;
  late TextEditingController _lastDonationController;

  String _selectedBloodGroup = 'A+';
  String _selectedGender = 'Male';
  String _selectedRole = 'donor';
  bool _isAvailable = true;
  double? _cachedLatitude;
  double? _cachedLongitude;
  DateTime? _locationUpdatedAt;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdatingAvailability = false;
  bool _isUpdatingLocation = false;
  String _errorMessage = '';

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _roles = ['donor', 'recipient'];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _dobController = TextEditingController();
    _lastDonationController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _dobController.dispose();
    _lastDonationController.dispose();
    super.dispose();
  }

  String _safeFormatDate(String rawDate) {
    if (rawDate.trim().isEmpty) return '';
    try {
      DateTime parsed = DateTime.parse(rawDate.trim());
      return "${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;
    try {
      UserProfile? profile = await _profileService.getProfile(_currentUser.uid);
      if (profile != null) {
        setState(() {
          _fullNameController.text = profile.fullName;
          _phoneNumberController.text = profile.phoneNumber;
          _dobController.text = _safeFormatDate(profile.dateOfBirth);
          _selectedBloodGroup = profile.bloodGroup;
          _selectedGender = profile.gender;
          _lastDonationController.text = _safeFormatDate(profile.lastDonationDate);
          _selectedRole = profile.role;
          _isAvailable = profile.isAvailable;
          _cachedLatitude = profile.latitude;
          _cachedLongitude = profile.longitude;
          _locationUpdatedAt = profile.locationUpdatedAt;
        });
        _checkDonationReminder(_lastDonationController.text);
      } else {
        _fullNameController.text = _currentUser.displayName ?? '';
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkDonationReminder(String lastDateStr) {
    if (lastDateStr.trim().isNotEmpty) {
      try {
        DateTime lastDate = DateTime.parse(lastDateStr.trim());
        int daysSinceDonation = DateTime.now().difference(lastDate).inDays;
        if (daysSinceDonation >= 90) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Donation Reminder'),
                content: const Text(
                  'It has been over 3 months (90 days) since your last recorded blood donation. If you are feeling healthy and eligible, consider donating again to save lives!',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _handleAvailabilityChange(bool value) async {
    if (_currentUser == null || _selectedRole != 'donor') return;

    setState(() {
      _isAvailable = value;
      _isUpdatingAvailability = true;
      _errorMessage = '';
    });

    try {
      await _profileService.updateAvailability(_currentUser.uid, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Status: Available for donation' : 'Status: Unavailable for donation'),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isAvailable = !value;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvailability = false;
        });
      }
    }
  }

  Future<void> _updateMyLocation() async {
    if (_currentUser == null) return;

    setState(() {
      _isUpdatingLocation = true;
      _errorMessage = '';
    });

    try {
      Position? position = await LocationService.getCurrentPositionWithPermissionCheck();
      if (position != null) {
        await _profileService.updateLocation(_currentUser.uid, position.latitude, position.longitude);
        
        setState(() {
          _cachedLatitude = position.latitude;
          _cachedLongitude = position.longitude;
          _locationUpdatedAt = DateTime.now();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'Failed to obtain current GPS position.';
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    DateTime initialDate = DateTime.tryParse(_dobController.text) ?? DateTime(1995, 1, 1);
    if (initialDate.isAfter(DateTime.now())) {
      initialDate = DateTime.now();
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectLastDonationDate(BuildContext context) async {
    DateTime initialDate = DateTime.tryParse(_lastDonationController.text) ?? DateTime.now();
    if (initialDate.isAfter(DateTime.now())) {
      initialDate = DateTime.now();
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select Last Donation Date',
    );

    if (picked != null) {
      setState(() {
        _lastDonationController.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _showAddDonationDialog(BuildContext context) async {
    final hospitalController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String dialogError = '';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Donation Record'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialogError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(dialogError, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  TextField(
                    controller: hospitalController,
                    decoration: const InputDecoration(labelText: 'Hospital Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${selectedDate.toString().substring(0, 10)}'),
                      TextButton(
                        onPressed: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            if (picked.isAfter(DateTime.now())) {
                              setDialogState(() {
                                dialogError = 'Donation date cannot be in the future.';
                              });
                              return;
                            }
                            setDialogState(() {
                              selectedDate = picked;
                              dialogError = '';
                            });
                          }
                        },
                        child: const Text('Change Date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (hospitalController.text.trim().isEmpty) {
                      setDialogState(() {
                        dialogError = 'Please enter hospital name.';
                      });
                      return;
                    }
                    if (selectedDate.isAfter(DateTime.now())) {
                      setDialogState(() {
                        dialogError = 'Donation date cannot be in the future.';
                      });
                      return;
                    }

                    if (_currentUser != null) {
                      try {
                        DonationRecord record = DonationRecord(
                          id: '',
                          donorUid: _currentUser.uid,
                          bloodGroup: _selectedBloodGroup,
                          hospitalName: hospitalController.text.trim(),
                          status: 'pending',
                          donationDate: selectedDate,
                        );
                        await _donationHistoryService.addDonationRecord(record);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Donation record added (Pending verification).'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setDialogState(() {
                          dialogError = e.toString();
                        });
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      setState(() {
        _isSaving = true;
        _errorMessage = '';
      });

      try {
        Position? position = await LocationService.getCurrentPositionSafely();
        double? lat = position?.latitude ?? _cachedLatitude;
        double? lng = position?.longitude ?? _cachedLongitude;
        DateTime? updatedTime = position != null ? DateTime.now() : _locationUpdatedAt;

        bool availableStatus = _selectedRole == 'donor' ? _isAvailable : false;

        UserProfile profile = UserProfile(
          uid: _currentUser.uid,
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          email: _currentUser.email ?? '',
          dateOfBirth: _dobController.text.trim(),
          bloodGroup: _selectedBloodGroup,
          gender: _selectedGender,
          lastDonationDate: _lastDonationController.text.trim(),
          role: _selectedRole,
          isAvailable: availableStatus,
          latitude: lat,
          longitude: lng,
          locationUpdatedAt: updatedTime,
        );

        await _profileService.saveProfile(profile);

        setState(() {
          _cachedLatitude = lat;
          _cachedLongitude = lng;
          if (position != null) _locationUpdatedAt = updatedTime;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLocationFresh = _locationUpdatedAt != null &&
        DateTime.now().difference(_locationUpdatedAt!).inHours <= 24;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donor Profile'),
        backgroundColor: Colors.redAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                      ),
                    
                    // Location Status Card
                    Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              isLocationFresh ? Icons.location_on : Icons.location_off,
                              color: isLocationFresh ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLocationFresh ? 'Location Status: Fresh' : 'Location Status: Stale / Unavailable',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isLocationFresh ? Colors.green : Colors.orange),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _locationUpdatedAt != null
                                        ? 'Last updated: ${_locationUpdatedAt.toString().substring(0, 16)}'
                                        : 'No GPS coordinates saved yet',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: _isUpdatingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.my_location, size: 16),
                              label: const Text('Update GPS', style: TextStyle(fontSize: 12)),
                              onPressed: _isUpdatingLocation ? null : _updateMyLocation,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Donation History Section
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Donation History',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Record', style: TextStyle(fontSize: 12)),
                                  onPressed: () => _showAddDonationDialog(context),
                                ),
                              ],
                            ),
                            const Divider(),
                            StreamBuilder<List<DonationRecord>>(
                              stream: _currentUser != null
                                  ? _donationHistoryService.getDonorDonations(_currentUser.uid)
                                  : const Stream.empty(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                                  ));
                                }

                                if (snapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      'Error loading donation history: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }

                                final records = snapshot.data ?? [];
                                final confirmedCount = records.where((r) => r.status == 'confirmed').length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Confirmed Donations: $confirmedCount',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const SizedBox(height: 8),
                                    if (records.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Text(
                                          'No donation records found. Tap "Add Record" to log a donation.',
                                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                        ),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: records.length,
                                        itemBuilder: (context, index) {
                                          final rec = records[index];
                                          bool isConfirmed = rec.status == 'confirmed';
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              backgroundColor: isConfirmed ? Colors.green.shade100 : Colors.orange.shade100,
                                              child: Icon(
                                                isConfirmed ? Icons.check_circle : Icons.hourglass_top,
                                                color: isConfirmed ? Colors.green : Colors.orange,
                                              ),
                                            ),
                                            title: Text(rec.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text(
                                              'Blood: ${rec.bloodGroup} | Date: ${rec.donationDate != null ? rec.donationDate.toString().substring(0, 10) : 'N/A'}',
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    isConfirmed ? 'Verified' : 'Pending',
                                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                                  ),
                                                  backgroundColor: isConfirmed ? Colors.green : Colors.orange,
                                                  padding: EdgeInsets.zero,
                                                ),
                                                if (!isConfirmed) ...[
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                                    onPressed: () async {
                                                      try {
                                                        await FirebaseFirestore.instance
                                                            .collection('donation_history')
                                                            .doc(rec.id)
                                                            .delete();
                                                        if (!context.mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Pending donation record deleted.'),
                                                            backgroundColor: Colors.green,
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        if (!context.mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Error deleting record: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDateOfBirth(context),
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your date of birth';
                        }
                        DateTime? dob = DateTime.tryParse(value);
                        if (dob == null) {
                          return 'Invalid date format. Please use YYYY-MM-DD';
                        }
                        if (dob.isAfter(DateTime.now())) {
                          return 'Date of birth cannot be in the future';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Blood Group',
                        prefixIcon: Icon(Icons.bloodtype, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                      ),
                      items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                      // ignore: deprecated_member_use
                      value: _selectedBloodGroup,
                      onChanged: (val) => setState(() => _selectedBloodGroup = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.wc, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                      ),
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      // ignore: deprecated_member_use
                      value: _selectedGender,
                      onChanged: (val) => setState(() => _selectedGender = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastDonationController,
                      readOnly: true,
                      onTap: () => _selectLastDonationDate(context),
                      decoration: const InputDecoration(
                        labelText: 'Last Donation Date (YYYY-MM-DD)',
                        prefixIcon: Icon(Icons.history, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        helperText: 'Tap to select date (Optional)',
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          DateTime? donationDate = DateTime.tryParse(value.trim());
                          if (donationDate == null) {
                            return 'Invalid date format. Please use YYYY-MM-DD';
                          }
                          if (donationDate.isAfter(DateTime.now())) {
                            return 'Last donation date cannot be in the future';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'User Role',
                        prefixIcon: Icon(Icons.badge_outlined, color: Colors.redAccent),
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                      // ignore: deprecated_member_use
                      value: _selectedRole,
                      onChanged: (val) {
                        setState(() {
                          _selectedRole = val!;
                          if (_selectedRole != 'donor') {
                            _isAvailable = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Donor Availability Toggle (Only visible if role is 'donor')
                    if (_selectedRole == 'donor') ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: SwitchListTile(
                            title: const Text('Available for Donation', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              _isAvailable ? 'You are currently visible to blood seekers' : 'You are currently offline',
                              style: TextStyle(color: _isAvailable ? Colors.green : Colors.grey),
                            ),
                            value: _isAvailable,
                            activeThumbColor: Colors.redAccent,
                            secondary: _isUpdatingAvailability
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                  )
                                : Icon(
                                    _isAvailable ? Icons.check_circle : Icons.cancel,
                                    color: _isAvailable ? Colors.green : Colors.grey,
                                  ),
                            onChanged: _isUpdatingAvailability ? null : _handleAvailabilityChange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Save Profile',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
