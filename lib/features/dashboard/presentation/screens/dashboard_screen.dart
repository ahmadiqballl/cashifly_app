import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/transaction_model.dart';
import '../../../../core/database/repositories/asset_repository.dart';
import '../../../asset/presentation/widgets/add_platform_sheet.dart';
import '../../../home/presentation/screens/add_transaction_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../activity/presentation/screens/activity_screen.dart';
import '../../../account/presentation/screens/account_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _fabExpanded = false;

  late final AnimationController _fabController;
  late final Animation<double> _fabAnimation;

  final _assetRepo = AssetRepository();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Key to trigger HomeScreen refresh after FAB actions
  final _homeKey = GlobalKey<HomeScreenState>();

  static const List<String> _titles = [
    '',
    'Aktivitas',
    'Akun',
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabController.reverse();
    }
  }

  Future<void> _openAddTransaction(TransactionType type) async {
    _closeFab();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );
    if (saved == true) _homeKey.currentState?.reload();
  }

  Future<void> _openAddPlatform() async {
    _closeFab();
    final platforms = await _assetRepo.getAll(_userId);
    if (!mounted) return;
    final existingNames = platforms.map((p) => p.name).toList();
    final added = await AddPlatformSheet.show(
      context,
      userId: _userId,
      existingNames: existingNames,
    );
    if (added == true) _homeKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: _currentIndex == 0
              ? Image.asset(
                  'assets/icons/logo.png',
                  height: 30,
                  fit: BoxFit.contain,
                )
              : Text(_titles[_currentIndex]),
          centerTitle: false,
        ),
        body: _ScaleFadeTabSwitcher(
          index: _currentIndex,
          children: [
            HomeScreen(key: _homeKey),
            const ActivityScreen(),
            const AccountScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            _closeFab();
            setState(() => _currentIndex = index);
          },
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Aktivitas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Akun',
            ),
          ],
        ),
        floatingActionButton: _currentIndex == 0 ? _buildFab() : null,
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Sub-buttons (expanded) ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _fabAnimation,
          builder: (_, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FabSubButton(
                  label: 'Tambah Platform',
                  icon: Icons.account_balance_wallet_outlined,
                  progress: _fabAnimation.value,
                  delay: 0.0,
                  onTap: _openAddPlatform,
                ),
                const SizedBox(height: 10),
                _FabSubButton(
                  label: 'Pemasukan',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.success,
                  progress: _fabAnimation.value,
                  delay: 0.08,
                  onTap: () => _openAddTransaction(TransactionType.income),
                ),
                const SizedBox(height: 10),
                _FabSubButton(
                  label: 'Pengeluaran',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.error,
                  progress: _fabAnimation.value,
                  delay: 0.16,
                  onTap: () => _openAddTransaction(TransactionType.expense),
                ),
                const SizedBox(height: 14),
              ],
            );
          },
        ),

        // ── Main FAB ─────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggleFab,
          child: AnimatedBuilder(
            animation: _fabAnimation,
            builder: (_, _) {
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: _fabAnimation.value * (3.14159 / 4), // 0 → 45°
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sub-button item ────────────────────────────────────────────────────────────

class _FabSubButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final double progress;
  final double delay;
  final VoidCallback onTap;

  const _FabSubButton({
    required this.label,
    required this.icon,
    this.iconColor = Colors.white,
    required this.progress,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Each sub-button slides/fades in with a slight delay
    final localProgress = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    final opacity = localProgress;
    final offsetY = (1.0 - localProgress) * 16;

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Opacity(
        opacity: opacity,
        child: IgnorePointer(
          ignoring: progress < 0.01,
          child: GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                        width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Icon button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.textPrimary, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scale+Fade tab switcher ───────────────────────────────────────────────────
// The active tab scales in from 97→100% while fading in.
// Background is always fully opaque — no blank flash.

class _ScaleFadeTabSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _ScaleFadeTabSwitcher({required this.index, required this.children});

  @override
  State<_ScaleFadeTabSwitcher> createState() => _ScaleFadeTabSwitcherState();
}

class _ScaleFadeTabSwitcherState extends State<_ScaleFadeTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_ScaleFadeTabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: child,
        ),
      ),
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}

