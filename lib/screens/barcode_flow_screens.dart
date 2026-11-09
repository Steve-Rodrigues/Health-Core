import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api.dart';

/// Barcode logging flow:
///   Scanner (camera or typed barcode) -> GET scan-food
///     -> Manual entry (if anything is missing or the product wasn't found) -> PUT manual-barcode
///     -> Log screen (servings + meal type, live macro preview) -> POST log-meal
/// The scanner screen drives the flow and pops with `true` once a meal is logged.

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

double? _toDouble(Object? value) => value is num ? value.toDouble() : null;

double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Shows whole numbers without a decimal and everything else with one decimal.
String formatAmount(num value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// Scanner
// ---------------------------------------------------------------------------

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _api = ApiClient();
  final _scanner = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _typedBarcode = TextEditingController();

  /// True while a lookup or the rest of the flow is running, so the camera
  /// (which reports the same barcode many times a second) only triggers one lookup.
  bool _busy = false;

  /// Set once a meal is logged and the scanner is closing.
  bool _finished = false;

  @override
  void dispose() {
    _scanner.dispose();
    _typedBarcode.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _lookup(value);
        return;
      }
    }
  }

  void _submitTyped() {
    final value = _typedBarcode.text.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    _lookup(value);
  }

  /// Pauses the camera while [task] runs (lookup and/or the screens pushed on top)
  /// and resumes it afterwards unless a meal was logged and we're leaving.
  Future<void> _whileBusy(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _pauseCamera();
    try {
      await task();
    } finally {
      if (mounted && !_finished) {
        setState(() => _busy = false);
        await _resumeCamera();
      }
    }
  }

  Future<void> _lookup(String barcode) => _whileBusy(() async {
    try {
      final food = await _api.scanBarcode(barcode);
      if (!mounted) return;
      if (food == null) {
        _showMessage("We couldn't find that product. Enter its info from the label.");
        await _continueFlow({'barcode': barcode, 'missing': <String>[]}, needsManualEntry: true);
      } else {
        final missing = food['missing'];
        final needsManualEntry = missing is List && missing.isNotEmpty;
        await _continueFlow(food, needsManualEntry: needsManualEntry);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 400) {
        _showMessage("That doesn't look like a valid food barcode. Try again.");
      } else {
        // API down or another error -- let them type the info in instead.
        _showMessage(
          error.message,
          actionLabel: 'Enter manually',
          onAction: () => _whileBusy(() => _continueFlow(
                {'barcode': barcode, 'missing': <String>[]},
                needsManualEntry: true,
              )),
        );
      }
    }
  });

  /// Runs manual entry (if needed) then the log screen. Pops the scanner if a meal was logged.
  Future<void> _continueFlow(Map<String, dynamic> food, {required bool needsManualEntry}) async {
    var current = food;
    if (needsManualEntry) {
      final saved = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => BarcodeManualEntryScreen(food: current)),
      );
      if (saved == null || !mounted) return; // backed out -> keep scanning
      current = saved;
    }

    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeLogScreen(food: current)),
    );
    if (logged == true && mounted) {
      _finished = true;
      Navigator.pop(context, true);
    }
  }

  Future<void> _pauseCamera() async {
    try {
      await _scanner.stop();
    } catch (_) {
      // Camera may not be running (no permission / no camera) -- typing still works.
    }
  }

  Future<void> _resumeCamera() async {
    try {
      await _scanner.start();
    } catch (_) {}
  }

  void _showMessage(String message, {String? actionLabel, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a barcode')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraUnavailable(error: error),
                ),
                // Simple frame to show where to aim.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Point the camera at the barcode, or type the numbers under it.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _typedBarcode,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _submitTyped(),
                          decoration: const InputDecoration(
                            labelText: 'Barcode number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _busy ? null : _submitTyped,
                        child: const Text('Look up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = error.errorCode == MobileScannerErrorCode.permissionDenied
        ? 'Camera permission was denied.'
        : 'The camera is unavailable.';
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$message\nYou can still type the barcode below.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Manual entry
// ---------------------------------------------------------------------------

/// Lets the user fill in a food's info from the nutrition label.
/// Macros are entered PER SERVING (what the label shows) and converted to
/// per 100 g before saving, since that's what the backend stores.
/// Pops with the saved food map.
class BarcodeManualEntryScreen extends StatefulWidget {
  const BarcodeManualEntryScreen({super.key, required this.food});

  final Map<String, dynamic> food;

  @override
  State<BarcodeManualEntryScreen> createState() => _BarcodeManualEntryScreenState();
}

class _BarcodeManualEntryScreenState extends State<BarcodeManualEntryScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _servingGrams;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    final serving = _toDouble(food['serving_size_grams']);

    // Pre-fill whatever the scan found, converted to per-serving amounts.
    String perServing(String key) {
      final per100 = _toDouble(food[key]);
      if (per100 == null || serving == null) return '';
      return formatAmount(per100 * serving / 100);
    }

    _name = TextEditingController(text: food['name'] as String? ?? '');
    _servingGrams = TextEditingController(text: serving == null ? '' : formatAmount(serving));
    _calories = TextEditingController(text: perServing('calories_per_100'));
    _protein = TextEditingController(text: perServing('protein_per_100'));
    _carbs = TextEditingController(text: perServing('carbs_per_100'));
    _fat = TextEditingController(text: perServing('fat_per_100'));
  }

  @override
  void dispose() {
    for (final c in [_name, _servingGrams, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requirePositive(String? text) {
    final value = _parseNumber(text ?? '');
    if (value == null) return 'Enter a number';
    if (value <= 0) return 'Must be more than 0';
    return null;
  }

  String? _requireNonNegative(String? text) {
    final value = _parseNumber(text ?? '');
    if (value == null) return 'Enter a number';
    if (value < 0) return "Can't be negative";
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final serving = _parseNumber(_servingGrams.text)!;
    double per100(TextEditingController c) => _parseNumber(c.text)! / serving * 100;

    setState(() => _saving = true);
    try {
      final saved = await _api.saveManualBarcodeFood(
        barcode: widget.food['barcode'].toString(),
        name: _name.text.trim(),
        servingSizeGrams: serving,
        caloriesPer100: per100(_calories),
        proteinPer100: per100(_protein),
        carbsPer100: per100(_carbs),
        fatPer100: per100(_fat),
      );
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = (widget.food['missing'] as List?)?.cast<String>() ?? const [];
    final notFound = widget.food['name'] == null && missing.isEmpty;

    Widget numberField(
      TextEditingController controller,
      String label, {
      String? suffix,
      String? Function(String?)? validator,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: validator ?? _requireNonNegative,
            decoration: InputDecoration(
              labelText: label,
              suffixText: suffix,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Enter food info')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              notFound
                  ? "This product isn't in our database yet. Fill in the info from its nutrition label."
                  : "Some info for this product is missing. Check the nutrition label and fill in the blanks.",
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (text) =>
                    (text == null || text.trim().isEmpty) ? 'Enter a name' : null,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            numberField(_servingGrams, 'Serving size', suffix: 'g', validator: _requirePositive),
            const SizedBox(height: 8),
            Text(
              'Per serving (as shown on the label)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            numberField(_calories, 'Calories', suffix: 'kcal'),
            numberField(_protein, 'Protein', suffix: 'g'),
            numberField(_carbs, 'Carbs', suffix: 'g'),
            numberField(_fat, 'Fat', suffix: 'g'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and continue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log screen
// ---------------------------------------------------------------------------

/// Shows the food, asks how many servings and which meal, previews the macros
/// with the same math the backend uses, then logs it. Pops with `true` on success.
class BarcodeLogScreen extends StatefulWidget {
  const BarcodeLogScreen({super.key, required this.food});

  final Map<String, dynamic> food;

  @override
  State<BarcodeLogScreen> createState() => _BarcodeLogScreenState();
}

class _BarcodeLogScreenState extends State<BarcodeLogScreen> {
  final _api = ApiClient();
  final _servings = TextEditingController(text: '1');
  late String _mealType = _defaultMealType();
  bool _saving = false;

  static String _defaultMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 16) return 'lunch';
    if (hour < 21) return 'dinner';
    return 'snack';
  }

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  double? get _servingCount {
    final value = _parseNumber(_servings.text);
    return (value == null || value <= 0) ? null : value;
  }

  /// grams eaten * (amount per 100 g) / 100 -- same formula as the backend's log_meal.
  double _macro(String key, double servings) {
    final grams = (_toDouble(widget.food['serving_size_grams']) ?? 0) * servings;
    return grams * (_toDouble(widget.food[key]) ?? 0) / 100;
  }

  Future<void> _log() async {
    final servings = _servingCount;
    if (servings == null) return;
    setState(() => _saving = true);
    try {
      await _api.logBarcodeMeal(
        barcode: widget.food['barcode'].toString(),
        servings: servings,
        mealType: _mealType,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final servingGrams = _toDouble(food['serving_size_grams']) ?? 0;
    final servings = _servingCount;

    Widget macroRow(String label, String key, String unit) => ListTile(
          dense: true,
          title: Text(label),
          trailing: Text(
            servings == null ? '—' : '${formatAmount(_macro(key, servings))} $unit',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Log food')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            food['name']?.toString() ?? 'Food',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('1 serving = ${formatAmount(servingGrams)} g'),
          const SizedBox(height: 20),
          TextField(
            controller: _servings,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Servings',
              border: const OutlineInputBorder(),
              errorText: servings == null ? 'Enter a number more than 0' : null,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            items: _mealTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _mealType = value!),
            decoration: const InputDecoration(
              labelText: 'Meal type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('Total amount'),
                    trailing: Text(
                      servings == null ? '—' : '${formatAmount(servingGrams * servings)} g',
                    ),
                  ),
                  const Divider(height: 1),
                  macroRow('Calories', 'calories_per_100', 'kcal'),
                  macroRow('Protein', 'protein_per_100', 'g'),
                  macroRow('Carbs', 'carbs_per_100', 'g'),
                  macroRow('Fat', 'fat_per_100', 'g'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: (_saving || servings == null) ? null : _log,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Log meal'),
          ),
        ],
      ),
    );
  }
}
