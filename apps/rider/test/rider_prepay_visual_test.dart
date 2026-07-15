import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/providers/booking_provider.dart';
import 'package:heycaby_rider/widgets/rider_prepay_card.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class _FakePrepaidService extends PrepaidRidePaymentService {
  const _FakePrepaidService(this.payment);

  final PrepaidRidePayment? payment;

  @override
  Future<PrepaidRidePaymentResult> snapshot({
    required String rideId,
    String? riderToken,
  }) async =>
      PrepaidRidePaymentResult.ok(payment);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('required prepay card fits a compact phone with larger text', (
    tester,
  ) async {
    const surface = Size(320, 568);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  RiderPrepayCard(
                    rideId: 'ride-1',
                    mode: BookingMode.scheduled,
                    colors: kHeyCabyDaylight,
                    typography: buildTypographyForTheme('daylight'),
                    l10n: AppLocalizations.of(context),
                    service: const _FakePrepaidService(
                      PrepaidRidePayment(
                        id: 'payment-1',
                        state: 'open',
                        amountCents: 4275,
                        currency: 'EUR',
                        checkoutUrl: 'https://www.mollie.com/checkout/test',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('€42.75'), findsOneWidget);
  });
}
