import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/asset_platform_model.dart';

/// Kartu diagram aset — bisa swipe antara Pie Chart dan Bar Chart.
/// Struktur: box biru (outer) → box putih (inner) → diagram.
class AssetChartCard extends StatefulWidget {
  final List<AssetPlatform> platforms;

  const AssetChartCard({super.key, required this.platforms});

  @override
  State<AssetChartCard> createState() => _AssetChartCardState();
}

class _AssetChartCardState extends State<AssetChartCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<String> _chartTitles = ['Distribusi Aset', 'Perbandingan Saldo'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<AssetPlatform> get _activePlatforms =>
      widget.platforms.where((p) => p.balance > 0).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: judul + dot indicators ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _chartTitles[_currentPage],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: List.generate(2, (i) {
                    final isActive = i == _currentPage;
                    return GestureDetector(
                      onTap: () => _goToPage(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 6),
                        width: isActive ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── White inner box with PageView ────────────────────────────────────
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.textPrimary, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _PieChartView(platforms: _activePlatforms),
                  _BarChartView(platforms: _activePlatforms),
                ],
              ),
            ),
          ),

          // ── Swipe hint ───────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 6),
            child: Row(
              children: [
                Icon(Icons.swipe_rounded, color: Colors.white70, size: 13),
                SizedBox(width: 4),
                Text(
                  'Geser untuk berganti diagram',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pie Chart View ────────────────────────────────────────────────────────────

class _PieChartView extends StatelessWidget {
  final List<AssetPlatform> platforms;

  const _PieChartView({required this.platforms});

  @override
  Widget build(BuildContext context) {
    if (platforms.isEmpty) {
      return const _EmptyChart(message: 'Belum ada aset dengan saldo > 0');
    }

    final total = platforms.fold(0.0, (s, p) => s + p.balance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Pie
          Expanded(
            flex: 5,
            child: CustomPaint(
              painter: _PiePainter(platforms: platforms, total: total),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(width: 10),
          // Legend
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: platforms.map((p) {
                  final pct = total > 0 ? (p.balance / total * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: Color(p.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _shortName(p.name),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    if (name == 'Uang Cash') return 'Cash';
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }
}

class _PiePainter extends CustomPainter {
  final List<AssetPlatform> platforms;
  final double total;

  _PiePainter({required this.platforms, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final innerRadius = radius * 0.5; // donut hole

    double startAngle = -math.pi / 2; // start at top

    for (final p in platforms) {
      final sweep = (p.balance / total) * 2 * math.pi;
      final paint = Paint()
        ..color = Color(p.colorValue)
        ..style = PaintingStyle.fill;

      // outer arc
      final path = Path()
        ..moveTo(
          center.dx + innerRadius * math.cos(startAngle),
          center.dy + innerRadius * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          startAngle + sweep,
          -sweep,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // thin white gap between slices
      final gapPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, gapPaint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.platforms != platforms || old.total != total;
}

// ── Bar Chart View ────────────────────────────────────────────────────────────

class _BarChartView extends StatelessWidget {
  final List<AssetPlatform> platforms;

  const _BarChartView({required this.platforms});

  // Left margin reserved for Y-axis labels
  static const double _yAxisWidth = 52.0;
  // Number of horizontal gridlines (and Y labels)
  static const int _gridCount = 4;

  @override
  Widget build(BuildContext context) {
    if (platforms.isEmpty) {
      return const _EmptyChart(message: 'Belum ada aset dengan saldo > 0');
    }

    final maxBalance = platforms.fold(0.0, (m, p) => math.max(m, p.balance));

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 12, 8),
      child: Column(
        children: [
          // Chart area: Y-axis labels + bars
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Y-axis labels ──────────────────────────────────────────
                SizedBox(
                  width: _yAxisWidth,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final h = constraints.maxHeight;
                      return Stack(
                        children: List.generate(_gridCount + 1, (i) {
                          // i=0 → top (max), i=gridCount → bottom (0)
                          final fraction = i / _gridCount;
                          final value = maxBalance * (1 - fraction);
                          final top = h * fraction - 7;
                          return Positioned(
                            top: top.clamp(0.0, h - 14),
                            right: 6,
                            child: Text(
                              _compactRupiah(value),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),

                // ── Bar area ───────────────────────────────────────────────
                Expanded(
                  child: CustomPaint(
                    painter: _BarPainter(
                      platforms: platforms,
                      maxBalance: maxBalance,
                      gridCount: _gridCount,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── X-axis labels ────────────────────────────────────────────────
          Row(
            children: [
              SizedBox(width: _yAxisWidth),
              ...platforms.map((p) => Expanded(
                    child: Text(
                      _shortName(p.name),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    if (name == 'Uang Cash') return 'Cash';
    if (name.startsWith('Bank ')) return name.substring(5);
    return name;
  }

  /// Compact format: 1.500.000 → "1,5Jt", 250.000 → "250Rb", 0 → "0"
  String _compactRupiah(double value) {
    if (value <= 0) return '0';
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}Jt';
    }
    if (value >= 1000) {
      final v = value / 1000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}Rb';
    }
    return value.toInt().toString();
  }
}

class _BarPainter extends CustomPainter {
  final List<AssetPlatform> platforms;
  final double maxBalance;
  final int gridCount;

  _BarPainter({
    required this.platforms,
    required this.maxBalance,
    required this.gridCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxBalance <= 0) return;

    // Semi-transparent horizontal gridlines
    final gridPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    for (int i = 0; i <= gridCount; i++) {
      final y = size.height * i / gridCount;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Bars
    final count = platforms.length;
    final barWidth = (size.width / count) * 0.55;
    final slot = size.width / count;

    for (int i = 0; i < count; i++) {
      final p = platforms[i];
      final barHeight = (p.balance / maxBalance) * size.height * 0.92;
      final left = slot * i + (slot - barWidth) / 2;
      final top = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(5),
        ),
        Paint()..color = Color(p.colorValue),
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.platforms != platforms ||
      old.maxBalance != maxBalance ||
      old.gridCount != gridCount;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
