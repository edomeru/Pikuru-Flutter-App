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
