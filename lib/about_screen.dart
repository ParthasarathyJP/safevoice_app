import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About SafeVoice')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Profile Card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Profile", style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  _buildDetail("Name", "Sarathy – Strategic Senior Architect"),
                  _buildDetail("Role", "Policy Advocate & Civic Educator"),
                  _buildDetail("Region", "Manimangalam, Kancheepuram District, Tamil Nadu"),
                  SizedBox(height: 10),
                  Text("Identity Anchor:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    "Sarathy blends technical clarity with civic empowerment, driving integrated infrastructure, "
                    "eco-tourism, and dignity-based recognition systems. As architect of the SafeVoice app, "
                    "he champions modular settings, privacy transparency, and citizen-centric complaint routing.",
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Operational Focus Card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Operational Focus", style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  _buildBullet("Modular Settings: Station selection, stats filter mode, location sharing toggle"),
                  _buildBullet("Complaint Routing: Device-specific logic with privacy-first transparency"),
                  _buildBullet("Dashboard Logic: Rolling window + calendar-based stats for citizen clarity"),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Symbolism & Recognition Card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Symbolism & Recognition", style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  _buildBullet("Campaign Emblem: DRKITE – “The Invisible Guide of Excellence”"),
                  _buildBullet("Heroes: DrKooya & DrKite as symbolic guides for citizen empowerment"),
                  _buildBullet("Milestone Badges: Transparency Champion, Collective Responsibility Builder"),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Citizen Promise Card
          Card(
            elevation: 6,
            color: Colors.deepPurple.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Citizen Promise", style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 10),
                  Text(
                    "SafeVoice is more than an app—it is a dignity-driven platform where every complaint is heard, "
                    "tracked, and resolved with transparency. Citizens are empowered to choose, share, and celebrate "
                    "their role in building a safer Tamil Nadu.",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text("Tagline:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    "“SafeVoice – Dignity in Every Report.”",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
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

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(fontSize: 18)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}