import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/widgets/event_card.dart';
import 'package:pikuru/widgets/group_card.dart';
import 'package:pikuru/widgets/court_card.dart';
import 'package:pikuru/utils/date_formatter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: SizedBox(
          height: 132,
          child: Image.asset(
            "assets/pikuru_logo.png",
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chat tapped")),
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // UPCOMING EVENTS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Upcoming events",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "See all",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // EVENT CAROUSEL (unchanged)
              SizedBox(
                height: 310,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("events")
                      .orderBy("event_start_date")
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        final Timestamp startDate = data["event_start_date"];
                        final Timestamp startTime = data["event_start_time"];

                        final DateTime date = startDate.toDate();
                        final DateTime time = startTime.toDate();

                        final formattedDateTime =
                        DateFormatter.formatDateTime(date, time);

                        return EventCard(
                          imageUrl: data["event_image"] ?? "",
                          title: data["event_title"] ?? "Untitled Event",
                          dateTime: formattedDateTime,
                          location:
                          data["event_location"] ?? "Unknown location",
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              Container(
                height: 1,
                color: AppColors.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 20),

              // LOCAL GROUPS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Local groups",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "See all",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // GROUPS CAROUSEL
              SizedBox(
                height: 290,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("organizations")
                      .orderBy("org_created_at")
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        return GroupCard(
                          imageUrl: data["org_image"] ?? "",
                          name: data["org_name"] ?? "Unnamed Group",
                          location:
                          data["org_loc_id"] ?? "Unknown location",
                        );
                      },
                    );
                  },
                ),
              ),


              const SizedBox(height: 30),

              Container(
                height: 1,
                color: AppColors.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 20),

              // PICKLEBALL COURTS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Pickleball courts",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "See all",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // PICKLEBALL COURTS CAROUSEL
              SizedBox(
                height: 290,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("locations")
                      .orderBy("loc_created_at")
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        return CourtCard(
                          imageUrl: data["loc_image"] ?? "",
                          name: data["loc_name"] ?? "Unnamed Group",
                          location:
                          data["loc_org_id"] ?? "Unknown location",
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

             // WELCOME TEXT
              const Text(
                "Welcome to Pikuru!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Find pickleball courts and events near you 🎾",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              // BUTTONS COLUMN
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WHAT IS PICKLEBALL BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "What is Pickleball?",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ABOUT PIKURU BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "About Pikuru",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // EXTRA SPACE BELOW BUTTON
                  const SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
