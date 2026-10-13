import 'package:flutter/material.dart';

import '../../core/theme.dart';

import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../more/more_screen.dart';
import '../payments/payments_screen.dart';
import '../progress/progress_screen.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key, required this.onLogout});
  final Future<void> Function() onLogout;
  @override
  State<ParentShell> createState() => _ShellState();
}

class _ShellState extends State<ParentShell> {
  int index = 0;
  List<Widget> get pages => [
    const HomeScreen(),
    const ProgressScreen(),
    const PaymentsScreen(),
    const MessagesScreen(),
    MoreScreen(onLogout: widget.onLogout),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(index: index, children: pages),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        height: 76,
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1406322C),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _destination(0, Icons.home_rounded, 'Home'),
            _destination(1, Icons.auto_graph_rounded, 'Progress'),
            _destination(2, Icons.receipt_long_rounded, 'Payments'),
            _destination(3, Icons.chat_bubble_rounded, 'Messages'),
            _destination(4, Icons.grid_view_rounded, 'More'),
          ],
        ),
      ),
    ),
  );

  Widget _destination(int value, IconData icon, String label) {
    final selected = value == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => index = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? AppColors.softMint : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? AppColors.forest : AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? AppColors.forest : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
