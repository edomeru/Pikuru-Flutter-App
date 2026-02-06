import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/loginpage.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {

  final _fireStore = FirebaseFirestore.instance;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool agree = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool showSpinner = false;

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

      body: ModalProgressHUD(
        inAsyncCall: showSpinner,
        child: FadeTransition(
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

                        const SizedBox(height: 6),
                        TextFormField(
                          controller: firstNameController,
                          decoration: _inputDecoration("Firstname"),
                          validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 6),
                        TextFormField(
                          controller: lastNameController,
                          decoration: _inputDecoration("Lastname"),
                          validator: (v) =>
                          v == null || v.isEmpty ? "Required" : null,
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          decoration: _inputDecoration("Email"),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Required";
                            if (!v.contains("@")) return "Invalid email";
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          decoration: _inputDecoration("Password").copyWith(
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

                        const SizedBox(height: 6),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: _inputDecoration("Confirm Password").copyWith(
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

                        // ---------------- NEW SIGN UP BUTTON ----------------
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              if (!_formKey.currentState!.validate()) return;

                              if (!agree) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("You must agree to the terms first"),
                                  ),
                                );
                                return;
                              }

                              setState(() => showSpinner = true);

                              try {
                                final credential =
                                await FirebaseAuth.instance
                                    .createUserWithEmailAndPassword(
                                  email: emailController.text.trim(),
                                  password: passwordController.text.trim(),
                                );

                                await _fireStore.collection("registration").add({
                                  "email": emailController.text.trim(),
                                  "firstName": firstNameController.text.trim(),
                                  "lastName": lastNameController.text.trim(),
                                });

                                setState(() => showSpinner = false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Account created successfully"),
                                  ),
                                );

                              } on FirebaseAuthException catch (e) {
                                setState(() => showSpinner = false);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message ?? "Auth error")),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward,
                                      color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // ---------------- BOTTOM CURVED SECTION ----------------
                ClipPath(
                  clipper: BottomCurveClipper(),
                  child: Container(
                    width: double.infinity,
                    color: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Text(
                          "Already have an account?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "Login",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward,
                                    color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- INPUT DECORATION ----------------

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(
      vertical: 14,
      horizontal: 12,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 1.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 1.5,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
        width: 2,
      ),
    ),
  );
}

// ---------------- HEADER CLIPPER ----------------

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

// ---------------- BOTTOM CURVE CLIPPER ----------------

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    path.moveTo(0, 40);
    path.quadraticBezierTo(
      size.width * 0.5,
      -40,
      size.width,
      40,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
