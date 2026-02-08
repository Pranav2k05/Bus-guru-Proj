import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const BusGuruApp());
}

class BusGuruApp extends StatefulWidget {
  const BusGuruApp({super.key});
  @override
  State<BusGuruApp> createState() => _BusGuruAppState();
}

class _BusGuruAppState extends State<BusGuruApp> {
  String token = '';
  String userName = 'Guest';
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Guru',
      theme: ThemeData.dark(useMaterial3: true),
      home: HomeShell(
        token: token,
        userName: userName,
        onAuth: (t, n) => setState(() {
          token = t;
          userName = n;
        }),
        onLogout: () => setState(() {
          token = '';
          userName = 'Guest';
        }),
      ),
    );
  }
}

const api = 'http://localhost:8001';

class HomeShell extends StatefulWidget {
  final String token;
  final String userName;
  final Function(String, String) onAuth;
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.token, required this.userName, required this.onAuth, required this.onLogout});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = [
      AuthPage(onAuth: widget.onAuth),
      PlanPage(token: widget.token),
      TicketsPage(token: widget.token),
      ChatPage(token: widget.token, userName: widget.userName),
      ScannerPage(token: widget.token),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('BMTC Bus Guru'),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(widget.userName))),
          if (widget.token.isNotEmpty)
            TextButton(onPressed: widget.onLogout, child: const Text('Logout'))
        ],
      ),
      body: tabs[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.directions_bus), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.confirmation_number), label: 'Tickets'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
        ],
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  final Function(String, String) onAuth;
  const AuthPage({super.key, required this.onAuth});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final suName = TextEditingController();
  final suEmail = TextEditingController();
  final suPass = TextEditingController();
  final liEmail = TextEditingController();
  final liPass = TextEditingController();
  String msg = '';
  Future<void> signup() async {
    setState(() => msg = '');
    final r = await http.post(Uri.parse('$api/auth/signup'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': suName.text, 'email': suEmail.text, 'password': suPass.text}));
    if (r.statusCode == 200) {
      setState(() => msg = 'Account created. Please login.');
    } else {
      setState(() => msg = 'Signup failed.');
    }
  }
  Future<void> login() async {
    setState(() => msg = '');
    final r = await http.post(Uri.parse('$api/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': 'User', 'email': liEmail.text, 'password': liPass.text}));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body);
      widget.onAuth(j['user_email'], j['user_name']);
      setState(() => msg = 'Login successful.');
    } else {
      setState(() => msg = 'Invalid credentials.');
    }
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Text('Signup', style: TextStyle(fontSize: 18)),
            TextField(controller: suName, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: suEmail, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: suPass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: signup, child: const Text('Create Account')),
          ]))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Text('Login', style: TextStyle(fontSize: 18)),
            TextField(controller: liEmail, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: liPass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: login, child: const Text('Login')),
          ]))),
          const SizedBox(height: 8),
          Text(msg),
        ],
      ),
    );
  }
}

class Bus {
  final int id;
  final String busName;
  final String routeName;
  final String startStop;
  final String endStop;
  final String departureTime;
  final double fare;
  final int seats;
  final List<List<double>> routeCoords;
  final List<String> stops;
  Bus.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        busName = j['bus_name'],
        routeName = j['route_name'],
        startStop = j['start_stop'],
        endStop = j['end_stop'],
        departureTime = j['departure_time'],
        fare = (j['fare'] as num).toDouble(),
        seats = j['total_seats'],
        routeCoords = (j['route_coords'] as List).map((e) => (e as List).map((n) => (n as num).toDouble()).toList()).toList(),
        stops = (j['stops'] as List).map((e) => e.toString()).toList();
}

class PlanPage extends StatefulWidget {
  final String token;
  const PlanPage({super.key, required this.token});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  List<String> stops = [];
  List<Bus> buses = [];
  String? start;
  String? end;
  Bus? selectedBus;
  @override
  void initState() {
    super.initState();
    loadData();
  }
  Future<void> loadData() async {
    final s = await http.get(Uri.parse('$api/stops'));
    final b = await http.get(Uri.parse('$api/buses'));
    if (s.statusCode == 200 && b.statusCode == 200) {
      setState(() {
        stops = (jsonDecode(s.body) as List).map((e) => e.toString()).toList();
        buses = (jsonDecode(b.body) as List).map((e) => Bus.fromJson(e)).toList();
      });
    }
  }
  List<Bus> filtered() {
    return buses.where((b) {
      final hasStart = start == null || b.startStop == start || b.stops.contains(start);
      final hasEnd = end == null || b.endStop == end || b.stops.contains(end);
      return hasStart && hasEnd;
    }).toList();
  }
  Future<void> book(Bus b, int seats) async {
    if (widget.token.isEmpty) return;
    final r = await http.post(Uri.parse('$api/book?token=${Uri.encodeComponent(widget.token)}'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'bus_id': b.id, 'seats': seats}));
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booked')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking failed')));
    }
    await loadData();
  }
  @override
  Widget build(BuildContext context) {
    final list = filtered();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: start, items: stops.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => start = v), decoration: const InputDecoration(labelText: 'Start'))),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(value: end, items: stops.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => end = v), decoration: const InputDecoration(labelText: 'End'))),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: () => setState(() {}), child: const Text('Search')),
          ]),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final b = list[i];
                    return Card(
                      child: ListTile(
                        title: Text('${b.busName} • ${b.routeName}'),
                        subtitle: Text('Departs ${b.departureTime} • Fare ₹${b.fare.toStringAsFixed(2)} • Seats ${b.seats}'),
                        trailing: PopupMenuButton<int>(
                          onSelected: (n) => book(b, n),
                          itemBuilder: (_) => [1,2,3,4,5].map((n) => PopupMenuItem(value: n, child: Text('Book $n'))).toList(),
                        ),
                        onTap: () => setState(() => selectedBus = b),
                      ),
                    );
                  },
                ),
              ),
              Expanded(child: selectedBus == null ? const Center(child: Text('Select a bus to view route')) : RouteMap(bus: selectedBus!)),
            ],
          ),
        ),
      ],
    );
  }
}

class RouteMap extends StatelessWidget {
  final Bus bus;
  const RouteMap({super.key, required this.bus});
  @override
  Widget build(BuildContext context) {
    final coords = bus.routeCoords.map((p) => LatLng(p[0], p[1])).toList();
    final center = coords.isNotEmpty ? coords.first : const LatLng(12.9716, 77.5946);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'bus_guru_flutter'),
        PolylineLayer(polylines: [Polyline(points: coords, strokeWidth: 4, color: Colors.blueAccent)]),
        MarkerLayer(markers: coords.map((p) => Marker(point: p, child: const Icon(Icons.location_on, color: Colors.red))).toList()),
      ],
    );
  }
}

class Ticket {
  final int id;
  final int seats;
  final double totalPrice;
  final String date;
  final String busName;
  final String routeName;
  final bool validated;
  Ticket.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        seats = j['seats_booked'],
        totalPrice = (j['total_price'] as num).toDouble(),
        date = j['booking_date'],
        busName = j['bus_name'],
        routeName = j['route_name'],
        validated = j['validated'] == true;
}

class TicketsPage extends StatefulWidget {
  final String token;
  const TicketsPage({super.key, required this.token});
  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  List<Ticket> tickets = [];
  @override
  void initState() {
    super.initState();
    load();
  }
  Future<void> load() async {
    if (widget.token.isEmpty) return;
    final r = await http.get(Uri.parse('$api/my-bookings?token=${Uri.encodeComponent(widget.token)}'));
    if (r.statusCode == 200) {
      setState(() {
        tickets = (jsonDecode(r.body) as List).map((e) => Ticket.fromJson(e)).toList();
      });
    }
  }
  Future<void> validate(int id) async {
    final r = await http.post(Uri.parse('$api/validate-ticket'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'booking_id': id}));
    if (r.statusCode == 200) {
      await load();
    }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.token.isEmpty) return const Center(child: Text('Login required'));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        itemCount: tickets.length,
        itemBuilder: (c, i) {
          final t = tickets[i];
          return Card(
            child: ListTile(
              title: Text('#${t.id} • ${t.busName} • ${t.routeName}'),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.date} • ₹${t.totalPrice.toStringAsFixed(2)} • ${t.seats} seats'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Center(child: QrImageView(data: 'BG:${t.id}', size: 120))),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: t.validated ? null : () => validate(t.id), child: Text(t.validated ? 'Validated' : 'Validate Ticket')),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String token;
  final String userName;
  const ChatPage({super.key, required this.token, required this.userName});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ctrl = TextEditingController();
  final msgs = <Map<String, String>>[];
  String prevLang = 'en';
  stt.SpeechToText? speech;
  bool listening = false;
  Future<void> initStt() async {
    speech ??= stt.SpeechToText();
    await speech!.initialize();
  }
  Future<void> toggleMic() async {
    await initStt();
    if (listening) {
      speech!.stop();
      setState(() => listening = false);
      return;
    }
    setState(() => listening = true);
    speech!.listen(onResult: (r) {
      setState(() {
        ctrl.text = r.recognizedWords;
      });
    });
  }
  Future<void> send() async {
    final m = ctrl.text.trim();
    if (m.isEmpty) return;
    setState(() {
      msgs.add({'role': 'you', 'content': m});
      ctrl.clear();
    });
    final r = await http.post(Uri.parse('$api/chat'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'message': m, 'token': widget.token.isEmpty ? null : widget.token, 'prev_lang': prevLang}));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body);
      setState(() {
        prevLang = j['lang'] ?? prevLang;
        msgs.add({'role': 'ai', 'content': j['response'] ?? ''});
      });
    } else {
      setState(() {
        msgs.add({'role': 'ai', 'content': 'Service unavailable'});
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: msgs.length,
            itemBuilder: (c, i) {
              final m = msgs[i];
              final isYou = m['role'] == 'you';
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Align(alignment: isYou ? Alignment.centerRight : Alignment.centerLeft, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isYou ? Colors.blueGrey : Colors.green.shade700, borderRadius: BorderRadius.circular(10)), child: Text(m['content'] ?? ''))),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Type message'))),
            const SizedBox(width: 8),
            IconButton(onPressed: toggleMic, icon: Icon(listening ? Icons.mic : Icons.mic_none)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: send, child: const Text('Send')),
          ]),
        )
      ],
    );
  }
}

class ScannerPage extends StatefulWidget {
  final String token;
  const ScannerPage({super.key, required this.token});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String status = 'Point camera at QR';
  Future<void> validateTicket(int id) async {
    final r = await http.post(Uri.parse('$api/validate-ticket'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'booking_id': id}));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body);
      setState(() => status = (j['message'] ?? j['status']).toString());
    } else {
      setState(() => status = 'Validation failed');
    }
  }
  void onDetect(BarcodeCapture cap) {
    final codes = cap.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? '';
    if (raw.startsWith('BG:')) {
      final idStr = raw.substring(3);
      final id = int.tryParse(idStr);
      if (id != null) {
        validateTicket(id);
      } else {
        setState(() => status = 'Invalid QR');
      }
    } else {
      setState(() => status = 'Unknown QR');
    }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.token.isEmpty) {
      return const Center(child: Text('Login required'));
    }
    return Column(
      children: [
        Expanded(child: MobileScanner(onDetect: onDetect)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(status),
        )
      ],
    );
  }
}
