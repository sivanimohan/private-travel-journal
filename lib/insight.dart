import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

class InsightPage extends StatelessWidget {
  final Databases databases;
  final String userId;

  const InsightPage({
    super.key,
    required this.databases,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Insights',
            style: TextStyle(fontFamily: 'JosefinSans')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightCard(
              icon: Icons.timer,
              title: 'Travel Duration Patterns',
              content:
                  'Analyzes your typical trip lengths and when you get restless',
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              icon: Icons.place,
              title: 'Location Preferences',
              content:
                  'Shows your favorite types of destinations (museums, nature, etc.)',
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              icon: Icons.schedule,
              title: 'Daily Routines',
              content:
                  'Identifies your unconscious travel habits (like bakery visits at 3pm)',
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              icon: Icons.attach_money,
              title: 'Spending Patterns',
              content: 'Compares your expenses with local averages',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'JosefinSans',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(content,
                      style: const TextStyle(
                        fontFamily: 'JosefinSans',
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
