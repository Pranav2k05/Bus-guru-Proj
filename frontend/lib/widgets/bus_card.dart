// lib/widgets/bus_card.dart
import 'package:flutter/material.dart';
import '../screens/qr_ticket_screen.dart';
import '../services/api_service.dart';

class BusCard extends StatelessWidget {
  final Map bus;
  const BusCard({super.key, required this.bus});

  @override Widget build(BuildContext context) {
    return InkWell(
      onTap: ()=>_openBooking(context),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Row(children: [
          Container(width: 120, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)) ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bus['bus_no'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${bus['available_seats'] ?? 0} seats', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bus['route'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Text('ETA: ${bus['eta'] ?? '—'}', style: const TextStyle(color: Colors.black54)),
            ])
          ]))),
          Padding(padding: const EdgeInsets.all(8), child: ElevatedButton(onPressed: ()=>_openBooking(context), child: const Text('Book')))
        ]),
      ),
    );
  }

  void _openBooking(BuildContext context) {
    showDialog(context: context, builder: (_) => BookingModal(bus: bus));
  }
}

class BookingModal extends StatefulWidget {
  final Map bus;
  const BookingModal({super.key, required this.bus});
  @override State<BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends State<BookingModal> {
  bool loading = false;

  Future<void> _book() async {
    setState(()=>loading=true);
    // pick user_id from local storage or demo=1
    final res = await ApiService.post('booking/book', {'user_id': 1, 'bus_id': widget.bus['id'], 'amount': 50});
    setState(()=>loading=false);
    if (res != null && res['status'] == 'ok') {
      Navigator.pop(context);
      final qrPath = res['qr_path'] as String? ?? '';
      Navigator.push(context, MaterialPageRoute(builder: (_) => QRTicketScreen(qrPath: qrPath)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed')));
    }
  }

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(padding: const EdgeInsets.all(16), width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Confirm Booking', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text('${widget.bus['bus_no']} • ${widget.bus['route']}'),
        const SizedBox(height: 12),
        Row(children: const [Text('Fare:'), Spacer(), Text('₹50', style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 18),
        loading ? const CircularProgressIndicator() : Row(children: [
          Expanded(child: OutlinedButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: _book, child: const Text('Pay & Book'))),
        ])
      ])),
    );
  }
}
