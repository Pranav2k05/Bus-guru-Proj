// lib/screens/passenger_dashboard.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/bus_card.dart';
import '../widgets/chatbot_fab.dart';
import '../widgets/wallet_fab.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});
  @override State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  List buses = [];
  String query = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchBuses();
  }

  Future<void> fetchBuses() async {
    setState(() => loading = true);
    final res = await ApiService.get('bus/buses');
    setState(() {
      buses = (res is List) ? res : [];
      loading = false;
    });
  }

  @override Widget build(BuildContext context) {
    final filtered = buses.where((b) {
      final route = (b['route'] ?? '').toString().toLowerCase();
      final busno = (b['bus_no'] ?? '').toString().toLowerCase();
      return route.contains(query.toLowerCase()) || busno.contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bus-Guru')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // search
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Search route or bus no'), onChanged: (v)=>setState(()=>query=v))),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: fetchBuses, child: const Text('Refresh'))
          ]),
          const SizedBox(height: 12),
          if (loading) const Expanded(child: Center(child: CircularProgressIndicator())) else Expanded(
            child: filtered.isEmpty ? const Center(child: Text('No buses found')) : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (c,i) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: BusCard(bus: filtered[i])),
            ),
          )
        ]),
      ),
      floatingActionButton: Stack(children: [
        Positioned(bottom: 20, right: 20, child: ChatbotFab()),
        Positioned(bottom: 90, right: 20, child: WalletFab())
      ]),
    );
  }
}
