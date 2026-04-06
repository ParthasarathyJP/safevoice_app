import 'package:flutter/material.dart';

class ComplaintFormScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Submit a Complaint',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              labelText: 'Complaint Details',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Placeholder for voice input
            },
            icon: Icon(Icons.mic),
            label: Text('Record Voice'),
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              // Placeholder for file upload
            },
            icon: Icon(Icons.attach_file),
            label: Text('Upload File'),
          ),
        ],
      ),
    );
  }
}