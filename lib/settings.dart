import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
    @override
    _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State <SettingsPage> {
    bool _autoExpiration = false;

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

    @override
    Widget build(BuildContext context) {
        return Scaffold(
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
                backgroundColor: const Color(0xFFf1faee)
            ),
        ),

            backgroundColor: const Color(0xFFf1faee),
            body: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            "expiration dates",
                            style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFbc6c25),
                            ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: SwitchListTile(
                                title: Text(
                                    "automatically set expiration dates",
                                    style: GoogleFonts.poppins(fontSize: 15),
                                ),
                                subtitle: Text(
                                    "uses AI to estimate expiration dates when scanning - no date picker shown",
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                                ),
                                value: _autoExpiration,
                                activeColor: const Color(0xFF606C38),
                                onChanged: _setAutoExpiration
                            ),
                        ),
                    ],
                ),
            );
    }
}




