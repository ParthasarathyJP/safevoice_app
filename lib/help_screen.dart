import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Help & Support')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Intro Card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Welcome to SafeVoice Help. Here you’ll find guidance on using the app and accessing support.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          SizedBox(height: 20),

          // How to use application
          _buildHelpCard(
            context,
            "1. How to use application",
            "Learn how to navigate SafeVoice, report incidents, and access emergency services quickly.",
          ),

          _buildHelpCard(
            context,
            "2. Citizen Dashboard",
            "View statistics, complaint history, and transparency logs in your personalized dashboard.",
          ),

          _buildHelpCard(
            context,
            "3. Complaint",
            "Submit complaints with location sharing and track them using your unique Tracking ID.",
          ),

          _buildHelpCard(
            context,
            "4. Settings",
            "Configure station selection, stats filter mode, and privacy options to suit your needs.",
          ),

          _buildHelpCard(
            context,
            "5. My Profile",
            "Manage your personal details, verify your phone number, and earn milestone badges.",
          ),

          SizedBox(height: 20),

          // Contact Card
          Card(
            elevation: 6,
            color: Colors.deepPurple.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("6. For More Information",
                      style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  Text(
                    "Contact: +91 9176735479",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, String title, String description) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}