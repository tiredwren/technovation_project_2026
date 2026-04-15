import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart';
import 'recipe.dart';

class RecipeListPage extends StatelessWidget {
  final void Function(String)? onRecipeChosen;

  final List<String> recipes;

  RecipeListPage({required this.recipes, this.onRecipeChosen});

  @override
  Widget build(BuildContext context) {
    List<String> validRecipes = recipes.where((recipe) {
      List<String> lines = recipe.split('\n');
      return lines.isNotEmpty && lines[0].startsWith('Title:');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('y o u r   r e c i p e s',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 25),
        ),

        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomePage(initialTab: 0)),
                  (route) => false,
            );
          },
        ),
        backgroundColor: const Color(0xFFfefae0),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFfefae0),
      body: validRecipes.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 60, color: Color(0xFFbc6c25)),
              SizedBox(height: 16),
              Text(
                "no valid recipes available;\nplease try again with different inputs!",
                style: GoogleFonts.poppins(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
        itemCount: validRecipes.length,
        itemBuilder: (context, index) {
          List<String> lines = validRecipes[index].split('\n');
          String title = lines[0].replaceAll('Title:', '').trim();

          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 500 + index * 100),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Card(
              color: Color(0xFFfefae0),
              elevation: 6,
              margin: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                leading: Icon(Icons.restaurant_menu, color: Color(0xFF606c38), size: 30),
                title: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF283618),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFFbc6c25)),
                onTap: () {
                  if (onRecipeChosen != null) {
                    print('recipe: ${validRecipes[index]}');
                    onRecipeChosen!(validRecipes[index]);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
