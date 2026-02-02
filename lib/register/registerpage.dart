import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool agree = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ---------------- HEADER ----------------
              ClipPath(
                clipper: RegisterHeaderClipper(),
                child: Container(
                  width: double.infinity,
                  height: 260,
                  color: AppColors.primary,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 130,
                        child: Image.asset(
                          "assets/register_pickleball.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ---------------- FORM ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // NAME
                      const Text("Name"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration("Enter your name"),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                      ),

                      const SizedBox(height: 16),

                      // EMAIL
                      const Text("Email"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        decoration: _inputDecoration("Enter your email"),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Required";
                          if (!v.contains("@")) return "Invalid email";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // PASSWORD
                      const Text("Password"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        decoration: _inputDecoration("Enter password").copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => showPassword = !showPassword);
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Required";
                          if (v.length < 6) return "Min 6 characters";
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      const Text("Confirm Password"),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        decoration: _inputDecoration("Re-enter password").copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() =>
                              showConfirmPassword = !showConfirmPassword);
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Required";
                          if (v != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // TERMS CHECKBOX
                      Row(
                        children: [
                          Checkbox(
                            value: agree,
                            onChanged: (v) {
                              setState(() => agree = v ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              "I agree to the Terms & Conditions and Privacy Policy",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ---------------- SIGN UP BUTTON ----------------
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            print("SIGN UP PRESSED");
                            print(emailController.text.trim());
                            print(passwordController.text.trim());

                            if (!_formKey.currentState!.validate()) return;

                            if (!agree) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("You must agree to the terms first"),
                                ),
                              );
                              return;
                            }

                            try {
                              final credential = await FirebaseAuth.instance
                                  .createUserWithEmailAndPassword(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Account created successfully"),
                                ),
                              );

                            } on FirebaseAuthException catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message ?? "Auth error")),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, color: Colors.white),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // LOGIN LINK
                      Center(
                        child: GestureDetector(
                          onTap: () {},
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Already have an account? "),
                              Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

class RegisterHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.lineTo(0, size.height - 80);

    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 1.5,
      size.width + 300,
      size.height - 250,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
