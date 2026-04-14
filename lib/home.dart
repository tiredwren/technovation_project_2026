import 'package:ai_recipe_generation/analyze.dart';
import 'package:ai_recipe_generation/eco-scan.dart';
import 'package:ai_recipe_generation/report.dart';
import 'package:ai_recipe_generation/shopping_list.dart';
import 'package:ai_recipe_generation/your_fridge.dart';
import 'package:ai_recipe_generation/navigation/bottom_nav.dart';
import 'package:ai_recipe_generation/recipe.dart';
import 'package:ai_recipe_generation/recipes_list.dart';
import 'package:ai_recipe_generation/scanner.dart';
import 'package:ai_recipe_generation/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  final int initialTab;

  const HomePage({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

void signUserOut() {
  FirebaseAuth.instance.signOut();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final user = FirebaseAuth.instance.currentUser!;

  String? extractedIngredients;
  String? company;
  List<String>? generatedRecipes;
  String? chosenRecipe;

  late int _selectedIndex = widget.initialTab;

  final List<IconData> _icons = [
    Icons.kitchen,
    Icons.compost,
    Icons.checklist,
    Icons.bug_report,
    Icons.settings,
  ];

  final List<String> _labels = [
    'fridge',
    'scan',
    'list',
    'report',
    'settings',
  ];

  List<Widget> get _pages => [
    GenerateRecipes(
      onRecipesGenerated: (recipes) {
        setState(() {
          generatedRecipes = recipes.whereType<String>().toList();
        });
      },
    ),
    SustainabilityScanner(
      onExtracted: (ingredients, companyNameOrSite) {
        setState(() {
          extractedIngredients = ingredients;
          company = companyNameOrSite;
        });
      },
    ),
    ShoppingListPage(),
    ReportIssuePage(),
    SettingsPage(),
    GeminiImageProcessor(),
  ];

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _selectedIndex = widget.initialTab;
      });
    }
  }

  void navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
      extractedIngredients = null;
      generatedRecipes = null;
      chosenRecipe = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;

    if (extractedIngredients != null) {
      print("extracted: $extractedIngredients");
      currentPage = SustainabilityAnalysisPage(
        ingredients: extractedIngredients!,
        companyOrWebsite: company!,
      );
    } else if (chosenRecipe != null) {
      currentPage = RecipePage(recipe: chosenRecipe!);
    } else if (generatedRecipes != null) {
      currentPage = RecipeListPage(
        recipes: generatedRecipes!,
        onRecipeChosen: (recipe) {
          setState(() {
            chosenRecipe = recipe;
          });
        },
      );
      if (chosenRecipe != null) {
        currentPage = RecipePage(recipe: chosenRecipe!);
      }
    } else {
      currentPage = _pages[_selectedIndex];
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
          child: Text(
            "e c o p l a t e",
            style: GoogleFonts.poppins(
              color: const Color(0xFFfefae0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF283618),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: IconButton(
              onPressed: signUserOut,
              icon: const Icon(Icons.logout_rounded),
              color: const Color(0xFFfefae0),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFf1faee),
      body: currentPage,
      bottomNavigationBar: BottomNavigation(
        onTabChange: navigateBottomBar,
        labels: _labels,
        numberOfTabs: _icons.length,
        icons: _icons,
        selectedIndex: _selectedIndex,
      ),
    );
  }
}
