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
  bool _isTextNotEmpty = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  bool extracting = false;
  Map<String, DateTime?> _expirationDates = {};

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    _textController.addListener(() {
      setState(() {
        _isTextNotEmpty = _textController.text.trim().isNotEmpty;
      });
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        extracting = true;
        _imageFile = File(pickedFile.path);
        _textController.text = "processing image...";
      });
      _processImage(_imageFile!);
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final content = [
        Content.multi([
          TextPart("""Extract only the ingredients from this recipe image. 
          Do not include instructions or non-food items. Format the ingredients 
          as a comma-separated list.
          If something in this list is not an ingredient, do not include it. 
          Also, figure out what abbreviations mean, because this is a recipe
          so there will be common store jargon. For instance, "org" means organic, etc"""),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      setState(() {
        _textController.text = response.text ?? 'no ingredients extracted.';
        extracting = false;
      });
    } catch (e) {
      setState(() {
        _textController.text = 'error processing image: $e';
      });
    }
  }

  Future<void> _saveIngredients() async {
    final extractedText = _textController.text.trim();

    if (extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("no ingredients to save.")),
      );
      return;
    }

    final ingredients = extractedText.split(',').map((e) => e.trim()).toList();

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("user not signed in!")),
      );
      return;
    }

    String userId = user.uid;

    for (String ingredient in ingredients) {
      if (ingredient.isNotEmpty) {
        
        final prefs = await SharedPreferences.getInstance();
        final autoExpiration = prefs.getBool('auto_expiration') ?? false;
        DateTime? expirationDate; 
        
        if (autoExpiration) {
          expirationDate = await _estimateExpirationDate(ingredient);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('using AI estimate for "$ingredient"')),
        );
        } else {  
        expirationDate = await showDatePicker(  
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'select an expiration date for "$ingredient"',
        );

        if (expirationDate == null) {
          // use AI to estimate expiration date
          expirationDate = await _estimateExpirationDate(ingredient);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no date selected for "$ingredient" – using AI estimate.')),
          );
        }
      }  

        _expirationDates[ingredient] = expirationDate;

        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('ingredients')
              .doc(ingredient.toLowerCase())
              .set({
            'timestamp': FieldValue.serverTimestamp(),
            'expiration_date': Timestamp.fromDate(expirationDate!),
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("error saving $ingredient: $e")),
          );
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ingredients saved!")),
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
Estimate a typical expiration time from today for "$ingredient". Respond only with a number of days (as an integer).
Example:
- milk → 7
- eggs → 21
- apples → 30
Do not include any text or explanation.
''';

      final response = await _model.generateContent([
        Content.text(prompt)
      ]);

      final rawText = response.text?.trim() ?? '';
      final days = int.tryParse(RegExp(r'\d+').stringMatch(rawText) ?? '');

      if (days != null) {
        return DateTime.now().add(Duration(days: days));
      }
    } catch (e) {
      print("Error estimating expiration: $e");
    }

    // fallback: 7 days if AI fails
    return DateTime.now().add(const Duration(days: 7));
  }

  @override
  Widget build(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                TextField(
                  controller: _textController,
                  maxLines: null,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: extracting
                        ? "processing image..."
                        : "ingredients list (edit as necessary)",
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTextNotEmpty ? _saveIngredients : null,
                    icon: const Icon(Icons.save),
                    label: const Text("save"),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomePage(initialTab: 0)),
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
