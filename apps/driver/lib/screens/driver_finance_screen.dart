import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_earnings_hub_body.dart';
import '../widgets/driver_money_flow_common.dart';

class DriverFinanceScreen extends ConsumerStatefulWidget {
  const DriverFinanceScreen({super.key});

  @override
  ConsumerState<DriverFinanceScreen> createState() =>
      _DriverFinanceScreenState();
}

class _DriverFinanceScreenState extends ConsumerState<DriverFinanceScreen> {
  static const _accountantEmailKey = 'driver_finance_accountant_email';
  static const _mailtoMaxUriLength = 1800;

  DriverFinanceDateFilter _dateFilter = DriverFinanceDateFilter.thisMonth;
  DateTimeRange? _customDateRange;
  String? _accountantEmail;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAccountantEmail();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final range = _selectedRange();
    final metricsAsync = ref.watch(driverFinanceMetricsProvider(range));
    final ledgerAsync = ref.watch(driverPaymentLedgerProvider);

    final metrics = metricsAsync.valueOrNull ?? const DriverFinanceMetrics();
    final ledger = ledgerAsync.valueOrNull ?? const [];

    return DriverEarningsHubBody(
      colors: colors,
      typography: typography,
      selectedFilter: _dateFilter,
      rangeLabel: _rangeLabelNl(),
      metrics: metrics,
      metricsLoading: metricsAsync.isLoading,
      metricsError: metricsAsync.hasError,
      ledgerItems: ledger,
      ledgerLoading: ledgerAsync.isLoading,
      accountantEmail: _accountantEmail,
      exporting: _exporting,
      onBack: () => context.pop(),
      onFilterSelected: _onFilterSelected,
      onExport: () => _showExportOptions(context, colors, typography),
      onViewAllRides: () => context.push('/driver/rides/today'),
      onEditAccountantEmail: _promptAccountantEmail,
    );
  }

  Future<void> _onFilterSelected(DriverFinanceDateFilter filter) async {
    if (filter == DriverFinanceDateFilter.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        setState(() {
          _dateFilter = filter;
          _customDateRange = picked;
        });
      }
    } else {
      setState(() {
        _dateFilter = filter;
        _customDateRange = null;
      });
    }
  }

  DriverFinanceRange _selectedRange() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfNow = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
      999,
    );
    switch (_dateFilter) {
      case DriverFinanceDateFilter.today:
        return DriverFinanceRange(start: startOfToday, end: endOfNow);
      case DriverFinanceDateFilter.thisWeek:
        final monday =
            startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
        return DriverFinanceRange(start: monday, end: endOfNow);
      case DriverFinanceDateFilter.thisMonth:
        return DriverFinanceRange(
            start: DateTime(now.year, now.month, 1), end: endOfNow);
      case DriverFinanceDateFilter.thisQuarter:
        final startMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DriverFinanceRange(
            start: DateTime(now.year, startMonth, 1), end: endOfNow);
      case DriverFinanceDateFilter.thisYear:
        return DriverFinanceRange(
            start: DateTime(now.year, 1, 1), end: endOfNow);
      case DriverFinanceDateFilter.custom:
        final custom = _customDateRange;
        if (custom == null) {
          return DriverFinanceRange(start: startOfToday, end: endOfNow);
        }
        return DriverFinanceRange(
          start:
              DateTime(custom.start.year, custom.start.month, custom.start.day),
          end: DateTime(custom.end.year, custom.end.month, custom.end.day, 23,
              59, 59, 999),
        );
    }
  }

  String _rangeLabelNl() {
    switch (_dateFilter) {
      case DriverFinanceDateFilter.today:
        return DriverStrings.financeRangeToday;
      case DriverFinanceDateFilter.thisWeek:
        return DriverStrings.financeRangeThisWeek;
      case DriverFinanceDateFilter.thisMonth:
        return DriverStrings.financeRangeThisMonth;
      case DriverFinanceDateFilter.thisQuarter:
        return DriverStrings.financeRangeThisQuarter;
      case DriverFinanceDateFilter.thisYear:
        return DriverStrings.financeRangeThisYear;
      case DriverFinanceDateFilter.custom:
        if (_customDateRange == null) return DriverStrings.financeRangeCustom;
        final df = DateFormat('dd-MM-yyyy');
        return '${df.format(_customDateRange!.start)} t/m ${df.format(_customDateRange!.end)}';
    }
  }

  String _formatPeriodBounds(DriverFinanceRange range) {
    final df = DateFormat('dd-MM-yyyy');
    return '${df.format(range.start)} t/m ${df.format(range.end)}';
  }

  String _formatGeneratedAt() =>
      DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

  String _eurNl(double value) => NumberFormat.currency(
        locale: 'nl_NL',
        symbol: '€',
        decimalDigits: 2,
      ).format(value);

  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _loadSavedAccountantEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _accountantEmail = prefs.getString(_accountantEmailKey));
  }

  void _showExportOptions(
    BuildContext context,
    DriverColors colors,
    DriverTypography typography,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverFinanceExportSheet(
        title: DriverStrings.financeExportSheetTitle,
        colors: colors,
        typography: typography,
        children: [
          DriverFinanceExportOption(
            icon: Icons.picture_as_pdf_rounded,
            title: DriverStrings.financeExportPdf,
            subtitle: DriverStrings.financeExportPdfSubtitle,
            colors: colors,
            typography: typography,
            onTap: () {
              Navigator.pop(ctx);
              _generatePDF();
            },
          ),
          const SizedBox(height: 12),
          DriverFinanceExportOption(
            icon: Icons.email_outlined,
            title: DriverStrings.financeExportEmail,
            subtitle: DriverStrings.financeExportEmailSubtitle,
            colors: colors,
            typography: typography,
            onTap: () {
              Navigator.pop(ctx);
              _sendByEmail();
            },
          ),
          const SizedBox(height: 12),
          DriverFinanceExportOption(
            icon: Icons.share_rounded,
            title: DriverStrings.financeExportWhatsapp,
            subtitle: DriverStrings.financeExportWhatsappSubtitle,
            colors: colors,
            typography: typography,
            onTap: () {
              Navigator.pop(ctx);
              _shareViaWhatsApp();
            },
          ),
        ],
      ),
    );
  }

  Future<String> _buildReportText() async {
    final range = _selectedRange();
    DriverFinanceMetrics metrics;
    try {
      metrics = await ref.read(driverFinanceMetricsProvider(range).future);
    } catch (_) {
      metrics = const DriverFinanceMetrics();
    }

    final platform = metrics.platformFees ?? 0;
    final tips = metrics.tips ?? 0;
    final km = NumberFormat.decimalPatternDigits(
      locale: 'nl_NL',
      decimalDigits: 1,
    ).format(metrics.totalKilometers);

    final lines = <String>[
      DriverStrings.financeReportTitle,
      '${DriverStrings.financeReportPeriodHeading}: ${_rangeLabelNl()}',
      '${DriverStrings.financeReportDatesHeading}: ${_formatPeriodBounds(range)}',
      '${DriverStrings.financeReportGenerated}: ${_formatGeneratedAt()}',
      '',
      DriverStrings.financeReportSectionSummary,
      '${DriverStrings.financeReportGross}: ${_eurNl(metrics.grossEarnings)}',
      '${DriverStrings.financeReportNet}: ${_eurNl(metrics.netEarnings)}',
      '${DriverStrings.financeReportTotalRides}: ${metrics.totalRides}',
      '${DriverStrings.financeReportKm}: $km',
      '${DriverStrings.financeReportPlatformFees}: ${_eurNl(platform)}',
      '${DriverStrings.financeReportTips}: ${_eurNl(tips)}',
      '${DriverStrings.financeReportCompleted}: ${metrics.completedRides}',
      '${DriverStrings.financeReportCancelled}: ${metrics.cancelledRides}',
      '${DriverStrings.financeReportCancellationFees}: ${_eurNl(metrics.cancellationFees)}',
      '',
      DriverStrings.financeReportFooter,
    ];
    return lines.join('\n');
  }

  Future<List<int>> _buildFinancePdfBytes() async {
    final report = await _buildReportText();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(DriverStrings.financeReportTitle),
          ),
          pw.Paragraph(text: report),
        ],
      ),
    );
    final bytes = await doc.save();
    if (bytes.isEmpty) {
      throw Exception('Generated PDF was empty');
    }
    return bytes;
  }

  Future<void> _generatePDF() async {
    setState(() => _exporting = true);
    try {
      final bytes = await _buildFinancePdfBytes();
      final file = await _savePdfFile(bytes);
      try {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject:
              '${DriverStrings.financeEmailSubject} — ${_rangeLabelNl()}',
          text:
              '${DriverStrings.financePdfShareCaption} (${_rangeLabelNl()})',
          sharePositionOrigin: _sharePositionOrigin(),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${DriverStrings.financePdfSaved} ${file.path}'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${DriverStrings.financePdfExportError} $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<File> _savePdfFile(List<int> bytes) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${baseDir.path}/finance_reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File(
      '${reportsDir.path}/heycaby_driver_finance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _sendByEmail() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await _buildReportText();
      final recipient = (_accountantEmail ?? '').trim();
      final subject =
          '${DriverStrings.financeEmailSubject} — ${_rangeLabelNl()}';

      final mailtoUri = recipient.isEmpty
          ? Uri(
              scheme: 'mailto',
              queryParameters: {
                'subject': subject,
                'body': report,
              },
            )
          : Uri(
              scheme: 'mailto',
              path: recipient,
              queryParameters: {
                'subject': subject,
                'body': report,
              },
            );

      Future<void> shareReportBySheet(String userHint) async {
        await Share.share(report, subject: subject);
        if (!mounted) return;
        if (recipient.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: recipient));
        }
        if (!mounted) return;
        final tail = recipient.isNotEmpty
            ? '\n${DriverStrings.financeEmailRecipientCopied}'
            : '';
        messenger.showSnackBar(
          SnackBar(content: Text('$userHint$tail')),
        );
      }

      if (mailtoUri.toString().length > _mailtoMaxUriLength) {
        await shareReportBySheet(DriverStrings.financeEmailBodyTooLongHint);
        return;
      }

      final launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        if (!mounted) return;
        if (recipient.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(DriverStrings.financeEmailNoRecipientHint),
            ),
          );
        }
        return;
      }

      await shareReportBySheet(DriverStrings.financeEmailMailtoFailedHint);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text(DriverStrings.financeEmailOpenError)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildFinancePdfBytes();
      final tmp = await getTemporaryDirectory();
      final file = File(
        '${tmp.path}/heycaby_chauffeur_financieel_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final subject =
          '${DriverStrings.financeEmailSubject} — ${_rangeLabelNl()}';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
        text: DriverStrings.financeWhatsappSharePdfCaption,
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${DriverStrings.financeShareError} $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _promptAccountantEmail() async {
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
    final controller = TextEditingController(text: _accountantEmail ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => DriverAccountantEmailDialog(
        colors: colors,
        typography: typography,
        controller: controller,
        onCancel: () => Navigator.pop(ctx),
        onSave: () => Navigator.pop(ctx, controller.text.trim()),
      ),
    );
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_accountantEmailKey);
    } else {
      await prefs.setString(_accountantEmailKey, value);
    }
    if (!mounted) return;
    setState(() => _accountantEmail = value.isEmpty ? null : value);
  }
}
