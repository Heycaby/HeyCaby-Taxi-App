import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_app_suggestion_body.dart';
import '../widgets/driver_work_flow_common.dart';

class DriverAppSuggestionScreen extends ConsumerStatefulWidget {
  const DriverAppSuggestionScreen({super.key});

  @override
  ConsumerState<DriverAppSuggestionScreen> createState() =>
      _DriverAppSuggestionScreenState();
}

class _DriverAppSuggestionScreenState
    extends ConsumerState<DriverAppSuggestionScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    HapticService.mediumTap();
    final text = _controller.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.appSuggestionTooShort)),
      );
      return;
    }
    final userId = ref.read(driverStateProvider).userId;
    final driverId = await ref.read(driverIdProvider.future);
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    final ok = await ref.read(driverDataServiceProvider).submitAppSuggestion(
          userId: userId,
          driverId: driverId,
          suggestionText: text,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.appSuggestionReceived)),
      );
      _controller.clear();
      ref.invalidate(topDriverAppSuggestionsProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.appSuggestionSendFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final topIdeasAsync = ref.watch(topDriverAppSuggestionsProvider);

    final List<DriverSuggestionIdeaItem> ideas = topIdeasAsync.maybeWhen(
      data: (items) => items
          .map(
            (s) => driverSuggestionIdeaFromStatus(
              text: s.suggestionText,
              status: s.status,
              votesLabel: DriverStrings.votesCount(s.votesCount),
              colors: colors,
            ),
          )
          .toList(),
      orElse: () => <DriverSuggestionIdeaItem>[],
    );

    return DriverAppSuggestionBody(
      colors: colors,
      typography: typography,
      introText: DriverStrings.appSuggestionIntro,
      hintText: DriverStrings.appSuggestionHint,
      controller: _controller,
      submitting: _isSubmitting,
      ideasLoading: topIdeasAsync.isLoading,
      ideasError:
          topIdeasAsync.hasError ? DriverStrings.topIdeasLoadFailed : null,
      ideas: ideas,
      onBack: () => context.pop(),
      onSubmit: _submit,
    );
  }
}
