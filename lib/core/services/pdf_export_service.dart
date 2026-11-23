import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/models/transaction_model.dart';

enum ExportPeriodType {
  daily,
  weekly,
  monthly,
  yearly,
}

/// ============================================================================
/// PdfExportService
/// ============================================================================
/// Layanan ekspor dokumen finansial PDF dengan tema kustom:
/// **Monochromatic Thermal Receipt Printer Style (Ala Struk Kasir / Struk Print).**
///
/// Fitur teknis:
/// - Menggunakan font monospaced kustom (Courier style).
/// - Layout struk memanjang dengan garis pembatas putus-putus (*dashed line*).
/// - Menghitung rekapitulasi ringkasan (Pemasukan, Pengeluaran, Transfer, Saldo Bersih).
/// - Terintegrasi dengan native Android/iOS print spooler (`Printing.layoutPdf`)
///   dan native document sharing intent (`Printing.sharePdf`).
class PdfExportService {
  PdfExportService._internal();
  static final PdfExportService instance = PdfExportService._internal();

  /// Format angka ke representasi rupiah tanpa simbol (misal: 150.000)
  String formatNumber(double amount) {
    final intPart = amount.toInt().abs().toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  String formatRupiah(double amount) {
    final sign = amount < 0 ? '-' : '';
    return '${sign}Rp ${formatNumber(amount)}';
  }

  /// Generate dokumen PDF bertema struk monokrom printer thermal untuk Cashifly
  Future<Uint8List> generateReceiptPdf({
    required String periodLabel,
    required String dateRangeDisplay,
    required List<TransactionModel> transactions,
    required Map<int, String> platformNames,
    String? userEmail,
  }) async {
    final pdf = pw.Document();

    final fontBase = pw.Font.courier();
    final fontBold = pw.Font.courierBold();
    final fontItalic = pw.Font.courierOblique();

    // Hitung total ringkasan
    double totalIncome = 0;
    double totalExpense = 0;
    double totalTransfer = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        totalExpense += tx.amount;
      } else if (tx.type == TransactionType.transfer) {
        totalTransfer += tx.amount;
      }
    }

    final netFlow = totalIncome - totalExpense;

    final now = DateTime.now();
    final printTimeStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final receiptNo =
        'CSF-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

    final email = userEmail ??
        FirebaseAuth.instance.currentUser?.email ??
        'User Cashifly';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: fontBase,
          bold: fontBold,
          italic: fontItalic,
        ),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.8,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CASHIFLY - LAPORAN KEUANGAN',
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(
                    'Hal ${context.pageNumber} dari ${context.pagesCount}',
                    style: pw.TextStyle(font: fontBase, fontSize: 10),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        build: (context) {
          return [
            pw.Center(
              child: pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(maxWidth: 480),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Struk ──────────────────────────────────────────
                    _buildDoubleLine(),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Text(
                        'CASHIFLY',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Center(
                      child: pw.Text(
                        'SMART PERSONAL FINANCIAL TRACKER',
                        style: pw.TextStyle(
                          font: fontBase,
                          fontSize: 8.5,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        '*** LAPORAN RIWAYAT KEUANGAN ***',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    _buildDoubleLine(),
                    pw.SizedBox(height: 10),

                    // ── Metadata Struk ─────────────────────────────────────────
                    _buildKeyValueRow('No. Struk', receiptNo, fontBase, fontBold),
                    _buildKeyValueRow('Waktu Cetak', printTimeStr, fontBase, fontBase),
                    _buildKeyValueRow('Akun Pengguna', email, fontBase, fontBase),
                    _buildKeyValueRow('Periode', '$periodLabel ($dateRangeDisplay)', fontBase, fontBold),
                    _buildKeyValueRow('Total Item', '${transactions.length} Transaksi', fontBase, fontBase),
                    pw.SizedBox(height: 8),

                    _buildDashedLine(),
                    pw.SizedBox(height: 6),

                    // ── Header Kolom Transaksi ─────────────────────────────────
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 80,
                          child: pw.Text(
                            'TGL/WAKTU',
                            style: pw.TextStyle(font: fontBold, fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'KETERANGAN / PLATFORM',
                            style: pw.TextStyle(font: fontBold, fontSize: 9),
                          ),
                        ),
                        pw.SizedBox(
                          width: 110,
                          child: pw.Text(
                            'NOMINAL (RP)',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(font: fontBold, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    _buildDashedLine(),
                    pw.SizedBox(height: 8),

                    // ── Baris Transaksi ────────────────────────────────────────
                    if (transactions.isEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 20),
                        child: pw.Center(
                          child: pw.Text(
                            '- TIDAK ADA TRANSAKSI PADA PERIODE INI -',
                            style: pw.TextStyle(font: fontItalic, fontSize: 10),
                          ),
                        ),
                      )
                    else
                      ...transactions.map((tx) {
                        return _buildTransactionItem(
                          tx: tx,
                          platformNames: platformNames,
                          fontBase: fontBase,
                          fontBold: fontBold,
                          fontItalic: fontItalic,
                        );
                      }),

                    pw.SizedBox(height: 8),
                    _buildDashedLine(),
                    pw.SizedBox(height: 8),

                    // ── Ringkasan (Summary) ────────────────────────────────────
                    pw.Text(
                      'RINGKASAN ARUS KEUANGAN:',
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 6),
                    _buildSummaryRow(
                      'Total Pemasukan (+)',
                      '+Rp ${formatNumber(totalIncome)}',
                      fontBase,
                      fontBold,
                    ),
                    _buildSummaryRow(
                      'Total Pengeluaran (-)',
                      '-Rp ${formatNumber(totalExpense)}',
                      fontBase,
                      fontBold,
                    ),
                    _buildSummaryRow(
                      'Total Pindah Saldo [⇄]',
                      ' Rp ${formatNumber(totalTransfer)}',
                      fontBase,
                      fontBase,
                    ),
                    pw.SizedBox(height: 8),
                    _buildDoubleLine(),
                    pw.SizedBox(height: 8),

                    // Arus Bersih (Net)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'ARUS BERSIH (NETTO)',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                        ),
                        pw.Text(
                          '${netFlow >= 0 ? '+' : '-'}Rp ${formatNumber(netFlow.abs())}',
                          style: pw.TextStyle(font: fontBold, fontSize: 13),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    _buildDoubleLine(),
                    pw.SizedBox(height: 18),

                    // ── Footer Struk ──────────────────────────────────────────
                    pw.Center(
                      child: pw.Text(
                        'TERIMA KASIH TELAH MENGGUNAKAN CASHIFLY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Center(
                      child: pw.Text(
                        'Kelola Saldo & Catat Pengeluaran dengan Tepat',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: fontBase, fontSize: 8.5),
                      ),
                    ),
                    pw.SizedBox(height: 12),

                    // Barcode Ala Struk Cetak
                    pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: receiptNo,
                        width: 220,
                        height: 38,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Center(
                      child: pw.Text(
                        '* $receiptNo *',
                        style: pw.TextStyle(font: fontBase, fontSize: 8),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        '=== SIMPAN STRUK INI SEBAGAI ARSIP KEUANGAN ANDA ===',
                        style: pw.TextStyle(font: fontItalic, fontSize: 7.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Sub-widget Helpers ───────────────────────────────────────────────────────

  pw.Widget _buildDoubleLine() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.black, thickness: 1.2),
        pw.SizedBox(height: 1.5),
        pw.Divider(color: PdfColors.black, thickness: 0.6),
      ],
    );
  }

  pw.Widget _buildDashedLine() {
    return pw.Divider(
      color: PdfColors.black,
      thickness: 0.8,
      borderStyle: pw.BorderStyle.dashed,
    );
  }

  pw.Widget _buildKeyValueRow(
    String key,
    String val,
    pw.Font fontKey,
    pw.Font fontVal,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              key.padRight(14, ' '),
              style: pw.TextStyle(font: fontKey, fontSize: 9),
            ),
          ),
          pw.Text(': ', style: pw.TextStyle(font: fontKey, fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              val,
              style: pw.TextStyle(font: fontVal, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String amountStr,
    pw.Font fontLabel,
    pw.Font fontAmount,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: fontLabel, fontSize: 9.5),
          ),
          pw.Text(
            amountStr,
            style: pw.TextStyle(font: fontAmount, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTransactionItem({
    required TransactionModel tx,
    required Map<int, String> platformNames,
    required pw.Font fontBase,
    required pw.Font fontBold,
    required pw.Font fontItalic,
  }) {
    final isIncome = tx.type == TransactionType.income;
    final isTransfer = tx.type == TransactionType.transfer;

    final sign = isTransfer ? '[⇄]' : (isIncome ? '(+)' : '(-)');

    // Format tanggal ringkas (DD/MM)
    String dateBrief = tx.date;
    try {
      final d = DateTime.parse(tx.date);
      dateBrief = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } catch (_) {}

    final timeStr = tx.time.isNotEmpty ? tx.time.replaceAll(':', '.') : '';
    final dateTimeDisplay = timeStr.isNotEmpty ? '$dateBrief $timeStr' : dateBrief;

    // Nama platform
    String platformInfo = '';
    if (isTransfer) {
      final fromP = platformNames[tx.platformId] ?? 'Sumber';
      final toP = platformNames[tx.toPlatformId] ?? 'Tujuan';
      platformInfo = '$fromP -> $toP';
    } else {
      platformInfo = platformNames[tx.platformId] ?? 'Platform';
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Tanggal & Waktu
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              dateTimeDisplay,
              style: pw.TextStyle(font: fontBase, fontSize: 8.5),
            ),
          ),

          // Keterangan & Platform
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  tx.category,
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                ),
                pw.Text(
                  '[$platformInfo]',
                  style: pw.TextStyle(font: fontItalic, fontSize: 8),
                ),
                if (tx.note != null &&
                    tx.note!.isNotEmpty &&
                    !tx.note!.startsWith('Dari '))
                  pw.Text(
                    'Cat: ${tx.note}',
                    style: pw.TextStyle(font: fontBase, fontSize: 8),
                  ),
              ],
            ),
          ),

          // Nominal
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '${formatNumber(tx.amount)} $sign',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: fontBold, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// Buka dialog print bawaan sistem (Android/iOS)
  Future<void> printReceipt({
    required String periodLabel,
    required String dateRangeDisplay,
    required List<TransactionModel> transactions,
    required Map<int, String> platformNames,
  }) async {
    final bytes = await generateReceiptPdf(
      periodLabel: periodLabel,
      dateRangeDisplay: dateRangeDisplay,
      transactions: transactions,
      platformNames: platformNames,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Struk_Cashifly_${periodLabel.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Bagikan file PDF (Share Sheet)
  Future<void> shareReceipt({
    required String periodLabel,
    required String dateRangeDisplay,
    required List<TransactionModel> transactions,
    required Map<int, String> platformNames,
  }) async {
    final bytes = await generateReceiptPdf(
      periodLabel: periodLabel,
      dateRangeDisplay: dateRangeDisplay,
      transactions: transactions,
      platformNames: platformNames,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Struk_Cashifly_${periodLabel.replaceAll(' ', '_')}.pdf',
    );
  }
}
