import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'hospital_screen.dart';
import 'road_user_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      const Icon(Icons.emergency, color: Colors.red, size: 70),

                      const SizedBox(height: 20),

                      const Text(
                        'PrāṇaSārathi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Guiding Every Life to Safety',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 15),
                      ),

                      const SizedBox(height: 50),

                      _roleButton(
                        context,
                        icon: Icons.local_shipping,
                        title: 'Ambulance Driver',
                        subtitle: 'Start and manage emergency journeys',
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(
                                token: 'demo-token',
                                userName: 'Ambulance Driver',
                                userId: 'AMB001',
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      _roleButton(
                        context,
                        icon: Icons.local_hospital,
                        title: 'Hospital',
                        subtitle: 'Receive ambulance arrival alerts',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HospitalScreen(
                                userId: 'HOS001',
                                userName: 'Demo Hospital',
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      _roleButton(
                        context,
                        icon: Icons.directions_car,
                        title: 'Road User',
                        subtitle: 'Receive emergency vehicle alerts',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RoadUserScreen(
                                userId: 'ROAD001',
                                userName: 'Demo Road User',
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        'Real-time emergency response system',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _roleButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 30),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
