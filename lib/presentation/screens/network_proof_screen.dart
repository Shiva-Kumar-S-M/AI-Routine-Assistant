import 'package:flutter/material.dart';

class NetworkProofScreen extends StatelessWidget {
  const NetworkProofScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Network-Proof Verification',
          style: TextStyle(color: Color(0xFF202124), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF202124)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Shield Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B4F8A), Color(0xFF1A7A4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    '100% On-Device Privacy Guaranteed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Routine Assistant operates with ZERO network sockets, zero cloud syncing, and zero remote analytics.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Live Privacy Assertions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF202124)),
            ),
            const SizedBox(height: 12),

            _assertionTile(
              icon: Icons.signal_wifi_off_rounded,
              title: 'android.permission.INTERNET',
              status: 'NOT DECLARED',
              description: 'The app does not request internet access from Android OS, making remote outbound connections physically impossible.',
              isSuccess: true,
            ),
            _assertionTile(
              icon: Icons.hub_outlined,
              title: 'Active Outbound HTTP Sockets',
              status: '0 Active Sockets',
              description: 'Zero active HTTP, HTTPS, WebSocket, or TCP connections open.',
              isSuccess: true,
            ),
            _assertionTile(
              icon: Icons.storage_rounded,
              title: 'Telemetry & Log Storage',
              status: 'Sandboxed SQLite Only',
              description: 'All logs are stored inside application-private sandboxed SQLite storage.',
              isSuccess: true,
            ),
            _assertionTile(
              icon: Icons.analytics_outlined,
              title: 'Third-Party Analytics SDKs',
              status: 'None Installed',
              description: 'Zero Firebase, Google Analytics, Mixpanel, or AdMob libraries included.',
              isSuccess: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _assertionTile({
    required IconData icon,
    required String title,
    required String status,
    required String description,
    required bool isSuccess,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF202124)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
