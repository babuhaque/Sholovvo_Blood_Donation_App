import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/blood_request.dart';
import '../services/blood_request_service.dart';
import '../services/location_service.dart';

class CreateBloodRequestScreen extends StatefulWidget {
  const CreateBloodRequestScreen({super.key});

  @override
  State<CreateBloodRequestScreen> createState() => _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final BloodRequestService _requestService = BloodRequestService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bagsController = TextEditingController();
  final TextEditingController _hospitalNameController = TextEditingController();
  final TextEditingController _hospitalAddressController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedBloodGroup = 'A+';
  String _selectedRequestType = 'Normal';
  bool _isLoading = false;
  String _errorMessage = '';

  GoogleMapController? _mapController;
  LatLng _selectedLatLng = const LatLng(23.8103, 90.4125); // Default Dhaka
  Set<Marker> _markers = {};

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _requestTypes = ['Normal', 'Emergency'];

  @override
  void initState() {
    super.initState();
    _initMapLocation();
  }

  Future<void> _initMapLocation() async {
    Position? pos = await LocationService.getCurrentPositionSafely();
    if (pos != null) {
      setState(() {
        _selectedLatLng = LatLng(pos.latitude, pos.longitude);
        _markers = {
          Marker(
            markerId: const MarkerId('request_loc'),
            position: _selectedLatLng,
            draggable: true,
            onDragEnd: (newPos) {
              setState(() {
                _selectedLatLng = newPos;
              });
            },
          ),
        };
      });
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_selectedLatLng, 15));
      }
    } else {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('request_loc'),
            position: _selectedLatLng,
            draggable: true,
          ),
        };
      });
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _phoneController.dispose();
    _bagsController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _dateTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        if (!context.mounted) return;
        final formattedDateTime =
            "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')} ${pickedTime.format(context)}";
        setState(() {
          _dateTimeController.text = formattedDateTime;
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        BloodRequest request = BloodRequest(
          id: '',
          userId: _currentUser.uid,
          patientName: _patientNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          bloodGroup: _selectedBloodGroup,
          bloodBags: int.tryParse(_bagsController.text.trim()) ?? 1,
          hospitalName: _hospitalNameController.text.trim(),
          hospitalAddress: _hospitalAddressController.text.trim(),
          requiredDateTime: _dateTimeController.text.trim(),
          requestType: _selectedRequestType,
          notes: _notesController.text.trim(),
          status: 'open',
          latitude: _selectedLatLng.latitude,
          longitude: _selectedLatLng.longitude,
        );

        await _requestService.createRequest(request);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Blood Request'),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
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
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Patient / Recipient Name',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter patient name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter contact phone number' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedBloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Required Blood Group',
                  prefixIcon: Icon(Icons.bloodtype, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                onChanged: (val) => setState(() => _selectedBloodGroup = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bagsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Blood Bags',
                  prefixIcon: Icon(Icons.water_drop_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter number of bags';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Please enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hospitalNameController,
                decoration: const InputDecoration(
                  labelText: 'Hospital Name',
                  prefixIcon: Icon(Icons.local_hospital_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter hospital name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hospitalAddressController,
                decoration: const InputDecoration(
                  labelText: 'Hospital Address',
                  prefixIcon: Icon(Icons.location_on_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter hospital address' : null,
              ),
              const SizedBox(height: 16),

              // Interactive Google Map for location pinning
              const Text(
                'Pin Hospital / Request Location on Map:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap on the map or drag the marker to set the exact request location.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    mapId: '7edc483004bba6dd19dacbd1',
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: _selectedLatLng,
                      zoom: 14,
                    ),
                    markers: _markers,
                    onTap: (latLng) {
                      setState(() {
                        _selectedLatLng = latLng;
                        _markers = {
                          Marker(
                            markerId: const MarkerId('request_loc'),
                            position: latLng,
                            draggable: true,
                            onDragEnd: (newPos) {
                              setState(() {
                                _selectedLatLng = newPos;
                              });
                            },
                          ),
                        };
                      });
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dateTimeController,
                readOnly: true,
                onTap: () => _selectDateTime(context),
                decoration: const InputDecoration(
                  labelText: 'Required Date & Time',
                  prefixIcon: Icon(Icons.calendar_today_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please select required date and time' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedRequestType,
                decoration: const InputDecoration(
                  labelText: 'Request Type',
                  prefixIcon: Icon(Icons.priority_high, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
                items: _requestTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _selectedRequestType = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  prefixIcon: Icon(Icons.note_outlined, color: Colors.redAccent),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Submit Blood Request',
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
