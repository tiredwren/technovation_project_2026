import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'home.dart';

class GenerateRecipes extends StatefulWidget {
  final void Function(List<String>)? onRecipesGenerated;

  GenerateRecipes({this.onRecipesGenerated});
  @override
  _GenerateRecipesState createState() => _GenerateRecipesState();
}

class _GenerateRecipesState extends State<GenerateRecipes> {
  User? user = FirebaseAuth.instance.currentUser;
  List<String> ingredients = [];
  List <String> expirationDates = [];
  List<String> allergies = [];
  List<bool> selectedIngredients = [];
  List<bool> selectedAllergies = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _showCustomDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu, size: 50, color: Color(0xFF606C38)),
                const SizedBox(height: 12),
                Text(
                  "ready to cook?",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF283618),
                  ),
                ),
                const SizedBox(height: 12),

                _buildSecondCardWrapper(
                  TextField(
                    controller: dietaryRestrictionsController,
                    decoration: const InputDecoration(
                      labelText: 'allergies/dietary restrictions/other specifications',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildSecondCardWrapper(
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'preferred cuisine type',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() {
                        cuisineType = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "tap below to generate recipes using your selected ingredients. we'll make sure to avoid your listed allergies!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // close dialog
                      generateRecipe(); // call generate function
                    },
                    child: Text("create recipes", style: GoogleFonts.poppins()),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDDA15E),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("cancel", style: GoogleFonts.poppins()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _fetchUserData() {
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('ingredients')
          .orderBy('expiration_date', descending: false)
          .snapshots()
          .listen((snapshot) {
        List<String> fetchedIngredients = [];
        List<String> fetchedExpirationDates = [];

        for (var doc in snapshot.docs) {
          fetchedIngredients.add(doc.id); // document ID is the ingredient name
          final timestamp = doc['expiration_date'] as Timestamp?;
          final date = timestamp?.toDate();
          final formattedDate = date != null
              ? DateFormat.yMMMd().format(date)
              : "no date";
          fetchedExpirationDates.add(formattedDate);
        }

        if (!mounted) return;
        setState(() {
          ingredients = fetchedIngredients;
          expirationDates = fetchedExpirationDates;
          selectedIngredients = List.filled(ingredients.length, false);
        });
      });

      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('allergies')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        List<String> fetchedAllergies = [];
        for (var doc in snapshot.docs) {
          final data = List<String>.from(doc['allergies']);
          fetchedAllergies.addAll(data.map((allergy) => allergy.toLowerCase()));
        }
        if (!mounted) return;
        setState(() {
          allergies = fetchedAllergies.toSet().toList();
          selectedAllergies = List.filled(allergies.length, false);
        });
      });
    }
  }

  String cuisineType = '';
  TextEditingController dietaryRestrictionsController = TextEditingController();
  bool isLoading = false;
  List<String> recipes = [];

  Future<void> generateRecipe() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      recipes.clear();
    });

    List<String> chosenIngredients = [];
    List<String> chosenAllergies = [];

    for (int i = 0; i < selectedIngredients.length; i++) {
      if (selectedIngredients[i]) chosenIngredients.add(ingredients[i]);
    }

    for (int i = 0; i < selectedAllergies.length; i++) {
      if (selectedAllergies[i]) chosenAllergies.add(allergies[i]);
    }

    if (dietaryRestrictionsController.text.isNotEmpty) {
      chosenAllergies.add(dietaryRestrictionsController.text);
    }

    String prompt = '''
    You are a world-traveling chef creating multiple unique recipes.
    Recommend 12 different recipes using:
    - Ingredients: ${chosenIngredients.join(", ")}
    - Allergies to avoid: ${chosenAllergies.join(", ")}
    - Cuisine preference: ${cuisineType.isNotEmpty ? cuisineType : "Any"}
    The recipes should use ONLY the ingredients given. DO NOT USE ANY EXTRA INGREDIENTS. 
    Try to also use all ingredients given in all recipes, if possible.

    Format for each:
    Title:
    Ingredients:
    - Ingredient1 (quantity)
    - Ingredient2 (quantity)
    Instructions:
    - Step1
    - Step2
    Cuisine Type:
    Serves: X
    Nutrition:
    - Calories: XX kcal
    - Fat: XX g
    - Carbs: XX g
    - Protein: XX g

    Separate each recipe with '###'
    ''';

    final apiKey = 'API_KEY';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'contents': [{'parts': [{'text': prompt}]}]}),
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String responseText = data['candidates'][0]['content']['parts'][0]['text'];
        List<String> generatedRecipes = responseText.split('###').map((r) =>
            r.trim()).toList();

        if (!mounted) return;
        setState(() {
          isLoading = false;
        });

        if (widget.onRecipesGenerated != null) {
          widget.onRecipesGenerated!(generatedRecipes); // list of strings
        }
        // navigate to new page with recipes
        print(generatedRecipes);
      } else {
        _showError('error: ${response.body}');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void inputIngredients() {
    print("in input");
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage(initialTab: 5)),
          (route) => false,
    );
  }

  void _showEditDialog(String currentIngredient, String currentExpirationDate, int index) {
    print("editing button pressed");
    final TextEditingController ingredientController = TextEditingController(text: currentIngredient);
    DateTime selectedDate = DateFormat("MMM dd, yyyy").parse(currentExpirationDate);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'edit ingredient',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ingredientController,
                  decoration: InputDecoration(
                    labelText: 'ingredient name',
                    labelStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  ),
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "expiration date",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final DateTime? newDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (newDate != null) {
                      setState(() {
                        selectedDate = newDate;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                          style: GoogleFonts.poppins(fontSize: 15),
                        ),
                        Icon(Icons.calendar_today, color: Color(0xFFAC2920), size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('cancel', style: GoogleFonts.poppins(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                String newIngredient = ingredientController.text.trim();
                if (newIngredient.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ingredient name cannot be empty')),
                  );
                  return;
                }

                Timestamp formattedDate = Timestamp.fromDate(selectedDate);

                await _updateIngredient(index, newIngredient, formattedDate);

                Navigator.of(context).pop();
              },
              child: Text('save', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteIngredient(int index) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ingredients')
        .doc(ingredients[index]
        .toLowerCase())
        .delete();

    setState(() {
      ingredients.removeAt(index);
      expirationDates.removeAt(index);
      selectedIngredients.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingredient deleted')));
  }

  Future<void> _updateIngredient(int index, String newIngredient, Timestamp newExpirationDate) async {
    // update the local lists with the new values
    setState(() {
      ingredients[index] = newIngredient;
      expirationDates[index] = newExpirationDate.toString();
    });

    // firebase update logic (make sure it updates both name and expiration date)
    String userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ingredients')
        .doc(ingredients[index]
        .toLowerCase()) // using lowercase ingredient name for doc ID for consistency
        .update({
      'expiration_date': newExpirationDate,
    });
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Padding(
              padding: EdgeInsetsDirectional.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "y o u r   i n g r e d i e n t s",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: const Color(0xFF283618),
                    ),
                  ),
                  const SizedBox(width: 20),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF606C38),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: inputIngredients,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFFf1faee),
          ),
          backgroundColor: const Color(0xFFf1faee),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ingredients.isEmpty
                            ? Column(
                          children: [
                            _buildCardWrapper(
                              _buildCheckboxList(
                                  ingredients, selectedIngredients,
                                  expirationDates),
                            ),
                          ],
                        ) : Column(
                          children: [
                            _buildSectionTitle('select ingredients'),
                            // display the section title only if there are ingredients
                            _buildCardWrapper(
                              _buildCheckboxList(
                                  ingredients, selectedIngredients,
                                  expirationDates),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showCustomDialog,
                      child: const Text(
                        'create recipes',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // overlay barrier & spinner when loading
        if (isLoading) ...[
          // prevent any interaction & dim background
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.5),
          ),
          // centered loader
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFbc6c25)),
              ),
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFbc6c25)),
      ),
    );
  }

  Widget _buildCardWrapper(Widget child) {
    return ingredients.isEmpty
        ? Column(
      children: [
        Image.asset('assets/images/cute_fridge.png', height: 200),
        SizedBox(height: 20),
        Text(
          "you currently have no ingredients in your fridge. when you add ingredients, they will appear on this page.",
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF606C38)),
              onPressed: inputIngredients,
              child: const Text(
                'add ingredients now!',
                style: TextStyle(color: Colors.white),
              )),
        ),
      ],
    )
        : child; // return the usual card wrapper if ingredients are present
  }

  Widget _buildSecondCardWrapper(Widget child) {
    return child; // return the usual card wrapper if ingredients are present
  }

  Widget _buildCheckboxList(List<String> items, List<bool> selections,
      List<String> expirationDates) {
    // first, parse expiration dates and sort
    List<Map<String, dynamic>> sortedItems = List.generate(items.length, (index) {
      return {
        'item': items[index],
        'selected': selections[index],
        'expiration': expirationDates[index],
        'expirationDateTime': DateFormat('MMM dd, yyyy').parse(expirationDates[index]),
        'index': index,
      };
    });

    sortedItems.sort((a, b) => a['expirationDateTime'].compareTo(b['expirationDateTime']));

    // split into expiring soon and normal
    List<Map<String, dynamic>> expiringSoonItems = [];
    List<Map<String, dynamic>> normalItems = [];

    for (var item in sortedItems) {
      bool isExpiringSoon = item['expirationDateTime'].difference(DateTime.now()).inDays <= 7;
      if (isExpiringSoon) {
        expiringSoonItems.add(item);
      } else {
        normalItems.add(item);
      }
    }

    // helper function to build each section
    List<Widget> buildItemList(List<Map<String, dynamic>> items) {
      return List.generate(items.length, (i) {
        var item = items[i];
        bool isExpiringSoon = item['expirationDateTime'].difference(DateTime.now()).inDays <= 7;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item['selected'],
                onChanged: (bool? value) {
                  if (!mounted) return;
                  setState(() {
                    selections[item['index']] = value!;
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['item'],
                      style: GoogleFonts.poppins(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      item['expiration'],
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      _showEditDialog(item['item'], item['expiration'], item['index']);
                    },
                    child: Text("edit", style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton(
                    onPressed: () {
                      _deleteIngredient(item['index']);
                    },
                    child: Text("delete", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        );
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // expiring soon section with red border
          if (expiringSoonItems.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      "expiring soon",
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                  ),
                  ...buildItemList(expiringSoonItems),
                ],
              ),
            ),
            Divider(),
          ],

          // normal items
          if (normalItems.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                "all ingredients",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...buildItemList(normalItems),
          ],
        ],
      ),
    );
  }
}