import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
    @override
    _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State <SettingsPage> {
    bool _autoExpiration = false;
    bool _darkMode = false;

    @override
    void initState() {
    super.initState();
    _loadSettings();
    }

    Future<void> _loadSettings() async {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
            _autoExpiration = prefs.getBool('auto_expiration') ?? false;
        });
    }

     Future<void> _setAutoExpiration(bool value) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_expiration', value);
        setState(() {
            _autoExpiration = value;
        });
    }

    Future<void> _savePref(String key, bool value) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(key, value);
    }

    Widget _buildSectionHeader(String title) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
                title,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFbc6c25),
                ),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: const Color(0xFFf1faee),
            appBar: AppBar(
                title: Text(
                    "s e t t i n g s",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: const Color(0xFF283618),
                    ),
                ),
                centerTitle: true,
                backgroundColor: const Color(0xFFf1faee),
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        _buildSectionHeader('appearance'),

                        // Dark Mode SwitchListTile
                        Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 4)
                                ],
                            ),
                            child: SwitchListTile(
                                title: Text(
                                    'dark mode',
                                    style: GoogleFonts.poppins(fontSize: 18),
                                ),
                                subtitle: Text(
                                    'switch to a darker color scheme',
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.black54,
                                    ),
                                ),
                                value: _darkMode,
                                activeColor: const Color(0xFF606C38),
                                onChanged: (val) {
                                    setState(() => _darkMode = val);
                                    _savePref('dark_mode', val);
                                },
                            ),
                        ),

                        const SizedBox(height: 20),

                        _buildSectionHeader('expiration dates'),

                        // Auto Expiration SwitchListTile
                        Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 4)
                                ],
                            ),
                            child: SwitchListTile(
                                title: Text(
                                    "automatically set expiration dates",
                                    style: GoogleFonts.poppins(fontSize: 18),
                                ),
                                subtitle: Text(
                                    "uses AI to estimate expiration dates when scanning; you can change estimated dates in your fridge later",
                                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                                ),
                                value: _autoExpiration,
                                activeColor: const Color(0xFF606C38),
                                onChanged: _setAutoExpiration,
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}