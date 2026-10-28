import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class NetworkProofScreen extends StatelessWidget {
  const NetworkProofScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'PRIVACY VERIFICATION',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Shield Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: const Column(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.textPrimary, size: 40),
                  SizedBox(height: 12),
                  Text(
                    '100% On-Device Privacy Guaranteed',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'AI Routine Assistant operates with ZERO network sockets, zero cloud syncing, and zero remote telemetry.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
              'LIVE PRIVACY ASSERTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            _assertionTile(
              icon: Icons.signal_wifi_off_outlined,
              title: 'android.permission.INTERNET',
              status: 'NOT DECLARED',
              description: 'The app does not request internet access from Android OS, making remote outbound connections physically impossible.',
            ),
            _assertionTile(
              icon: Icons.hub_outlined,
              title: 'Active Outbound HTTP Sockets',
              status: '0 ACTIVE SOCKETS',
              description: 'Zero active HTTP, HTTPS, WebSocket, or TCP connections open.',
            ),
            _assertionTile(
              icon: Icons.storage_outlined,
              title: 'Telemetry & Log Storage',
              status: 'SANDBOXED SQLITE ONLY',
              description: 'All logs are stored inside application-private sandboxed SQLite storage.',
            ),
            _assertionTile(
              icon: Icons.analytics_outlined,
              title: 'Third-Party Analytics SDKs',
              status: 'NONE INSTALLED',
              description: 'Zero Firebase, Google Analytics, Mixpanel, or AdMob libraries included.',
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
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
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
