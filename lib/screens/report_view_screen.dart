import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class ReportViewScreen extends StatefulWidget {
  final String reportType;
  final String timePeriod;

  const ReportViewScreen({
    super.key,
    required this.reportType,
    required this.timePeriod,
  });

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportData = [];
  Map<String, dynamic> _summaryData = {};
  String _summary = '';
  final DateTime _generatedTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    
    try {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        // Try parsing different date formats
        try {
          // Parse format like "June 12, 2025 at 8:15:58PM UTC+8"
          final parts = dateValue.split(' at ');
          if (parts.length == 2) {
            final datePart = parts[0]; // "June 12, 2025"
            final timePart = parts[1].split(' ')[0]; // "8:15:58PM"
            final dateTimeStr = '$datePart $timePart';
            return DateFormat('MMMM d, yyyy hha').parse(dateTimeStr);
          }
        } catch (e) {
          // Error parsing date string format 1
        }

        // Try other date formats if the first one fails
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          // Error parsing date string format 2
        }
      } else if (dateValue is DateTime) {
        return dateValue;
      }
    } catch (e) {
      // Error parsing date
    }
    return null;
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      // Calculate date range based on selected period
      DateTime endDate = DateTime.now();
      DateTime startDate;
      switch (widget.timePeriod) {
        case 'Last 7 Days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case 'Last 14 Days':
          startDate = endDate.subtract(const Duration(days: 14));
          break;
        case 'Last 30 Days':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 7));
      }



      // Initialize summary data
      _summaryData = {
        'totalJobs': 0,
        'activeJobs': 0,
        'totalApplications': 0,
        'totalUsers': 0,
        'employers': 0,
        'jobSeekers': 0,
      };

      // First get all applications to get job IDs and their dates
      final applicationsSnapshot = await FirebaseFirestore.instance
          .collection('jobApplications')
          .get();



      // Create a map of job IDs and their first application date
      final jobDates = <String, DateTime>{};
      final Set<String> jobIds = {};

      for (var doc in applicationsSnapshot.docs) {
        try {
          final data = doc.data();
          final jobId = data['jobId']?.toString();
          if (jobId != null) {
            jobIds.add(jobId);
            final appliedAt = _parseDate(data['appliedAt']);
            if (appliedAt != null) {
              if (!jobDates.containsKey(jobId) || appliedAt.isBefore(jobDates[jobId]!)) {
                jobDates[jobId] = appliedAt;
              }
            }
          }
        } catch (e) {
          // Error processing application
        }
      }

      // Now fetch jobs using the collected job IDs
      if (jobIds.isNotEmpty) {
        final jobsSnapshot = await FirebaseFirestore.instance
            .collection('jobs')
            .where(FieldPath.documentId, whereIn: jobIds.toList())
            .get();



        // Filter jobs based on application dates
        final filteredJobs = jobsSnapshot.docs.where((doc) {
          try {
            final jobId = doc.id;
            final jobDate = jobDates[jobId];
            if (jobDate == null) return false;
            
            return jobDate.isAfter(startDate) && jobDate.isBefore(endDate);
          } catch (e) {
            // Error processing job
            return false;
          }
        }).toList();

        _summaryData['totalJobs'] = filteredJobs.length;
        _summaryData['activeJobs'] = filteredJobs.where((doc) {
          try {
            final data = doc.data();
            final status = data['status']?.toString().toLowerCase() ?? '';
            return status == 'active' || status == 'open';
          } catch (e) {
            // Error checking job status
            return false;
          }
        }).length;
      }

      // Filter applications based on date
      final filteredApplications = applicationsSnapshot.docs.where((doc) {
        try {
          final data = doc.data();
          final appliedAt = _parseDate(data['appliedAt']);

          if (appliedAt == null) return false;
          return appliedAt.isAfter(startDate) && appliedAt.isBefore(endDate);
        } catch (e) {
          // Error processing application
          return false;
        }
      }).toList();

      _summaryData['totalApplications'] = filteredApplications.length;

      // Fetch users data
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();



      for (var doc in usersSnapshot.docs) {
        try {
          final data = doc.data();
          _summaryData['totalUsers'] = (_summaryData['totalUsers'] ?? 0) + 1;
          
          // Check email domain for role if role field is empty
          final email = data['email']?.toString().toLowerCase() ?? '';
          final role = data['role']?.toString().toLowerCase() ?? '';
          
          // If role is empty, try to determine from email or other fields
          if (role.isEmpty) {
            if (email.contains('@employer') || data['companyName'] != null) {
              _summaryData['employers'] = (_summaryData['employers'] ?? 0) + 1;
            } else {
              _summaryData['jobSeekers'] = (_summaryData['jobSeekers'] ?? 0) + 1;
            }
          } else {
            if (role == 'employer') {
              _summaryData['employers'] = (_summaryData['employers'] ?? 0) + 1;
            } else {
              _summaryData['jobSeekers'] = (_summaryData['jobSeekers'] ?? 0) + 1;
            }
          }
        } catch (e) {
          // Error processing user
        }
      }

      // Convert summary data to report format
      _reportData = [
        {
          'Metric': 'Total Jobs Posted',
          'Value': _summaryData['totalJobs'],
          'Period': widget.timePeriod
        },
        {
          'Metric': 'Active Jobs',
          'Value': _summaryData['activeJobs'],
          'Period': widget.timePeriod
        },
        {
          'Metric': 'Total Applications',
          'Value': _summaryData['totalApplications'],
          'Period': widget.timePeriod
        },
        {
          'Metric': 'Total Users',
          'Value': _summaryData['totalUsers'],
          'Period': widget.timePeriod
        },
        {
          'Metric': 'Employers',
          'Value': _summaryData['employers'],
          'Period': widget.timePeriod
        },
        {
          'Metric': 'Job Seekers',
          'Value': _summaryData['jobSeekers'],
          'Period': widget.timePeriod
        },
      ];

      _summary = 'This report shows analytics data for ${widget.timePeriod.toLowerCase()}. ' 
                 'Total of ${_summaryData['totalJobs']} jobs posted with ${_summaryData['activeJobs']} active jobs. '
                 'Received ${_summaryData['totalApplications']} applications. '
                 'Platform has ${_summaryData['totalUsers']} users (${_summaryData['employers']} employers, ${_summaryData['jobSeekers']} job seekers).';

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _summary = 'Error generating report: $e';
      });
    }
  }

  Future<void> _generatePDF() async {
    try {
      final doc = pw.Document();
      
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Title
                  pw.Text(
                    widget.reportType,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated on ${DateFormat('dd MMM yyyy, HH:mm').format(_generatedTime)}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Summary
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(_summary),
                  ),
                  pw.SizedBox(height: 20),

                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      // Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Metric',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Value',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Period',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      // Data rows
                      ..._reportData.map((data) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(data['Metric'].toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(data['Value'].toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(data['Period'].toString()),
                          ),
                        ],
                      )).toList(),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save PDF to temporary directory
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await doc.save());

      if (!mounted) return;

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Analytics Report',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'View Report',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.normal,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.reportType,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3F51B5),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(_generatedTime),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Color(0xFF3F51B5),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3F51B5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _summary,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Report Data
                        if (_reportData.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No data available for the selected period',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try selecting a different time period or check back later',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Table(
                              border: TableBorder.all(
                                color: Colors.grey[300]!,
                                width: 0.5,
                              ),
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                // Header row
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                  ),
                                  children: ['Metric', 'Value', 'Period'].map((header) {
                                    return TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          header,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3F51B5),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                // Data rows
                                ..._reportData.map((data) {
                                  return TableRow(
                                    children: ['Metric', 'Value', 'Period'].map((key) {
                                      return TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                            data[key].toString(),
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: ElevatedButton.icon(
          onPressed: _generatePDF,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text(
            'Export as PDF',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3F51B5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
} 