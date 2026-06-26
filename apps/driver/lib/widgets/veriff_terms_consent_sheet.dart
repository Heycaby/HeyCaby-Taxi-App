import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/driver_legal_urls.dart';
import '../l10n/driver_strings.dart';

/// Shows terms + consent before opening the Veriff session URL. Returns `true` if the user agreed.
Future<bool> showVeriffTermsConsentSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _VeriffTermsSheet(),
  );
  return result == true;
}

class _VeriffTermsSheet extends ConsumerStatefulWidget {
  const _VeriffTermsSheet();

  @override
  ConsumerState<_VeriffTermsSheet> createState() => _VeriffTermsSheetState();
}

class _VeriffTermsSheetState extends ConsumerState<_VeriffTermsSheet> {
  bool _agreed = false;
  bool _agreedDataProcessing = false;

  Future<void> _open(String url) async {
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accentL,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: colors.accent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DriverStrings.veriffTermsGateTitle,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                DriverStrings.veriffTermsGateBody,
                style: typo.bodyLarge.copyWith(
                  color: colors.text,
                  height: 1.5,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              _InfoBlock(
                title: DriverStrings.veriffTermsDataControllerTitle,
                body: DriverStrings.veriffTermsDataControllerBody,
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 14),
              _InfoBlock(
                title: 'GDPR and data minimisation',
                body: DriverStrings.veriffTermsDataMinimizationBody,
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 14),
              _InfoBlock(
                title: 'Security and third-party responsibility',
                body: DriverStrings.veriffTermsSecurityLiabilityBody,
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 14),
              _InfoBlock(
                title: 'Legal disclosure',
                body: DriverStrings.veriffTermsLegalDisclosureBody,
                colors: colors,
                typo: typo,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _open(kDriverTermsUrl),
                    icon: Icon(Icons.open_in_new_rounded, size: 18, color: colors.accent),
                    label: Text(
                      DriverStrings.veriffTermsReadFull,
                      style: typo.titleSmall.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _open(kDriverTermsVeriffSectionUrl),
                    icon: Icon(Icons.article_outlined, size: 18, color: colors.textMid),
                    label: Text(
                      DriverStrings.veriffTermsReadVeriffOnly,
                      style: typo.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: colors.accent,
                checkColor: colors.onAccent,
                title: Text(
                  DriverStrings.veriffTermsCheckbox,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    height: 1.45,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _agreedDataProcessing,
                onChanged: (v) => setState(() => _agreedDataProcessing = v ?? false),
                contentPadding: EdgeInsets.zero,
                activeColor: colors.accent,
                checkColor: colors.onAccent,
                title: Text(
                  DriverStrings.veriffTermsCheckboxDataProcessing,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    height: 1.45,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.text,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(DriverStrings.veriffTermsCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !(_agreed && _agreedDataProcessing)
                          ? null
                          : () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                          disabledBackgroundColor: colors.border,
                          disabledForegroundColor: colors.textMid,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      child: Text(
                        DriverStrings.veriffTermsContinue,
                        style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.body,
    required this.colors,
    required this.typo,
  });

  final String title;
  final String body;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              height: 1.5,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
