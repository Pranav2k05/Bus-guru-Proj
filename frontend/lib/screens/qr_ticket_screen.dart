// lib/screens/qr_ticket_screen.dart
import 'package:flutter/material.dart';

class QRTicketScreen extends StatelessWidget {
  final String qrPath;
  const QRTicketScreen({super.key, required this.qrPath});

  @override Widget build(BuildContext context) {
    final full = qrPath.startsWith('http') ? qrPath : 'http://127.0.0.1:5000/$qrPath';
    return Scaffold(
      appBar: AppBar(title: const Text('Your Ticket')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Show this QR to the conductor', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Image.network(full, width: 260, height: 260, errorBuilder: (c,e,s)=>const Text('QR image failed to load')),
          const SizedBox(height: 12),
          SelectableText(full)
        ]),
      ),
    );
  }
}
