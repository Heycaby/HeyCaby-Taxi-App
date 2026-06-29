-- Localized rider home banner rows (one row per locale; slug is unique globally).

DELETE FROM public.rider_home_banners
WHERE slug IN (
  'anniversary_2026_example',
  'no_supply_notice',
  'anniversary_2026_en',
  'anniversary_2026_nl',
  'anniversary_2026_ar',
  'no_supply_en',
  'no_supply_nl',
  'no_supply_ar'
);

INSERT INTO public.rider_home_banners (
  slug, title, subtitle, variant, tap_action, modal_title, modal_body, locale, priority, is_active
) VALUES
(
  'anniversary_2026_en',
  'HeyCaby turns 1 today!',
  'Tap to see how we are celebrating with riders and drivers.',
  'promo', 'modal',
  'One year of HeyCaby',
  'Thank you for riding with us. Stay tuned for anniversary perks — details will appear here when the campaign goes live.',
  'en', 100, false
),
(
  'anniversary_2026_nl',
  'HeyCaby is vandaag 1 jaar!',
  'Tik om te zien hoe we het vieren met passagiers en chauffeurs.',
  'promo', 'modal',
  'Eén jaar HeyCaby',
  'Bedankt dat je met ons rijdt. Binnenkort delen we hier de anniversary-acties.',
  'nl', 100, false
),
(
  'anniversary_2026_ar',
  'HeyCaby يكمل سنة اليوم!',
  'اضغط لمعرفة كيف نحتفل مع الركاب والسائقين.',
  'promo', 'modal',
  'عام من HeyCaby',
  'شكرًا لركوبك معنا. ترقّب مزايا الذكرى السنوية هنا عند إطلاق الحملة.',
  'ar', 100, false
);

INSERT INTO public.rider_home_banners (
  slug, title, subtitle, variant, tap_action, only_when_no_supply, locale, priority, is_active
) VALUES
(
  'no_supply_en',
  'No taxis in your zone',
  'You can still request — we''ll notify you when a driver is available.',
  'accent', 'none', true, 'en', 50, false
),
(
  'no_supply_nl',
  'Geen taxi''s in jouw zone',
  'Je kunt toch een rit aanvragen — we laten het weten zodra er een chauffeur is.',
  'accent', 'none', true, 'nl', 50, false
),
(
  'no_supply_ar',
  'لا تاكسي في منطقتك',
  'يمكنك طلب رحلة — سنُخبرك عند توفر سائق.',
  'accent', 'none', true, 'ar', 50, false
);
