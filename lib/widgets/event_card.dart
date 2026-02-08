import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';

class EventCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String dateTime;
  final String location;

  const EventCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.dateTime,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, // <-- REDUCED WIDTH
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF32A259).withOpacity(0.02), // <-- 10% opacity
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary, // <-- border stroke
          width: 0.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          // IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: Image.network(
              imageUrl.isNotEmpty
                  ? imageUrl
                  : "https://via.placeholder.com/300x200.png?text=No+Image",
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // <-- important
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  dateTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
