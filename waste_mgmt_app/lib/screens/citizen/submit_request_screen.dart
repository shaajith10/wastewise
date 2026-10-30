import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';

class SubmitRequestScreen extends StatefulWidget {
  const SubmitRequestScreen({super.key});
  @override
  State<SubmitRequestScreen> createState() => _SubmitRequestScreenState();
}

class _SubmitRequestScreenState extends State<SubmitRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController(text: '123 Eco Green Street, Block B, Cityville');
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '3.0');

  Map<String, dynamic>? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  double? _lat = 12.9716, _lng = 77.5946;
  bool _loading = false;
  bool _locating = false;
  bool _loadingCats = true;

  final _defaultCategories = [
    {'id': 'cat_plastic', 'name': 'Plastic', 'pointsPerKg': 50, 'description': 'Bottles, containers, packaging'},
    {'id': 'cat_paper', 'name': 'Paper & Cardboard', 'pointsPerKg': 30, 'description': 'Boxes, cartons, newspapers'},
    {'id': 'cat_metal', 'name': 'Metals & Aluminum', 'pointsPerKg': 80, 'description': 'Cans, tins, scrap metal'},
    {'id': 'cat_ewaste', 'name': 'E-Waste', 'pointsPerKg': 150, 'description': 'Electronics, batteries, cables'},
    {'id': 'cat_glass', 'name': 'Glass Bottles', 'pointsPerKg': 40, 'description': 'Bottles, jars, glassware'},
    {'id': 'cat_organic', 'name': 'Organic Waste', 'pointsPerKg': 15, 'description': 'Food scraps, compostable waste'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _qtyCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await ApiClient.get('/categories');
      final cats = List<Map<String, dynamic>>.from(data['categories'] ?? []);
      _categories = cats.isNotEmpty ? cats : _defaultCategories;
    } catch (_) {
      _categories = _defaultCategories;
    }
    if (_categories.isNotEmpty && _selectedCategory == null) {
      _selectedCategory = _categories.first;
    }
    if (mounted) setState(() => _loadingCats = false);
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Using manual address.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      if (_addressCtrl.text.isEmpty || _addressCtrl.text.contains('Cityville')) {
        _addressCtrl.text = 'Pickup at GPS (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📍 Location pinned successfully!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.warning));
      }
    }
    if (mounted) setState(() => _locating = false);
  }

  int get _estimatedPoints {
    if (_selectedCategory == null) return 0;
    final rate = (_selectedCategory!['pointsPerKg'] as num?)?.toInt() ?? 20;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
    return (rate * qty).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a waste category.')));
      return;
    }

    final latToSend = _lat ?? 12.9716;
    final lngToSend = _lng ?? 77.5946;

    setState(() => _loading = true);
    try {
      await ApiClient.post('/pickup-requests', {
        'categoryId': _selectedCategory!['id'],
        'categoryName': _selectedCategory!['name'],
        'quantityKg': double.parse(_qtyCtrl.text),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'latitude': latToSend,
        'longitude': lngToSend,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Pickup scheduled! You will earn ~$_estimatedPoints reward points on collection.'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.go('/citizen/requests');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Waste Pickup')),
      body: _loadingCats
        ? const LoadingWidget(message: 'Loading categories & reward rates...')
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('1. Select Recyclable Waste Category'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _categories.map((cat) {
                      final selected = _selectedCategory?['id'] == cat['id'];
                      final pts = cat['pointsPerKg'] ?? 30;
                      return ChoiceChip(
                        selected: selected,
                        avatar: Icon(
                          selected ? Icons.check_circle : Icons.recycling,
                          size: 18,
                          color: selected ? Colors.white : AppTheme.primary,
                        ),
                        label: Text('${cat['name']} ($pts pts/kg)'),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _section('2. Quantity & Measured Weight (kg)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 3.5',
                      prefixIcon: Icon(Icons.scale, color: AppTheme.primary),
                      suffixText: 'kg',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter approximate weight in kg';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Please enter a valid positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Real-Time Estimated Reward Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: Color(0xFFF57F17), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Reward: +$_estimatedPoints Points',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryDark),
                              ),
                              Text(
                                'Rate: ${_selectedCategory?['pointsPerKg'] ?? 20} pts/kg • Verified upon collector pickup',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _section('3. Pickup Address & GPS Location'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Street address, house number, area',
                            prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter pickup address' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _locating ? null : _getLocation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(54, 52),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _locating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _section('4. Additional Notes / Instructions (Optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Kept in blue bin near front porch...',
                      prefixIcon: Icon(Icons.notes, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Schedule Collection & Earn Points'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _section(String title) => Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryDark));
}
