import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';

class GroupCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String location;

  const GroupCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF32A259).withOpacity(0.001),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary,
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
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: Container(
              height: 220,
              width: double.infinity,
              color: Colors.white, // prevents weird background gaps
              child: Image.network(
                imageUrl.isNotEmpty
                    ? imageUrl
                    : "https://via.placeholder.com/300x200.png?text=No+Image",
                fit: BoxFit.contain, // <-- FIX: shows full logo/image
                errorBuilder: (context, error, stackTrace) =>
                const Center(child: Icon(Icons.broken_image, size: 40)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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
                          fontSize: 11,
                          color: Colors.black,
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
