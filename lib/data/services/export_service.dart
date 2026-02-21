import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/fixed_charge_model.dart';
import '../../core/utils.dart'; // Ensure utils has formatCurrency

class ExportService {
  
  // --- HELPER: Save File ---
  static Future<File> _saveFile(BuildContext context, String filename, List<int> bytes) async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Try to save to actual "Download" folder
      directory = Directory('/storage/emulated/0/Download');
      // If it doesn't exist (emulator?), fallback
      if (!await directory.exists()) {
         directory = await getExternalStorageDirectory(); 
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final path = "${directory?.path ?? ''}/$filename";
    final file = File(path);
    await file.writeAsBytes(bytes);
    
    // Notify User
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File saved to: $path'), duration: const Duration(seconds: 3)),
    );
    
    return file;
  }

  // --- PDF EXPORT ---
  static Future<void> exportToPdf(
    BuildContext context,
    int year,
    int month,
    List<ExpenseModel> expenses,
    double startingBalance,
    double totalIncome,
    double totalSpent,
    double currentBalance,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Monthly Expense Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(monthName, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Summary Table
          pw.Text("Summary", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Starting Balance', Utils.formatCurrency(startingBalance)],
              ['Income', Utils.formatCurrency(totalIncome)],
              ['Spent', Utils.formatCurrency(totalSpent)],
              ['Ending Balance', Utils.formatCurrency(currentBalance)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),

          // Expenses List
          pw.Text("Transactions", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Type', 'Amount'],
            data: (List<ExpenseModel>.from(expenses)..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)))).map((e) => [
              DateFormat('dd MMM').format(DateTime.parse(e.date)),
              e.category,
              e.description,
              e.type.toUpperCase(),
              Utils.formatCurrency(e.amount),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FixedColumnWidth(50),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(70),
            },
            cellAlignments: {4: pw.Alignment.centerRight},
          ),
        ],
      ),
    );

    // Save & Share
    final bytes = await pdf.save();
    final filename = 'report_${year}_$month.pdf';
    final file = await _saveFile(context, filename, bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Monthly Expense Report');
  }

  // --- EXCEL EXPORT ---
  static Future<void> exportToExcel(
    BuildContext context,
    int year,
    int month,
    List<ExpenseModel> expenses,
    double startingBalance,
    double totalIncome,
    double totalSpent,
    double currentBalance,
  ) async {
    var excel = Excel.createExcel();
    
    // Sheet 1: Summary
    String summarySheet = 'Summary';
    Sheet sSheet = excel[summarySheet];
    
    sSheet.appendRow([TextCellValue('Metric'), TextCellValue('Amount')]);
    sSheet.appendRow([TextCellValue('Starting Balance'), DoubleCellValue(startingBalance)]);
    sSheet.appendRow([TextCellValue('Income'), DoubleCellValue(totalIncome)]);
    sSheet.appendRow([TextCellValue('Spent'), DoubleCellValue(totalSpent)]);
    sSheet.appendRow([TextCellValue('Ending Balance'), DoubleCellValue(currentBalance)]);
    
    // Sheet 2: Transactions
    String sheetName = 'Transactions';
    Sheet sheet = excel[sheetName];
    excel.delete('Sheet1'); // Remove default
    
    // Headers
    sheet.appendRow([
      TextCellValue('Date'), 
      TextCellValue('Category'), 
      TextCellValue('Description'), 
      TextCellValue('Type'), 
      TextCellValue('Amount'), 
      TextCellValue('Loanee/Event')
    ]);
    
    for (var e in (List<ExpenseModel>.from(expenses)..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date))))) {
      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(DateTime.parse(e.date))),
        TextCellValue(e.category),
        TextCellValue(e.description),
        TextCellValue(e.type),
        DoubleCellValue(e.amount),
        TextCellValue(e.loanee ?? e.eventId ?? ''),
      ]);
    }
    
    // Save & Share
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final filename = "report_${year}_$month.xlsx";
    final file = await _saveFile(context, filename, fileBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Monthly Expense Report');
  }

  // --- ADVANCED PDF EXPORT ---
  static Future<void> exportToPdfAdvanced(
    BuildContext context,
    int year,
    int month,
    List<ExpenseModel> expenses,
    double startingBalance,
    double totalIncome,
    double totalSpent,
    double currentBalance,
    Map<String, double> categoryBreakdown,
    List<Map<String, dynamic>> activeLoans,
    List<Map<String, dynamic>> activeBorrows,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

    // Calculate total categorized spending for percentages
    final totalCategorized = categoryBreakdown.values.fold(0.0, (sum, val) => sum + val);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Advanced Monthly Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(monthName, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Summary Table
          pw.Text("Financial Summary", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Starting Balance', Utils.formatCurrency(startingBalance)],
              ['Income', Utils.formatCurrency(totalIncome)],
              ['Spent', Utils.formatCurrency(totalSpent)],
              ['Ending Balance', Utils.formatCurrency(currentBalance)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),

          // Category Breakdown
          pw.Text("Spending by Category", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
             headers: ['Category', 'Amount', '% of Total'],
             data: (categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) {
                final percentage = totalCategorized > 0 ? (e.value / totalCategorized) * 100 : 0.0;
                return [
                  e.key,
                  Utils.formatCurrency(e.value),
                  '${percentage.toStringAsFixed(1)}%'
                ];
             }).toList(),
             headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
             headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
             cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),

          // Active Loans
          if (activeLoans.isNotEmpty) ...[
            pw.Text("Active Lendings (Money owed to you)", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
               headers: ['Person', 'Total Loaned', 'Remaining'],
               data: activeLoans.map((l) => [
                 l['name'],
                 Utils.formatCurrency(l['totalAmount']),
                 Utils.formatCurrency(l['remaining']),
               ]).toList(),
               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
               headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
               cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 20),
          ],

          // Active Borrows
          if (activeBorrows.isNotEmpty) ...[
            pw.Text("Active Debts (Money you owe)", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
               headers: ['Person', 'Total Borrowed', 'Remaining'],
               data: activeBorrows.map((b) => [
                 b['name'],
                 Utils.formatCurrency(b['totalAmount']),
                 Utils.formatCurrency(b['remaining']),
               ]).toList(),
               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
               headerDecoration: const pw.BoxDecoration(color: PdfColors.deepOrange800),
               cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 20),
          ],
          
          // Transactions List (New Page suggested implicitly if it overflows)
          pw.Text("All Transactions ($monthName)", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Type', 'Amount'],
            data: (List<ExpenseModel>.from(expenses)..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)))).map((e) => [
              DateFormat('dd MMM').format(DateTime.parse(e.date)),
              e.category,
              e.description,
              e.type.toUpperCase(),
              Utils.formatCurrency(e.amount),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FixedColumnWidth(50),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(70),
            },
            cellAlignments: {4: pw.Alignment.centerRight},
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'advanced_report_${year}_$month.pdf';
    final file = await _saveFile(context, filename, bytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Advanced Monthly Report');
  }

  // --- ADVANCED EXCEL EXPORT ---
  static Future<void> exportToExcelAdvanced(
    BuildContext context,
    int year,
    int month,
    List<ExpenseModel> expenses,
    double startingBalance,
    double totalIncome,
    double totalSpent,
    double currentBalance,
    Map<String, double> categoryBreakdown,
    List<Map<String, dynamic>> activeLoans,
    List<Map<String, dynamic>> activeBorrows,
  ) async {
    var excel = Excel.createExcel();
    
    // Sheet 1: Summary & Categories
    String summarySheet = 'Summary';
    Sheet sSheet = excel[summarySheet];
    
    sSheet.appendRow([TextCellValue('Metric'), TextCellValue('Amount')]);
    sSheet.appendRow([TextCellValue('Starting Balance'), DoubleCellValue(startingBalance)]);
    sSheet.appendRow([TextCellValue('Income'), DoubleCellValue(totalIncome)]);
    sSheet.appendRow([TextCellValue('Spent'), DoubleCellValue(totalSpent)]);
    sSheet.appendRow([TextCellValue('Ending Balance'), DoubleCellValue(currentBalance)]);
    sSheet.appendRow([TextCellValue('')]); // Blank row
    
    sSheet.appendRow([TextCellValue('Category Breakdown')]);
    sSheet.appendRow([TextCellValue('Category'), TextCellValue('Amount')]);
    
    final sortedCategories = categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedCategories) {
       sSheet.appendRow([TextCellValue(entry.key), DoubleCellValue(entry.value)]);
    }
    
    // Sheet 2: Loans & Borrows
    String debtsSheet = 'Loans & Debts';
    Sheet dSheet = excel[debtsSheet];
    excel.delete('Sheet1'); // Remove default
    
    dSheet.appendRow([TextCellValue('Active Lendings (Owed to you)')]);
    dSheet.appendRow([TextCellValue('Person'), TextCellValue('Total Loaned'), TextCellValue('Remaining')]);
    for (var l in activeLoans) {
      dSheet.appendRow([TextCellValue(l['name'].toString()), DoubleCellValue(l['totalAmount']), DoubleCellValue(l['remaining'])]);
    }
    
    dSheet.appendRow([TextCellValue('')]); // Blank row
    
    dSheet.appendRow([TextCellValue('Active Debts (You owe)')]);
    dSheet.appendRow([TextCellValue('Person'), TextCellValue('Total Borrowed'), TextCellValue('Remaining')]);
    for (var b in activeBorrows) {
      dSheet.appendRow([TextCellValue(b['name'].toString()), DoubleCellValue(b['totalAmount']), DoubleCellValue(b['remaining'])]);
    }
    
    // Sheet 3: Transactions
    String sheetName = 'Transactions';
    Sheet tSheet = excel[sheetName];
    
    tSheet.appendRow([
      TextCellValue('Date'), 
      TextCellValue('Category'), 
      TextCellValue('Description'), 
      TextCellValue('Type'), 
      TextCellValue('Amount'), 
      TextCellValue('Loanee/Event')
    ]);
    
    for (var e in (List<ExpenseModel>.from(expenses)..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date))))) {
      tSheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(DateTime.parse(e.date))),
        TextCellValue(e.category),
        TextCellValue(e.description),
        TextCellValue(e.type),
        DoubleCellValue(e.amount),
        TextCellValue(e.loanee ?? e.eventId ?? ''),
      ]);
    }
    
    // Save & Share
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final filename = "advanced_report_${year}_$month.xlsx";
    final file = await _saveFile(context, filename, fileBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Advanced Monthly Report');
  }
}
