import 'package:flutter/material.dart';
import 'package:pikuru/register/RegisterPage.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Home")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RegisterPage()),
            );
          },
          child: const Text("Go to Register Page"),
        ),
      ),
    );
  }
}
