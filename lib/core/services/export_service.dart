import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:daddies_app/models/session_model.dart';
import 'package:daddies_app/models/cashflow_model.dart';
import 'package:daddies_app/models/user_model.dart';
import 'package:daddies_app/core/services/app_logger.dart';

class ExportService {
  static const _tag = 'ExportService';

  static final _rupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  // ---------------------------------------------------------------------------
  // CSV Exports
  // ---------------------------------------------------------------------------

  static Future<void> exportSessionsCsv(List<SessionModel> sessions) async {
    final rows = <List<dynamic>>[
      ['Judul', 'Venue', 'Tanggal', 'Waktu', 'Maks Pemain', 'Harga', 'Status', 'Mimin'],
      ...sessions.map((s) => [
            s.title,
            s.venue,
            _dateFormat.format(s.date),
            '${s.timeStart}-${s.timeEnd}',
            s.maxPlayers,
            s.pricePerPlayer,
            s.statusLabel,
            s.miminName,
          ]),
    ];

    await _shareCsv(rows, 'sesi_padel');
  }

  static Future<void> exportFinanceCsv(List<CashFlowModel> cashflows) async {
    final rows = <List<dynamic>>[
      ['Tanggal', 'Tipe', 'Kategori', 'Jumlah', 'Deskripsi', 'Dicatat Oleh'],
      ...cashflows.map((c) => [
            _dateFormat.format(c.createdAt),
            c.type == CashFlowType.income ? 'Pemasukan' : 'Pengeluaran',
            c.category,
            c.amount,
            c.description,
            c.recordedBy,
          ]),
    ];

    await _shareCsv(rows, 'laporan_keuangan');
  }

  static Future<void> exportMembersCsv(List<UserModel> members) async {
    final rows = <List<dynamic>>[
      ['Nama', 'Telepon', 'Role', 'Bergabung'],
      ...members.map((m) => [
            m.name,
            m.phone,
            m.roleLabel,
            _dateFormat.format(m.createdAt),
          ]),
    ];

    await _shareCsv(rows, 'daftar_anggota');
  }

  static Future<void> _shareCsv(
      List<List<dynamic>> rows, String filename) async {
    try {
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/${filename}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: filename,
      );
    } catch (e) {
      AppLogger.e(_tag, 'CSV export failed', error: e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // PDF Export
  // ---------------------------------------------------------------------------

  static Future<void> exportFinancePdf({
    required List<CashFlowModel> cashflows,
    required int totalIncome,
    required int totalExpense,
    required int balance,
    String? monthLabel,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Daddies Padel Community',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Laporan Keuangan${monthLabel != null ? ' - $monthLabel' : ''}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                'Dicetak: ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (context) => [
            // Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfSummaryBox('Pemasukan', totalIncome, PdfColors.green700),
                _pdfSummaryBox('Pengeluaran', totalExpense, PdfColors.red700),
                _pdfSummaryBox('Saldo', balance,
                    balance >= 0 ? PdfColors.blue700 : PdfColors.red700),
              ],
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerLeft,
              },
              headers: ['Tanggal', 'Tipe', 'Kategori', 'Jumlah', 'Deskripsi'],
              data: cashflows.map((c) {
                return [
                  _dateFormat.format(c.createdAt),
                  c.type == CashFlowType.income ? 'Masuk' : 'Keluar',
                  c.category,
                  _rupiah.format(c.amount),
                  c.description,
                ];
              }).toList(),
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/laporan_keuangan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Laporan Keuangan Daddies Padel',
      );
    } catch (e) {
      AppLogger.e(_tag, 'PDF export failed', error: e);
      rethrow;
    }
  }

  static pw.Widget _pdfSummaryBox(String label, int amount, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(
            _rupiah.format(amount),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
