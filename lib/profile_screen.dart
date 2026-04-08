import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _genderController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  String _verificationId = "";
  bool _isPhoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile(); // load saved profile when screen opens
  }

  Future<void> _verifyPhone() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        setState(() {
          _isPhoneVerified = true;
          _verificationId = "";
        });
        _saveProfileLocally();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Phone verified automatically")),
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent to phone")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _confirmOTP(String smsCode) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);

    setState(() {
      _isPhoneVerified = true;
      _verificationId = "";
    });

    _saveProfileLocally();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Phone verified successfully")),
    );
  }

  Future<void> _saveProfileLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", _nameController.text);
    await prefs.setString("gender", _genderController.text);
    await prefs.setInt("age", int.tryParse(_ageController.text) ?? 0);
    await prefs.setString("phone", _phoneController.text);
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString("name") ?? "";
      _genderController.text = prefs.getString("gender") ?? "";
      _ageController.text = (prefs.getInt("age") ?? 0).toString();
      _phoneController.text = prefs.getString("phone") ?? "";
      // If phone already verified before, skip OTP
      _isPhoneVerified = _phoneController.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Profile')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Name"),
              ),
              TextFormField(
                controller: _genderController,
                decoration: InputDecoration(labelText: "Gender"),
              ),
              TextFormField(
                controller: _ageController,
                decoration: InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20),
              if (!_isPhoneVerified)
                ElevatedButton(
                  onPressed: _verifyPhone,
                  child: Text("Verify Phone"),
                ),
              if (!_isPhoneVerified && _verificationId.isNotEmpty)
                TextFormField(
                  decoration: InputDecoration(labelText: "Enter OTP"),
                  onFieldSubmitted: (code) => _confirmOTP(code),
                ),
              if (_isPhoneVerified)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    "✅ Phone verified and profile saved locally",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}