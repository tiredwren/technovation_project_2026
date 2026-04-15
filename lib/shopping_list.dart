import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ShoppingListPage extends StatefulWidget {
  @override
  _ShoppingListPageState createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  User? user = FirebaseAuth.instance.currentUser;
  final _itemController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late final String _userId;

  static const _green = Color(0xFF283618);
  static const _lightGreen = Color(0xFF606c38);
  static const _cream = Color(0xFFfefae0);

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
    } else {
      throw Exception('no user signed in');
    }
  }

  Future<void> _addItem(String itemName) async {
    final lowerItemName = itemName.toLowerCase();
    final ingredientDoc = await _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('ingredients')
        .doc(lowerItemName)
        .get();

    if (ingredientDoc.exists) {
      _showAlreadyExistsDialog(lowerItemName);
    } else {
      _addItemToShoppingList(lowerItemName);
    }
  }

  void _addItemToShoppingList(String itemName) {
    _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        .add({
      'name': itemName,
      'quantity': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'isChecked': false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('added to shopping list!',
            style: GoogleFonts.poppins(color: _cream)),
        backgroundColor: _lightGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    _itemController.clear();
  }

  void _showAlreadyExistsDialog(String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('already in pantry',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('you already have this ingredient. add to shopping list anyway?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('no', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addItemToShoppingList(itemName);
            },
            child: Text('yes', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _updateItemChecked(String itemId, bool isChecked) {
    _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        .doc(itemId)
        .update({'isChecked': isChecked});
  }

  void _updateItemQuantity(String itemId, int quantity) {
    if (quantity > 0) {
      _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList')
          .doc(itemId)
          .update({'quantity': quantity});
    }
  }

  void _deleteItem(String itemId) async {
    try {
      await _firestore
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList')
          .doc(itemId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('item removed!',
              style: GoogleFonts.poppins(color: _cream)),
          backgroundColor: _lightGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error deleting item.')),
      );
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userShoppingListRef = _firestore
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EE), // light neutral background
      appBar: AppBar(
        title: Text(
          "s h o p p i n g   l i s t",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22, // slightly bigger for visibility
            color: _green,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      labelText: 'Add an ingredient...',
                      border: const OutlineInputBorder()
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final itemName = _itemController.text.trim();
                      if (itemName.isNotEmpty) _addItem(itemName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _cream,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                      elevation: 2,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Add',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: userShoppingListRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error loading list.',
                            style: GoogleFonts.poppins(fontSize: 16)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _lightGreen));
                  }
                  final items = snapshot.data!.docs;

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_basket_outlined,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Your list is empty',
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[500], fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemId = item.id;
                      final itemName = item['name'] as String;
                      final quantity = item['quantity'] as int;
                      final isChecked = item['isChecked'] as bool;

                      return Container(
                        decoration: BoxDecoration(
                          color: isChecked ? Colors.grey[100] : Colors.white,
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
                              Checkbox(
                                value: isChecked,
                                activeColor: _lightGreen,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                                onChanged: (bool? newValue) {
                                  _updateItemChecked(itemId, newValue ?? false);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isChecked
                                        ? Colors.grey[500]
                                        : Colors.grey[900],
                                    decoration: isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _qtyButton(
                                    icon: Icons.remove,
                                    onTap: () => _updateItemQuantity(
                                        itemId, quantity - 1),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '$quantity',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  _qtyButton(
                                    icon: Icons.add,
                                    onTap: () => _updateItemQuantity(
                                        itemId, quantity + 1),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Color(0xFFbc6c25), size: 24),
                                onPressed: () => _deleteItem(itemId),
                                splashRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDE4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: _lightGreen),
      ),
    );
  }
}