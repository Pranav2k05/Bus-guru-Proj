// lib/widgets/wallet_fab.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "wallet_fab",
      backgroundColor: Colors.white,
      elevation: 4,
      onPressed: () => showDialog(
        context: context,
        builder: (_) => const WalletDialog(),
      ),
      child: Icon(
        Icons.account_balance_wallet,
        color: Theme.of(context).colorScheme.primary,
        size: 26,
      ),
    );
  }

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const WalletDialog(),
    );
  }
}

class WalletDialog extends StatefulWidget {
  const WalletDialog({super.key});

  @override
  State<WalletDialog> createState() => _WalletDialogState();
}

class _WalletDialogState extends State<WalletDialog> {
  double balance = 0.0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      balance = prefs.getDouble('wallet_balance') ?? 200.0; // default
      loading = false;
    });
  }

  Future<void> _recharge() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      balance += 100;
    });
    await prefs.setDouble('wallet_balance', balance);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recharged ₹100 (offline demo)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 380,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wallet Balance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _recharge,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Recharge ₹100"),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Offline wallet demo. Real transaction will sync with backend.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  )
                ],
              ),
      ),
    );
  }
}
