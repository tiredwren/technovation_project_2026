import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart'
as http;
import 'dart:convert';

class TrashSortingPage extends StatefulWidget {
    @override
    _TrashSortingPageState createState() => _TrashSortingPageState();
}

class _TrashSortingPageState extends State < TrashSortingPage > {
    final _controller = TextEditingController();
    bool _isLoading = false;
    Map < String,
    dynamic > ? _result;

    Future < void > _classify() async {
        final item = _controller.text.trim();
        if (item.isEmpty) return;

        setState(() {
            _isLoading = true;
            _result = null;
        });

        try {
            final response = await http.post(
                Uri.parse('API_KEY'),
                headers: {
                    'Content-Type': 'application/json'
                },
                body: jsonEncode({
                        'contents': [{
                                'parts': [{
                                        'text': ''
                                        'You are a waste sorting assistant. For the food item or packaging: "$item", respond ONLY with a JSON object in this exact format: {
                                        "category": "compost"
                                        or "recycle"
                                        or "landfill",
                                        "reason": "one sentence explanation",
                                        "tip": "one practical tip"
                                    }
                                    ''
                                    '    
                                }]
                        }]
                }),
        );
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            final clean = text.replaceAll('```json', '').replaceAll('```', '');
            setState(() {
                _result = jsonDecode(clean);
            });
        }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('something went wrong: $e')),
        );
    } finally {
        setState(() => _isLoading = false);
    }
}

Color _categoryColor(String category) {
    switch (category) {
        case 'compost':
            return const Color(0xFF606C38);
        case 'recycle':
            return const Color(0xFF1a6fa8);
        case 'landfill':
            return const Color(0xFF7a7a7a);
    }
}

IconData _categoryIcon(String category) {
    switch (category) {
        case 'compost':
            return Icons.yard;
        case 'recycle':
            return Icons.recycling;
        case 'landfill':
            return Icons.delete_outline;
        default:
            return Icons.help_outline;
    }
}

@override
void dispose() {
    _controller.dispose();
    super.dispose();
}

@override
Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(
                "t r a s h  s o r t i n g",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: const Color(0xFF283618),
                ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFFf1faee)
        ),
        backgroundColor: const Color(0xFFf1faee),
            body: Padding(
                padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Text(
                                'enter a food or packaging type to find how to dispose of it correctly.',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                                TextField(
                                    controller: _controller,
                                    decoration: InputDecoration(
                                        labelText: 'ex banana peel, plastic wrap, cardboard box',
                                        labelStyle: GoogleFonts.poppins(),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        filler: true,
                                        fillColor: Colors.white,
                                    ),
                                    const SizedBox(height: 12),
                                        ElevatedButton(
                                            onPressed: _isLoading ? null : _classify,
                                            child: _isLoading ?
                                            const SizedBox(height: 20, width: 20, child: CicularProgressIndicator(strokeWidth: 2, color: Colors.white)): Text('check', style: GoogleFonts.poppins()),
                                        ),
                                        const SizedBox(height: 24),
                                            if (_result != null)[
                                                Container(
                                                    padding: const EdgeInsets.all(20),
                                                        decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(12),
                                                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                                            border: Border.all(
                                                                color: _categoryColor(_result['category']),
                                                                width: 2,
                                                            ),
                                                        ),
                                                        child: Column(
                                                            children: [
                                                                Icon(
                                                                    _categoryIcon(_result!['category']),
                                                                    size: 48,
                                                                    color: _categoryColor(_result!['category']),
                                                                ),
                                                                const SizedBox(height: 10),
                                                                    Text(
                                                                        _result!['category'],
                                                                        style: GoogleFonts.poppins(
                                                                            fontSize: 22,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: _categoryColor(_result!['category']),
                                                                        ),
                                                                    ),
                                                                    const SizedBox(height: 10),
                                                                        Text(
                                                                            _result!['category'],
                                                                            style: GoogleFonts.poppins(fontSize: 14),
                                                                            textAlign: TextAlign.center,
                                                                        ),
                                                                        const SizedBox(height: 12),
                                                                            Container(
                                                                                padding: const EdgeInsets.all(12),
                                                                                    decoration: BoxDecoration(
                                                                                        color: const Color(0xFFf1faee),
                                                                                            borderRadius: BorderRadius.circular(8),
                                                                                    ),
                                                                                    child: Row(
                                                                                        children: [
                                                                                            const Icon(Icons.lightbulb_outline, color: Color(0xFFbc6c25), size: 18),
                                                                                                const SizedBox(width: 8),
                                                                                                    Expanded(
                                                                                                        child: Text(
                                                                                                            _result!['tip'],
                                                                                                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                                                                                                        ),
                                                                                                    ),
                                                                                        ],
                                                                                    ),
                                                                            ),
                                                            ],
                                                        ),
                                                ),
                                            ],
                                ),
                        ],
                    ),
            ),
    );
}
}