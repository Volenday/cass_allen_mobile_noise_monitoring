import 'package:flutter/material.dart';
import 'package:flutter_noise_meter_demo/main.dart';
import 'package:flutter_noise_meter_demo/screens/record.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _passwordVisible = false;
  bool _rememberMe = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> _login() async {
    final apiUrl = dotenv.env['API_URL'];
    final apiKey = dotenv.env['API_KEY'];
    final environment = dotenv.env['ENV'];
    final String email = _emailController.text;
    final String password = _passwordController.text;

    final response = await http.post(
      Uri.parse('$apiUrl/api/auth/email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "emailAddress": email,
        "password": password,
        "apiKey": apiKey,
        "environment": environment
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      // Get the EmailAddress from the login response
      final String loginUserEmail = responseData['account']['EmailAddress'];
      final String loginUserToken = responseData['token'];
      final String refreshToken = responseData['refreshToken'];

      // Fetch StationAdmins data
      final stationAdminsResponse = await http.get(
        Uri.parse('$apiUrl/api/e/StationAdmins'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': loginUserToken
        },
      );

      if (stationAdminsResponse.statusCode == 200) {
        final stationAdminsData =
            jsonDecode(stationAdminsResponse.body)['data'];

        // Filter the admins based on EmailAddress
        final admin = stationAdminsData.firstWhere(
          (admin) => admin['Admin']['User']['EmailAddress'] == loginUserEmail,
          orElse: () => null, // Return null if no match is found
        );

        if (admin == null) {
          _showErrorDialog('User not found in station admins');
          return;
        }

        await _secureStorage.write(
            key: 'user_credentials', value: jsonEncode(admin));
        await _secureStorage.write(key: 'token', value: loginUserToken);
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);

        _showSuccessDialog();
      } else {
        _showErrorDialog('Failed to fetch station admins');
      }
    } else {
      _showErrorDialog(response.body);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Login successful! Redirecting...'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const RecordScreen()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Container(
            height: 200,
            color: Theme.of(context).colorScheme.primary,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 70,
                  // left: 0,
                  child: Image.network(
                      'https://d3t9tvgbdc7c7w.cloudfront.net/development/applications/5f994eb0-1642-11ef-adfb-89cfc197f417/cass-allen-logo-3.png'),
                ),
                Positioned(
                  top: -150,
                  child: Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(
                          0.1), // Semi-transparent white background
                    ),
                  ),
                ),
                Positioned(
                  top: -210,
                  child: Container(
                    height: 400,
                    width: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(
                          0.1), // Semi-transparent white background
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.0),
                  topRight: Radius.circular(30.0),
                ),
                color: whiteColor,
              ),
              width: double.infinity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      "Log in",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 30.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.mail_outline),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelText: 'Email Address',
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey, // Gray border color
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary // Gray border color when enabled
                                  ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary // Gray border color when focused
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32.0),
                        TextField(
                          obscureText: !_passwordVisible,
                          controller: _passwordController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary, // Gray border color
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary // Gray border color when enabled
                                  ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary // Gray border color when focused
                                  ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _rememberMe = value!;
                                      });
                                    },
                                  ),
                                ),
                                const Text('Remember me'),
                              ],
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft),
                              onPressed: () {
                                // Handle forgot password
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: FloatingActionButton.extended(
            foregroundColor: whiteColor,
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _login,
            label: const Text('Log in'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
    );
  }
}
