import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../data/models/models.dart';

class PdfService {
  static Future<String> generateInspectionReport(InspectionModel inspection, List<PhotoModel> photos, {bool isHindi = true}) async {
    final pdf = pw.Document();

    // Load Devanagari font for Hindi text
    final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final devanagariFont = pw.Font.ttf(fontData);

    // Default font for English/Fallback
    final defaultFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final theme = pw.ThemeData.withFont(
      base: devanagariFont, // Set base to Devanagari to handle Hindi automatically
      bold: devanagariFont,
    );

    // Fetch images asynchronously
    final imageProviders = <pw.MemoryImage>[];
    for (final photo in photos) {
      if (photo.filePath.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(photo.filePath));
          if (response.statusCode == 200) {
            imageProviders.add(pw.MemoryImage(response.bodyBytes));
          }
        } catch (e) {
          print('Error loading image: $e');
        }
      }
    }


    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1E88E5), // Blue header
          ),
          child: pw.Text(
            isHindi ? 'निरीक्षण रिपोर्ट' : 'INSPECTION REPORT',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.Text(
            isHindi ? 'विस्तृत निरीक्षण रिपोर्ट' : 'Detailed Inspection Report',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
          ),
          pw.SizedBox(height: 10),
          
          // Metadata Table
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(6),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            headers: [isHindi ? 'विवरण' : 'Detail', isHindi ? 'जानकारी' : 'Information'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 11),
            data: [
              [isHindi ? 'निरीक्षण आईडी' : 'Inspection ID', inspection.id.substring(0, 8).toUpperCase()],
              [isHindi ? 'दिनांक' : 'Date', DateFormat('dd/MM/yyyy').format(inspection.inspectionDate ?? DateTime.now())],
              [isHindi ? 'योजना का नाम' : 'Project Name', inspection.projectName ?? 'N/A'],
              [isHindi ? 'निरीक्षणकर्ता' : 'Investigator', inspection.investigatorName ?? 'N/A'],
              [isHindi ? 'ग्राम पंचायत' : 'Panchayat', inspection.panchayatId], // Ideally should pass panchayat name
              [isHindi ? 'स्थिति' : 'Status', inspection.status.toUpperCase()],
            ],
          ),
          pw.SizedBox(height: 20),

          // Content from AI or Fallback
          pw.Text(
            isHindi ? 'टिप्पणी एवं निष्कर्ष:' : 'Observations & Conclusions:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            inspection.aiReportDraft?.isNotEmpty == true 
                ? inspection.aiReportDraft! 
                : (inspection.observations ?? (isHindi ? 'निरीक्षण किया गया।' : 'Inspection conducted.')),
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 30),

          // Photos Section
          if (imageProviders.isNotEmpty) ...[
            pw.Text(
              isHindi ? 'निरीक्षण स्थल की तस्वीरें:' : 'Inspection Site Photographs:',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: imageProviders.map((img) {
                return pw.Container(
                  width: 230,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(img, height: 150, fit: pw.BoxFit.cover),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        isHindi ? 'स्थल की तस्वीर' : 'Site Photograph',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          
          pw.SizedBox(height: 50), // Space before signatures

          // Signatures Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Witness Signature
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isHindi ? 'गवाह (Witness)' : 'Witness',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    isHindi ? 'हस्ताक्षर: ____________________' : 'Signature: ____________________',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    isHindi ? 'नाम: _______________________' : 'Name: _______________________',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              // Inspector Signature
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    isHindi ? 'निरीक्षणकर्ता (Inspector)' : 'Inspector',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                    isHindi ? 'हस्ताक्षर: ____________________' : 'Signature: ____________________',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    isHindi ? 'नाम: ${inspection.investigatorName ?? '_______________________'}' : 'Name: ${inspection.investigatorName ?? '_______________________'}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    isHindi ? 'पद: ________________________' : 'Designation: __________________',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Save and Return PDF Path
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Inspection_Report_${inspection.id.substring(0, 8)}.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
