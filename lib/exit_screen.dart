import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for SystemNavigator.pop()

class ExitScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          SystemNavigator.pop(); // closes the app gracefully
        },
        icon: Icon(Icons.exit_to_app),
        label: Text('Exit SafeVoice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}