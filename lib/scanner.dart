import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

class GeminiImageProcessor extends StatefulWidget {
  @override
  _GeminiImageProcessorState createState() => _GeminiImageProcessorState();
}

class _GeminiImageProcessorState extends State<GeminiImageProcessor> {
  final String apiKey = 'API_KEY';
  late final GenerativeModel _model;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _manualController = TextEditingController();
  bool extracting = false;

  Map<String, DateTime?> _expirationDates = {};
  Map<String, String> _ingredientQuantities = {};
  List<String> _ingredientsList = [];

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        extracting = true;
        _imageFile = File(pickedFile.path);
      });
      await _processImage(_imageFile!);
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart("""Extract only the ingredients and their quantities from this recipe image. 
          Format as: ingredient: quantity, separated by commas. 
          If quantity is not clear, leave empty and AI can estimate later."""),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final extractedText = response.text ?? '';

      final items = extractedText.split(',').map((e) {
        final parts = e.split(':').map((p) => p.trim()).toList();
        final ingredient = parts[0];
        final quantity = parts.length > 1 ? parts[1] : '';
        _ingredientQuantities[ingredient] = quantity;
        return ingredient;
      }).toList();

      setState(() {
        _ingredientsList.addAll(items.where((i) => i.isNotEmpty));
        extracting = false;
      });
    } catch (e) {
      setState(() {
        extracting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  void _addManualIngredient() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;

    final parts = text.split(':').map((p) => p.trim()).toList();
    final ingredient = parts[0];
    final quantity = parts.length > 1 ? parts[1] : '';

    if (!_ingredientsList.contains(ingredient)) {
      setState(() {
        _ingredientsList.add(ingredient);
        _ingredientQuantities[ingredient] = quantity;
      });
    }

    _manualController.clear();
  }

  Future<void> _confirmIngredients() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not signed in!")),
      );
      return;
    }

    String userId = user.uid;
    final prefs = await SharedPreferences.getInstance();
    final autoExpiration = prefs.getBool('auto_expiration') ?? false;

    for (String ingredient in _ingredientsList) {
      DateTime? expirationDate;

      if (autoExpiration) {
        expirationDate = await _estimateExpirationDate(ingredient);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Using AI estimate for "$ingredient"')),
        );
      } else {
        expirationDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Select an expiration date for "$ingredient"',
        );

        if (expirationDate == null) {
          expirationDate = await _estimateExpirationDate(ingredient);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'No date selected for "$ingredient" – using AI estimate.')),
          );
        }
      }

      _expirationDates[ingredient] = expirationDate;

      // If quantity is empty, estimate using AI
      if ((_ingredientQuantities[ingredient] ?? '').isEmpty) {
        _ingredientQuantities[ingredient] =
        await _estimateQuantity(ingredient);
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('ingredients')
            .doc(ingredient.toLowerCase())
            .set({
          'timestamp': FieldValue.serverTimestamp(),
          'expiration_date': Timestamp.fromDate(expirationDate!),
          'quantity': _ingredientQuantities[ingredient],
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving $ingredient: $e")),
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ingredients saved!")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage(initialTab: 0)),
          (route) => false,
    );
  }

  Future<DateTime?> _estimateExpirationDate(String ingredient) async {
    try {
      final prompt = '''
Estimate a typical expiration time from today for "$ingredient". Respond only with a number of days (as an integer).''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final rawText = response.text?.trim() ?? '';
      final days = int.tryParse(RegExp(r'\d+').stringMatch(rawText) ?? '');

      if (days != null) {
        return DateTime.now().add(Duration(days: days));
      }
    } catch (e) {
      print("Error estimating expiration: $e");
    }
    return DateTime.now().add(const Duration(days: 7));
  }

  Future<String> _estimateQuantity(String ingredient) async {
    try {
      final prompt = '''
Suggest a typical quantity for "$ingredient" in a recipe. Respond with something like "2 cups" or "1 tbsp". Do not include extra text.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '1 unit';
    } catch (e) {
      print("Error estimating quantity: $e");
      return '1 unit';
    }
  }

  void _updateQuantity(String ingredient, String quantity) {
    setState(() {
      _ingredientQuantities[ingredient] = quantity;
    });
  }

  void _deleteIngredient(String ingredient) {
    setState(() {
      _ingredientsList.remove(ingredient);
      _ingredientQuantities.remove(ingredient);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color _green = Color(0xFF283618);
    const Color _lightGreen = Color(0xFF606c38);
    const Color _cream = Color(0xFFfefae0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "i n p u t   i n g r e d i e n t s",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("upload a receipt"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("take image of receipt"),
                  ),
                ),
                _imageFile != null
                    ? Image.file(_imageFile!, height: 200)
                    : const Icon(Icons.image, size: 100, color: Colors.grey),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        decoration: InputDecoration(
                          labelText: 'Add ingredient (name: quantity)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _addManualIngredient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: _cream,
                        ),
                        child: Text(
                          'Add',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ingredientsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ingredient = _ingredientsList[index];
                    final quantity = _ingredientQuantities[ingredient] ?? '';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ingredient,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'qty',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                controller: TextEditingController(
                                    text: quantity),
                                onChanged: (val) =>
                                    _updateQuantity(ingredient, val),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Color(0xFFbc6c25), size: 24),
                              onPressed: () => _deleteIngredient(ingredient),
                              splashRadius: 22,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                    _ingredientsList.isNotEmpty ? _confirmIngredients : null,
                    icon: const Icon(Icons.save),
                    label: const Text("confirm"),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                          const HomePage(initialTab: 0)),
                          (route) => false,
                    ),
                    child: const Text("cancel"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}