import 'package:flutter/material.dart';
import 'package:syntrak/models/activity.dart';

class ActivityTypeSelector extends StatelessWidget {
  const ActivityTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Activity Type'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(24),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildActivityTypeCard(context, ActivityType.run, Icons.directions_run, 'Run'),
          _buildActivityTypeCard(context, ActivityType.ride, Icons.directions_bike, 'Ride'),
          _buildActivityTypeCard(context, ActivityType.walk, Icons.directions_walk, 'Walk'),
          _buildActivityTypeCard(context, ActivityType.hike, Icons.terrain, 'Hike'),
          _buildActivityTypeCard(context, ActivityType.swim, Icons.pool, 'Swim'),
          _buildActivityTypeCard(context, ActivityType.other, Icons.fitness_center, 'Other'),
        ],
      ),
    );
  }

  Widget _buildActivityTypeCard(
    BuildContext context,
    ActivityType type,
    IconData icon,
    String label,
  ) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pop(context, type),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFFF4500)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

