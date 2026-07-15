import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_locale_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_liability_acknowledgment_body.dart';

// English - Full Terms of Service (Word-for-Word from Document)
const String _fullTermsEn = '''HEYCABY — ALGEMENE VOORWAARDEN
Terms of Service — English (Governing Language)
Version 1.0 | Effective Date: 1 May 2026

Important Notice: These Terms of Service constitute a legally binding agreement between you and HeyCaby. Read them carefully and completely before using the platform. By creating an account or using the HeyCaby application, you confirm that you have read, understood, and agree to be bound by these Terms.

Governing Law: These Terms are governed by the laws of the Netherlands. Any disputes shall be submitted exclusively to the competent courts of Rotterdam, the Netherlands.

Language: In the event of any conflict between the Dutch and English versions of these Terms, the English version shall prevail.

ARTICLE 1 — DEFINITIONS
In these Terms of Service, the following definitions apply:

"HeyCaby" or "the Platform" means HeyCaby, a private limited company incorporated under Dutch law, registered with the Kamer van Koophandel (KvK) under number 42021548, with its registered address at Lindenhof, Rotterdam, the Netherlands.

"Platform Services" means the digital directory, communication tools, and profile management features made available by HeyCaby through its mobile application and any associated software.

"Driver" means any independent taxi operator who registers on the Platform as a driver to advertise their taxi services to Riders. Drivers must be licensed professional taxi operators under Dutch law.

"Rider" means any person who accesses the Platform to locate and contact available Drivers, whether or not they have created a registered account.

"Transport Agreement" means the direct contractual agreement formed exclusively between a Driver and a Rider for the provision of taxi transport services. HeyCaby is not a party to any Transport Agreement.

"Driver Profile" means the publicly visible profile a Driver creates on the Platform containing information about their vehicle, service area, rates, and availability.

"Chauffeurskaart" means the taxi driver's card (chauffeursbevoegdheid) issued by Kiwa Register on behalf of the Dutch government, as required under the Wet personenvervoer 2000 (WP2000).

"Taxivergunning" means the taxi transport licence (vergunning voor taxivervoer) issued by Kiwa Register on behalf of the Dutch government, as required under Article 76 of the Wet personenvervoer 2000.

"P-nummer" means the Personenvervoernummer assigned to a licensed taxi operator upon receipt of their Taxivergunning.

"Driver Access Fee" means the fee paid by Drivers to access Driver features of the Platform, currently set at €30 per 7 days plus 21% VAT for the first 200 approved Founding Members. Rider access to the Platform is free of charge.

"Content" means any information, text, images, data, or other material uploaded, posted, or transmitted by a User through the Platform.

"User" means any person — whether Driver or Rider — who accesses or uses the Platform.

"GDPR" means the General Data Protection Regulation (EU) 2016/679.

"DSA" means the Digital Services Act (EU) 2022/2065, the EU Regulation on a Single Market for Digital Services.

ARTICLE 2 — NATURE OF THE PLATFORM
2.1 Directory and Communication Tool Only. HeyCaby operates exclusively as a digital directory and communication platform. HeyCaby enables licensed, independent taxi professionals to advertise their services and enables Riders to locate and contact those professionals. HeyCaby does not provide taxi transport services, does not employ Drivers, does not act as a taxi operator, dispatcher, or transport company of any kind, and does not set, control, or influence pricing, routing, or availability of Drivers.

2.2 No Intermediary Role in Transport Agreements. HeyCaby is not a party to any Transport Agreement between a Driver and a Rider. All contractual obligations arising from a taxi journey — including obligations related to safety, pricing, timeliness, vehicle condition, professional conduct, and legal compliance — rest exclusively and entirely with the Driver as an independent professional.

2.3 Platform as Passive Directory. In accordance with Article 6:196c of the Dutch Burgerlijk Wetboek (Civil Code) and the relevant provisions of the Digital Services Act (EU) 2022/2065, HeyCaby functions as a passive information society service provider. HeyCaby transmits and stores information provided by Drivers and Riders but does not initiate the transmission, select the receivers, or select or modify the information transmitted.

2.4 Driver Verification and Limitations. HeyCaby operates as a technology platform that facilitates connections between riders and independent drivers. While HeyCaby does not guarantee the validity, authenticity, or continued compliance of any driver's credentials, the platform implements reasonable verification measures to enhance safety and trust.

2.4.1 No Guarantee of Credentials. HeyCaby does not verify, authenticate, or guarantee the validity, currency, or authenticity of any licence, permit, certificate, insurance policy, or credential presented or declared by any Driver. This includes, without limitation, the Chauffeurskaart, Taxivergunning, P-nummer, vehicle insurance, and any other authorisation required under Dutch law. Drivers remain fully and solely responsible for obtaining, maintaining, and complying with all applicable legal and regulatory requirements at all times.

2.4.2 Verification Measures Implemented by HeyCaby. Without creating any warranty or guarantee, HeyCaby may perform the following checks:

(a) Vehicle Verification (RDW). HeyCaby uses publicly available data from the RDW (Rijksdienst voor het Wegverkeer) to verify vehicle registration details. This includes license plate validation, vehicle make and registration status, and confirmation that the vehicle is registered as a taxi (including blue license plate where applicable). Only vehicles that meet these criteria may be allowed to operate on the platform.

(b) Identity Verification (Veriff). HeyCaby uses a third-party identity verification provider, Veriff, to verify driver identity, validate driver's licence authenticity, and confirm that drivers are who they claim to be. This process is conducted through secure third-party systems.

(c) Chauffeurskaart Checks. HeyCaby may perform periodic manual checks of submitted Chauffeurskaart documents to assess validity. However, HeyCaby does not guarantee ongoing validity or compliance.

(d) Insurance Documentation. Drivers are required to submit proof of valid vehicle insurance, including insurance provider, coverage details, and expiration date. HeyCaby may review this documentation but does not guarantee its accuracy or continued validity.

(e) Business Registration (KvK). Where applicable, HeyCaby may verify driver business registration details via the Kamer van Koophandel (KvK) public register to confirm business existence and registration status. Drivers remain responsible for ensuring their business operates in compliance with Dutch law.

2.4.3 Important Limitation. These verification steps are conducted on a best-effort basis and are not exhaustive. They do not eliminate risk, and HeyCaby does not warrant that any driver is compliant, licensed, insured, or operating lawfully at all times. Drivers may attempt to circumvent verification systems, and HeyCaby cannot fully prevent such actions.

2.4.4 Reporting and Enforcement. If you become aware of any driver who may be operating without valid credentials, violating applicable laws or regulations, or engaging in unsafe or fraudulent behavior, you are encouraged to report this immediately to qb@heycaby.nl. HeyCaby reserves the right to investigate and take appropriate action, including suspension or removal from the platform.

2.5 Independent Contractors. Drivers are independent contractors and self-employed professionals (zelfstandigen zonder personeel, ZZP). No employment relationship, agency relationship, partnership, joint venture, or franchise relationship exists between HeyCaby and any Driver.

ARTICLE 3 — ELIGIBILITY AND ACCOUNT REGISTRATION
3.1 Driver Eligibility. To register as a Driver on the Platform, you must, at the time of registration and at all times during your use of the Platform:

(a) Hold a valid Chauffeurskaart (chauffeursbevoegdheid) issued by Kiwa Register, as required under the Wet personenvervoer 2000;
(b) Hold a valid Taxivergunning (vergunning voor taxivervoer) issued by Kiwa Register on behalf of the Dutch government, as required under Article 76 of the Wet personenvervoer 2000;
(c) Be registered in the Handelsregister of the Kamer van Koophandel (KvK) with SBI-code 49330 (taxi transport services) or any successor code;
(d) Hold a valid and current professional taxi insurance policy (beroepsaansprakelijkheidsverzekering) and a valid WAM (Wet aansprakelijkheidsverzekering motorrijtuigen) insurance policy covering your taxi vehicle for commercial transport use;
(e) Hold a valid taxi vehicle registration (blue plate/blauw kenteken) as issued by the RDW (Rijksdienst voor het Wegverkeer) for the vehicle(s) listed on your Driver Profile;
(f) Hold a valid Verklaring Omtrent het Gedrag (VOG) as required for the exercise of the taxi profession;
(g) Hold a valid driving licence (rijbewijs) authorising you to perform commercial passenger transport;
(h) Comply with all obligations under the Arbeidstijdenwet regarding driving and rest times;
(i) Be at least 21 years of age;
(j) Be legally authorised to work as a self-employed person in the Netherlands.

3.2 Driver Self-Declaration. By completing your Driver registration and activating your Driver Profile, you make a legal declaration and warranty to HeyCaby and to all Riders who view your profile that you meet all eligibility requirements set out in Article 3.1 and that all information provided in your Driver Profile is accurate, complete, and current.

3.3 Ongoing Compliance Obligation. Your eligibility is not a one-time check. You are required to maintain compliance with all requirements in Article 3.1 for the entire duration of your use of the Platform. If any of your credentials expire, are revoked, are suspended, or otherwise cease to be valid, you are required to immediately deactivate your Driver Profile and cease advertising your services on the Platform until validity is restored.

3.4 Rider Access. Riders may use the Platform without creating an account or providing an email address or phone number. However, before requesting a driver, Riders may be required to provide a display name so the Driver can identify who to pick up. Riders may optionally create an account to access features such as ride history and invoicing. Riders must be at least 16 years of age to use the Platform. Riders under the age of 18 should have parental consent.

3.5 Account Security. You are responsible for maintaining the confidentiality of your account credentials and for all activity that occurs under your account. You must notify HeyCaby immediately if you become aware of any unauthorised use of your account.

3.6 One Account Per Person. Each Driver may hold only one Driver account. Creating multiple accounts for the same individual is prohibited and will result in the suspension of all associated accounts.

ARTICLE 4 — DRIVER OBLIGATIONS
4.1 Legal Compliance. Drivers must at all times comply with:

(a) The Wet personenvervoer 2000 (WP2000) and all subordinate legislation including the Besluit personenvervoer 2000 (BP2000);
(b) All conditions attached to their Taxivergunning and Chauffeurskaart;
(c) All applicable municipal taxi regulations, including any local taxiverordeningen in the cities in which they operate;
(d) All applicable traffic laws and road transport regulations;
(e) The Arbeidstijdenwet requirements regarding working hours and rest periods;
(f) All applicable tax laws, including VAT obligations (if applicable) and income tax obligations under the Wet inkomstenbelasting 2001;
(g) The GDPR and applicable Dutch privacy legislation regarding any personal data processed during the provision of transport services.

4.2 Accuracy of Profile Information. Drivers must ensure that all information on their Driver Profile — including vehicle details, licence plate number, service area, pricing, and availability — is accurate, truthful, and current. Drivers must promptly update their Profile whenever any information changes.

4.3 Professional Conduct. Drivers must conduct themselves professionally and courteously at all times when interacting with Riders through or in connection with the Platform.

4.4 Pricing Transparency. Drivers set their own rates. Rates displayed on a Driver Profile must be the actual rates the Driver charges. Drivers may not engage in deceptive pricing practices, including charging rates that differ materially from those displayed on their Profile without prior agreement with the Rider.

4.5 Anti-Discrimination. Drivers must not refuse to provide services to any Rider on the basis of race, ethnicity, nationality, religion, gender, disability, sexual orientation, age, or any other characteristic protected under Dutch law, including the Algemene wet gelijke behandeling.

4.6 Non-Solicitation. Drivers may not use contact information or personal data obtained through the Platform to solicit Riders for services outside the Platform in a manner that undermines the Platform's purpose or violates applicable law.

4.7 Prohibited Conduct. Drivers must not:

(a) Operate their taxi vehicle without valid insurance, a valid Chauffeurskaart, or a valid Taxivergunning;
(b) Allow any person other than themselves (or an employee or subcontractor who holds all required credentials) to operate a vehicle listed on their Driver Profile;
(c) Use the Platform to engage in any fraudulent, deceptive, or misleading activity;
(d) Upload Content that is false, defamatory, harassing, abusive, obscene, discriminatory, or otherwise unlawful;
(e) Circumvent, disable, or interfere with any security features of the Platform;
(f) Reverse-engineer, decompile, or disassemble any part of the Platform software.

ARTICLE 5 — RIDER OBLIGATIONS
5.1 Honest Use. Riders must use the Platform honestly and in good faith. Riders must not use the Platform to engage in any fraudulent, abusive, or unlawful conduct.

5.2 Respectful Conduct. Riders must treat Drivers with respect and must not harass, threaten, or abuse Drivers in any way.

5.3 Accurate Information. Where Riders provide information to the Platform (such as contact information or pickup location), that information must be accurate.

5.4 Direct Relationship. Riders acknowledge that their transport is provided by an independent Driver and that their contractual relationship for the transport service is exclusively with that Driver, not with HeyCaby.

ARTICLE 6 — CONTENT AND INTELLECTUAL PROPERTY
6.1 User Content. You retain ownership of any Content you upload to the Platform. By uploading Content, you grant HeyCaby a non-exclusive, royalty-free, worldwide licence to use, display, reproduce, and distribute that Content solely for the purposes of operating and improving the Platform.

6.2 Content Standards. You must not upload Content that:

(a) Is false, misleading, or deceptive;
(b) Infringes any third party's intellectual property rights;
(c) Contains personal data of third parties without their consent;
(d) Is defamatory, harassing, discriminatory, or obscene;
(e) Promotes illegal activities;
(f) Contains malware, viruses, or other harmful code.

6.3 HeyCaby Intellectual Property. The Platform, including all software, design, trademarks, logos, and content created by HeyCaby, is protected by intellectual property law. You may not use, copy, modify, or distribute HeyCaby's intellectual property without express written consent.

6.4 Content Removal. HeyCaby reserves the right to remove any Content that violates these Terms or applicable law, in accordance with its obligations under the Digital Services Act.

ARTICLE 7 — PLATFORM AVAILABILITY AND MODIFICATIONS
7.1 No Uptime Guarantee. HeyCaby provides the Platform on an "as is" and "as available" basis. HeyCaby does not guarantee uninterrupted or error-free access to the Platform. HeyCaby may suspend, modify, or discontinue the Platform or any feature thereof at any time, with or without notice.

7.2 Maintenance. HeyCaby may take the Platform offline for maintenance. HeyCaby will endeavour to provide advance notice of planned maintenance but is not obligated to do so.

7.3 Modifications to the Platform. HeyCaby may add, modify, or remove features from the Platform at any time. Material changes that affect Driver Access Fees will be communicated with at least 30 days' notice.

ARTICLE 8 — PLATFORM BALANCE, PAYMENT AND PAUSED RIDE REQUESTS
8.1 Driver Service Fee. HeyCaby charges the Driver a backend-configured service fee only after a successfully completed, chargeable ride. The current fee and estimated net earnings are shown before acceptance and are frozen for that ride. The Rider is not charged this fee as an extra Rider surcharge.

8.2 Platform Balance. For cash, PIN, Tikkie or another direct payment, the Rider pays the Driver and the completed-ride service fee is added to the Driver's Platform Balance. For a prepaid ride, the frozen fee is deducted before the verified Driver payout is routed.

8.3 Effect of an Outstanding Balance. At the backend-configured balance limit, HeyCaby may pause new direct-payment rides. Eligible prepaid rides remain available because the service fee can be collected automatically. The Driver keeps access to their account, documents, history, support and other tools.

8.4 No Subscription. The Driver Service Fee is per chargeable completed ride and is not a weekly subscription or long-term plan.

8.5 Settlement. Drivers settle an outstanding Platform Balance through the payment methods made available by HeyCaby or its payment partners. Bank transfers may require a payment reference so HeyCaby can identify the payment. Payments may take time to appear in the driver's balance.

8.6 Loss of Preferential Status. Any preferential driver status is conditional and may be lost. A driver may lose such status if they: (a) break platform rules; (b) fail to pay on time; (c) remain inactive for an extended period; (d) fail to maintain valid legal documents, permits, insurance, or required taxi credentials; or (e) misuse, abuse, or attempt to manipulate the platform.

8.7 Future Pricing. HeyCaby may schedule a future Driver Service Fee. A fee change never alters an already accepted ride's frozen fee. Material changes will be communicated where required by law or contract.

8.8 Payment Processing. Payments are processed by Mollie B.V., a third-party payment service provider based in the Netherlands. By making a payment, you agree to be bound by Mollie's applicable terms and conditions. Mollie may process payment-related data as an independent data controller in accordance with its own privacy policy. HeyCaby does not store or process payment card details on its own servers.

8.9 Rider Services. Rider access to the Platform is free of charge. HeyCaby does not process payments for taxi journeys. Payment for taxi services is made directly between the Rider and the Driver.

8.10 VAT and Tax. Drivers are solely responsible for all tax obligations arising from their use of the Platform and from the taxi services they provide. HeyCaby may issue VAT invoices for Driver Access Fees where required by law. The Driver Access Fee does not constitute income of the Driver; it is a business tool cost which may be tax-deductible for ZZP drivers. Drivers should consult a tax adviser regarding their specific situation.

ARTICLE 9 — LIMITATION OF LIABILITY
9.1 HeyCaby's Exclusion of Liability for Transport Services. To the maximum extent permitted by mandatory applicable law:

(a) HeyCaby is not liable for any loss, damage, injury, death, delay, or other harm arising from or in connection with any taxi journey arranged through the Platform. All liability for transport services rests exclusively with the Driver who provides those services;
(b) HeyCaby is not liable for any Driver's failure to hold valid credentials, insurance, or any required licence or permit;
(c) HeyCaby is not liable for any Driver's conduct during a taxi journey, including but not limited to negligent driving, accidents, theft, or personal injury;
(d) HeyCaby is not liable for any Rider's conduct towards a Driver;
(e) HeyCaby is not liable for the accuracy or completeness of information provided by Drivers or Riders on the Platform.

9.2 Platform Liability Limitation. To the maximum extent permitted by mandatory applicable law, HeyCaby's total aggregate liability to any User for any claims arising from or in connection with the Platform Services (as distinct from transport services) shall not exceed the total Driver Access Fees paid by that User in the three months preceding the claim.

9.3 Exclusion of Consequential Damages. To the maximum extent permitted by mandatory applicable law, HeyCaby is not liable for any indirect, incidental, special, consequential, or punitive damages, including loss of profits, loss of data, loss of goodwill, or business interruption, arising from or in connection with the Platform or these Terms.

9.4 Mandatory Consumer Rights. Nothing in these Terms limits or excludes any liability that cannot be limited or excluded under mandatory Dutch law, including liability for death or personal injury caused by HeyCaby's own gross negligence or wilful misconduct, or any rights that consumers cannot be deprived of under Dutch consumer protection law.

9.5 Force Majeure. HeyCaby is not liable for any failure or delay in performance caused by circumstances beyond its reasonable control, including but not limited to acts of God, war, terrorism, pandemics, governmental actions, power failures, or telecommunications failures.

ARTICLE 10 — INDEMNIFICATION BY DRIVERS
10.1 Driver Indemnification Obligation. Drivers agree to indemnify, defend, and hold harmless HeyCaby, its directors, officers, employees, contractors, and agents ("HeyCaby Parties") from and against any and all claims, damages, losses, liabilities, costs, and expenses (including reasonable legal fees) arising out of or in connection with:

(a) Any Driver's provision of taxi services, including any accident, injury, death, or property damage occurring during or in connection with a taxi journey;
(b) Any Driver's failure to hold, maintain, or comply with any required licence, permit, insurance, or credential, including but not limited to the Chauffeurskaart, Taxivergunning, or WAM insurance;
(c) Any Driver's violation of these Terms of Service;
(d) Any Driver's violation of any applicable law or regulation;
(e) Any Content uploaded by a Driver that infringes any third party right or violates any applicable law;
(f) Any claim by a Rider or any third party arising from a Driver's conduct.

Note: The standalone Indemnification and Liability Declaration document, which Drivers sign separately at registration, sets out the full terms of this indemnification obligation.

ARTICLE 11 — SUSPENSION AND TERMINATION
11.1 HeyCaby's Right to Suspend or Terminate. HeyCaby may suspend or permanently terminate any User account, with or without prior notice, if:

(a) The User violates these Terms of Service;
(b) HeyCaby receives credible evidence that a Driver is operating without valid required credentials;
(c) HeyCaby receives credible evidence of fraudulent, deceptive, dangerous, or illegal conduct;
(d) A Driver's 7-day access fee payment fails and is not remedied within 7 days;
(e) HeyCaby is required to do so by applicable law or court order;
(f) HeyCaby determines, in its reasonable discretion, that the User's presence on the Platform poses a risk to other Users or to HeyCaby.

11.2 Notice of Suspension. Where feasible and not precluded by law enforcement considerations, HeyCaby will notify a Driver before suspending their account and will provide a reasonable opportunity to respond. This obligation does not apply in cases of immediate safety risk or legal obligation.

11.3 User's Right to Terminate. You may terminate your account at any time through the Platform settings. Driver Access Fees already paid are non-refundable as provided in Article 8.5.

11.4 Effect of Termination. Upon termination of your account, your right to access the Platform ceases immediately. HeyCaby will retain and process your personal data in accordance with its Privacy Policy and applicable law.

ARTICLE 12 — DISPUTE RESOLUTION
12.1 Complaints. If you have a complaint about the Platform, please contact HeyCaby support at support@heycaby.nl. HeyCaby will make reasonable efforts to resolve complaints within 14 days.

12.2 Consumer Mediation. If you are a consumer and your complaint cannot be resolved directly with HeyCaby, you may have the right to submit your complaint to the Geschillencommissie (Dutch Disputes Committee) or other applicable consumer dispute resolution bodies, or to the European Online Dispute Resolution platform at https://ec.europa.eu/consumers/odr.

12.3 Driver Disputes. Disputes between HeyCaby and Drivers that cannot be resolved through good faith negotiation shall be submitted to the exclusive jurisdiction of the competent court in Rotterdam, the Netherlands.

12.4 Rider-Driver Disputes. Disputes between Riders and Drivers regarding taxi services are exclusively between the Rider and the Driver. HeyCaby is not a mediator and is not responsible for resolving such disputes. HeyCaby may, at its sole discretion, remove from the Platform a Driver who is the subject of multiple credible complaints from Riders.

12.5 Governing Law. These Terms are governed by Dutch law. The application of the UN Convention on Contracts for the International Sale of Goods is excluded.

ARTICLE 13 — PRIVACY AND DATA PROTECTION
13.1 Privacy Policy. HeyCaby processes personal data in accordance with its Privacy Policy, which forms part of these Terms and is available at https://www.heycaby.nl/privacy. The Privacy Policy describes what data is collected, how it is used, how long it is retained, and the rights of Users under the GDPR.

13.2 Data Processing Role. HeyCaby is the data controller for personal data processed through the Platform. Drivers process personal data of Riders independently in their capacity as data controllers for the purposes of providing transport services. Drivers are solely responsible for ensuring their own data processing activities comply with the GDPR.

13.3 Rider Limited-Data Use. Riders may use the Platform without creating an account, email address, or phone number. HeyCaby may process a temporary session identifier, pickup and drop-off information, and a rider display name where necessary to request a driver and complete the ride flow.

13.4 Third-Party Service Providers. HeyCaby uses the following third-party services to operate the Platform. These providers may process personal data as necessary to deliver their services:

(a) Supabase (Supabase Inc.) — Database hosting, authentication, and storage (EU data centres, Frankfurt region);
(b) Mollie (Mollie B.V.) — Payment processing for Driver Access Fees;
(c) Firebase / Firebase Cloud Messaging (Google LLC) — push notifications;
(d) Veriff (Veriff Identity OÜ) — Driver identity verification and document checks;
(e) RDW (Rijksdienst voor het Wegverkeer) — Public vehicle registration data lookup;
(f) KvK (Kamer van Koophandel) — Public business registration verification;
(g) Mapbox (Mapbox, Inc.) — Maps and location services;
(h) AI Support Assistant — Automated support chat powered by third-party AI providers (including OpenAI). Messages may be processed by these providers to generate responses. Users are clearly informed before first use and must provide explicit consent before any data is processed by AI systems.

All third-party providers are bound by data processing agreements ensuring GDPR compliance. Data is not transferred outside the EEA without appropriate safeguards.

ARTICLE 14 — NOTICES AND COMMUNICATIONS
14.1 Communications to Users. HeyCaby may communicate with Users by in-app notification, email (where an email address is provided), or push notification.

14.2 Communications to HeyCaby. Legal notices to HeyCaby must be sent in writing to: HeyCaby, Lindenhof, Rotterdam, the Netherlands, or by email to legal@heycaby.nl.

14.3 Contact Channels. HeyCaby maintains different communication channels for specific purposes:

(a) support@heycaby.nl — customer support and technical assistance;
(b) hello@heycaby.nl — general inquiries and business communication;
(c) qb@heycaby.nl — reporting legal, regulatory, or safety concerns;
(d) legal@heycaby.nl — formal legal notices.

ARTICLE 15 — GENERAL PROVISIONS
15.1 Entire Agreement. These Terms, together with the Privacy Policy and the Indemnification and Liability Declaration signed by Drivers, constitute the entire agreement between you and HeyCaby regarding the Platform and supersede all prior agreements.

15.2 Severability. If any provision of these Terms is found to be invalid, illegal, or unenforceable under applicable law, that provision shall be modified to the minimum extent necessary to make it valid, legal, and enforceable. All other provisions remain in full force and effect.

15.3 No Waiver. HeyCaby's failure to enforce any right or provision of these Terms does not constitute a waiver of that right or provision.

15.4 Assignment. HeyCaby may assign its rights and obligations under these Terms to a successor entity without your consent. You may not assign your rights or obligations under these Terms without HeyCaby's prior written consent.

15.5 Amendments. HeyCaby may amend these Terms at any time. Amended Terms will be communicated to Users by in-app notification and email (where available) at least 14 days before the amendments take effect. Continued use of the Platform after the effective date constitutes acceptance of the amended Terms. If you do not accept the amendments, you must stop using the Platform and terminate your account before the effective date.

15.6 Language. These Terms are available in English and Dutch. In the event of any discrepancy, the English version shall prevail.

ARTICLE 16 — ACKNOWLEDGMENT AND WAIVER
16.1 Express Acknowledgment. By using the HeyCaby platform, you expressly acknowledge that:

(a) You have been given the opportunity to read these Terms of Service in full;
(b) You have been given the opportunity to read the Indemnification and Liability Declaration in full;
(c) You understand your rights and obligations under both documents.

16.2 Waiver of Claims. You waive any claim that you were not aware of the contents of these documents, that you did not understand them, or that you did not have adequate opportunity to review them.

16.3 Binding Confirmation. By continuing to use the platform, you confirm:

I have read and agree to the Terms of Service and the Indemnification & Liability Declaration.

HeyCaby — 42021548 — Lindenhof, Rotterdam, Netherlands
Last updated: 1 May 2026 — Version 1.0''';

// Dutch - Full Terms of Service (Word-for-Word from Document)
const String _fullTermsNl = '''HEYCABY — ALGEMENE VOORWAARDEN
Gebruiksvoorwaarden — Nederlands
Versie 1.0 | Ingangsdatum: 1 mei 2026

Belangrijke mededeling: Deze Gebruiksvoorwaarden vormen een juridisch bindende overeenkomst tussen u en HeyCaby. Lees ze zorgvuldig en volledig door voordat u het platform gebruikt. Door een account aan te maken of de HeyCaby-applicatie te gebruiken, bevestigt u dat u deze Voorwaarden hebt gelezen, begrepen en ermee akkoord gaat.

Toepasselijk recht: Deze Voorwaarden worden beheerst door het Nederlands recht. Eventuele geschillen worden uitsluitend voorgelegd aan de bevoegde rechtbanken in Rotterdam, Nederland.

Taal: In geval van een conflict tussen de Nederlandse en Engelse versie van deze Voorwaarden, prevaleert de Engelse versie.

ARTIKEL 1 — DEFINITIES
In deze Gebruiksvoorwaarden gelden de volgende definities:

"HeyCaby" of "het Platform" betekent HeyCaby, een besloten vennootschap opgericht naar Nederlands recht, geregistreerd bij de Kamer van Koophandel (KvK) onder nummer 42021548, met haar geregistreerde adres te Lindenhof, Rotterdam, Nederland.

"Platformdiensten" betekent de digitale gids, communicatietools en profielbeheerfuncties die door HeyCaby beschikbaar worden gesteld via haar mobiele applicatie en eventuele bijbehorende software.

"Chauffeur" betekent elke zelfstandige taxionderneming die zich registreert op het Platform als chauffeur om zijn taxidiensten aan Passagiers te adverteren. Chauffeurs moeten professionele taxichauffeurs zijn conform het Nederlands recht.

"Passagier" betekent elke persoon die toegang krijgt tot het Platform om beschikbare Chauffeurs te vinden en contact met hen op te nemen, ongeacht of deze een geregistreerd account heeft aangemaakt.

"Vervoersovereenkomst" betekent de directe contractuele overeenkomst die uitsluitend wordt gevormd tussen een Chauffeur en een Passagier voor de levering van taxivervoersdiensten. HeyCaby is geen partij bij enige Vervoersovereenkomst.

"Chauffeursprofiel" betekent het publiek zichtbare profiel dat een Chauffeur aanmaakt op het Platform met informatie over zijn voertuig, servicegebied, tarieven en beschikbaarheid.

"Chauffeurskaart" betekent de chauffeurskaart (chauffeursbevoegdheid) afgegeven door Kiwa Register namens de Nederlandse overheid, zoals vereist onder de Wet personenvervoer 2000 (WP2000).

"Taxivergunning" betekent de taxi vergunning voor taxivervoer afgegeven door Kiwa Register namens de Nederlandse overheid, zoals vereist onder artikel 76 van de Wet personenvervoer 2000.

"P-nummer" betekent het Personenvervoernummer dat wordt toegekend aan een gelicenseerde taxionderneming bij ontvangst van zijn Taxivergunning.

"Chauffeurstoegangstarief" betekent het tarief dat door Chauffeurs wordt betaald om toegang te krijgen tot Chauffeursfuncties van het Platform, momenteel vastgesteld op €30 per 7 dagen plus 21% BTW voor de eerste 200 goedgekeurde Grondleggers. Passagiers hebben gratis toegang tot het Platform.

"Content" betekent elke informatie, tekst, afbeeldingen, data of ander materiaal dat door een Gebruiker wordt geüpload, geplaatst of verzonden via het Platform.

"Gebruiker" betekent elke persoon — Chauffeur of Passagier — die toegang krijgt tot of gebruikmaakt van het Platform.

"AVG" betekent de Algemene Verordening Gegevensbescherming (EU) 2016/679.

"DSA" betekent de Digital Services Act (EU) 2022/2065, de EU-verordening betreffende een digitale interne markt.

ARTIKEL 2 — AARD VAN HET PLATFORM
2.1 Alleen Gids- en Communicatietool. HeyCaby opereert uitsluitend als digitale gids en communicatieplatform. HeyCaby stelt gelicenseerde, zelfstandige taxiprofessionals in staat om hun diensten te adverteren en stelt Passagiers in staat om deze professionals te vinden en contact met hen op te nemen. HeyCaby verstrekt geen taxivervoersdiensten, neemt geen Chauffeurs in dienst, treedt niet op als taxionderneming, centrale, of vervoersbedrijf van welke aard dan ook, en bepaalt, beheert of beïnvloedt geen prijzen, routes of beschikbaarheid van Chauffeurs.

2.2 Geen Intermediaire Rol in Vervoersovereenkomsten. HeyCaby is geen partij bij enige Vervoersovereenkomst tussen een Chauffeur en een Passagier. Alle contractuele verplichtingen voortvloeiend uit een taxirit — inclusief verplichtingen met betrekking tot veiligheid, prijzen, tijdigheid, voertuigconditie, professioneel gedrag en wettelijke naleving — rusten uitsluitend en volledig op de Chauffeur als zelfstandig professional.

2.3 Platform als Passieve Gids. In overeenstemming met artikel 6:196c van het Nederlands Burgerlijk Wetboek en de relevante bepalingen van de Digital Services Act (EU) 2022/2065, fungeert HeyCaby als een passieve aanbieder van informatiemaatschappelijke diensten. HeyCaby verzendt en slaat informatie op die door Chauffeurs en Passagiers wordt verstrekt, maar initieert de verzending niet, selecteert de ontvangers niet, of selecteert of wijzigt de verzonden informatie niet.

2.4 Chauffeurverificatie en Beperkingen. HeyCaby opereert als technologieplatform dat verbindingen faciliteert tussen passagiers en zelfstandige chauffeurs. Hoewel HeyCaby de geldigheid, authenticiteit of voortgezette naleving van de credentials van enige chauffeur niet garandeert, implementeert het platform redelijke verificatiemaatregelen om veiligheid en vertrouwen te vergroten.

2.4.1 Geen Garantie op Credentials. HeyCaby verifieert, authenticeert of garandeert niet de geldigheid, actualiteit of authenticiteit van enig rijbewijs, vergunning, certificaat, verzekeringspolis of credential die door enige Chauffeur wordt gepresenteerd of verklaard. Dit omvat, zonder beperking, de Chauffeurskaart, Taxivergunning, P-nummer, voertuigverzekering, en enige andere autorisatie vereist onder Nederlands recht. Chauffeurs blijven te allen tijde volledig en uitsluitend verantwoordelijk voor het verkrijgen, onderhouden en naleven van alle toepasselijke wettelijke en regelgevende vereisten.

2.4.2 Door HeyCaby Geïmplementeerde Verificatiemaatregelen. Zonder enige garantie of waarborg te creëren, kan HeyCaby de volgende controles uitvoeren:

(a) Voertuigverificatie (RDW). HeyCaby gebruikt publiek beschikbare data van de RDW (Rijksdienst voor het Wegverkeer) om voertuigregistratiegegevens te verifiëren. Dit omvat kentekenvalidatie, voertuigmerk en registratiestatus, en bevestiging dat het voertuig als taxi is geregistreerd (inclusief blauw kenteken waar van toepassing). Alleen voertuigen die aan deze criteria voldoen, mogen op het platform opereren.

(b) Identiteitsverificatie (Veriff). HeyCaby gebruikt een externe identiteitsverificatieprovider, Veriff, om de identiteit van de chauffeur te verifiëren, de authenticiteit van het rijbewijs te valideren, en te bevestigen dat chauffeurs zijn wie ze beweren te zijn. Dit proces wordt uitgevoerd via beveiligde externe systemen.

(c) Chauffeurskaart-controles. HeyCaby kan periodieke handmatige controles uitvoeren van ingediende Chauffeurskaart-documenten om geldigheid te beoordelen. HeyCaby garandeert echter geen voortgezette geldigheid of naleving.

(d) Verzekeringsdocumentatie. Chauffeurs zijn verplicht om bewijs van geldige voertuigverzekering te verstrekken, inclusief verzekeringsmaatschappij, dekkingsdetails en vervaldatum. HeyCaby kan deze documentatie beoordelen maar garandeert niet de nauwkeurigheid of voortgezette geldigheid ervan.

(e) Bedrijfsregistratie (KvK). Waar van toepassing, kan HeyCaby chauffeur bedrijfsregistratiegegevens verifiëren via het publieke register van de Kamer van Koophandel (KvK) om bedrijfsexistentie en registratiestatus te bevestigen. Chauffeurs blijven verantwoordelijk voor het waarborgen dat hun bedrijf opereert in naleving van het Nederlands recht.

2.4.3 Belangrijke Beperking. Deze verificatiestappen worden uitgevoerd op basis van beste inspanning en zijn niet exhaustief. Ze elimineren geen risico, en HeyCaby waarborgt niet dat enige chauffeur te allen tijde compliant, gelicenseerd, verzekerd of wettelijk opereert. Chauffeurs kunnen proberen verificatiesystemen te omzeilen, en HeyCaby kan dergelijke acties niet volledig voorkomen.

2.4.4 Melding en Handhaving. Als u zich bewust bent van enige chauffeur die mogelijk opereert zonder geldige credentials, toepasselijke wetten of regelgeving schendt, of onveilig of frauduleus gedrag vertoont, wordt u aangemoedigd om dit onmiddellijk te melden aan qb@heycaby.nl. HeyCaby behoudt zich het recht voor om te onderzoeken en passende maatregelen te nemen, inclusief schorsing of verwijdering van het platform.

2.5 Zelfstandige Contractanten. Chauffeurs zijn zelfstandige contractanten en zelfstandige professionals (zelfstandigen zonder personeel, ZZP). Er bestaat geen arbeidsrelatie, agentschapsrelatie, partnerschap, joint venture of franchiserelatie tussen HeyCaby en enige Chauffeur.

ARTIKEL 3 — GESCHIKTHEID EN ACCOUNTREGISTRATIE
3.1 Chauffeurgeschiktheid. Om te registreren als Chauffeur op het Platform, moet u, op het moment van registratie en te allen tijde tijdens uw gebruik van het Platform:

(a) Een geldige Chauffeurskaart (chauffeursbevoegdheid) bezitten, afgegeven door Kiwa Register, zoals vereist onder de Wet personenvervoer 2000;
(b) Een geldige Taxivergunning (vergunning voor taxivervoer) bezitten, afgegeven door Kiwa Register namens de Nederlandse overheid, zoals vereist onder artikel 76 van de Wet personenvervoer 2000;
(c) Geregistreerd zijn in het Handelsregister van de Kamer van Koophandel (KvK) met SBI-code 49330 (taxivervoer) of enige opvolgercode;
(d) Een geldige en actuele professionele taxiverzekering (beroepsaansprakelijkheidsverzekering) en een geldige WAM (Wet aansprakelijkheidsverzekering motorrijtuigen) verzekering bezitten die uw taxivoertuig voor commercieel vervoer dekt;
(e) Een geldige taxi voertuigregistratie (blauw kenteken) bezitten, afgegeven door de RDW (Rijksdienst voor het Wegverkeer) voor de op uw Chauffeursprofiel vermelde voertuigen;
(f) Een geldige Verklaring Omtrent het Gedrag (VOG) bezitten zoals vereist voor de uitoefening van het taxiberoep;
(g) Een geldig rijbewijs bezitten dat u autoriseert om commercieel personenvervoer uit te voeren;
(h) Voldoen aan alle verplichtingen onder de Arbeidstijdenwet met betrekking tot rij- en rusttijden;
(i) Minimaal 21 jaar oud zijn;
(j) Wettelijk geautoriseerd zijn om als zelfstandige in Nederland te werken.

3.2 Chauffeur Zelfverklaring. Door uw Chauffeur-registratie te voltooien en uw Chauffeursprofiel te activeren, doet u een juridische verklaring en garantie aan HeyCaby en aan alle Passagiers die uw profiel bekijken dat u voldoet aan alle geschiktheidsvereisten genoemd in artikel 3.1 en dat alle informatie verstrekt in uw Chauffeursprofiel nauwkeurig, volledig en actueel is.

3.3 Doorlopende Nalevingsverplichting. Uw geschiktheid is geen eenmalige controle. U bent verplicht om naleving te handhaven met alle vereisten in artikel 3.1 gedurende de gehele duur van uw gebruik van het Platform. Als enige van uw credentials verloopt, wordt ingetrokken, wordt geschorst of anderszins niet langer geldig is, bent u verplicht om onmiddellijk uw Chauffeursprofiel te deactiveren en te stoppen met het adverteren van uw diensten op het Platform totdat geldigheid is hersteld.

3.4 Passagierstoegang. Passagiers kunnen het Platform gebruiken zonder een account aan te maken of een e-mailadres of telefoonnummer te verstrekken. Echter, voordat een chauffeur wordt aangevraagd, kan van Passagiers worden vereist dat zij een weergavenaam verstrekken zodat de Chauffeur kan identificeren wie moet worden opgehaald. Passagiers kunnen optioneel een account aanmaken om toegang te krijgen tot functies zoals rithistorie en facturering. Passagiers moeten minimaal 16 jaar oud zijn om het Platform te gebruiken. Passagiers onder de 18 jaar dienen ouderlijke toestemming te hebben.

3.5 Accountbeveiliging. U bent verantwoordelijk voor het handhaven van de vertrouwelijkheid van uw accountgegevens en voor alle activiteit die plaatsvindt onder uw account. U moet HeyCaby onmiddellijk informeren als u zich bewust wordt van enige ongeautoriseerde gebruik van uw account.

3.6 Eén Account Per Persoon. Elke Chauffeur mag slechts één Chauffeur-account bezitten. Het aanmaken van meerdere accounts voor dezelfde persoon is verboden en zal resulteren in de schorsing van alle bijbehorende accounts.

ARTIKEL 4 — CHAUFFEURVERPLICHTINGEN
4.1 Wettelijke Naleving. Chauffeurs moeten te allen tijde voldoen aan:

(a) De Wet personenvervoer 2000 (WP2000) en alle ondergeschikte wetgeving inclusief het Besluit personenvervoer 2000 (BP2000);
(b) Alle voorwaarden verbonden aan hun Taxivergunning en Chauffeurskaart;
(c) Alle toepasselijke gemeentelijke taxiregels, inclusief eventuele lokale taxiverordeningen in de steden waarin zij opereren;
(d) Alle toepasselijke verkeerswetten en wegvervoerregelgeving;
(e) De vereisten van de Arbeidstijdenwet met betrekking tot werktijden en rustperiodes;
(f) Alle toepasselijke belastingwetten, inclusief BTW-verplichtingen (indien van toepassing) en inkomstenbelastingverplichtingen onder de Wet inkomstenbelasting 2001;
(g) De AVG en toepasselijke Nederlandse privacywetgeving met betrekking tot enige persoonsgegevens verwerkt tijdens de levering van vervoersdiensten.

4.2 Nauwkeurigheid van Profielinformatie. Chauffeurs moeten ervoor zorgen dat alle informatie op hun Chauffeursprofiel — inclusief voertuigdetails, kentekennummer, servicegebied, prijzen en beschikbaarheid — nauwkeurig, waarheidsgetrouw en actueel is. Chauffeurs moeten hun Profiel onmiddellijk bijwerken wanneer enige informatie wijzigt.

4.3 Professioneel Gedrag. Chauffeurs moeten zich te allen tijde professioneel en hoffelijk gedragen bij interacties met Passagiers via of in verband met het Platform.

4.4 Prijstransparantie. Chauffeurs bepalen hun eigen tarieven. Tarieven weergegeven op een Chauffeursprofiel moeten de daadwerkelijke tarieven zijn die de Chauffeur hanteert. Chauffeurs mogen zich niet bezighouden met misleidende prijspraktijken, inclusief het hanteren van tarieven die materieel verschillen van die weergegeven op hun Profiel zonder voorafgaande overeenkomst met de Passagier.

4.5 Anti-Discriminatie. Chauffeurs mogen weigeren om diensten te verlenen aan enige Passagier op basis van ras, etniciteit, nationaliteit, religie, geslacht, handicap, seksuele oriëntatie, leeftijd, of enig ander kenmerk beschermd onder Nederlands recht, inclusief de Algemene wet gelijke behandeling.

4.6 Non-Solicitatie. Chauffeurs mogen geen contactgegevens of persoonsgegevens verkregen via het Platform gebruiken om Passagiers te benaderen voor diensten buiten het Platform op een manier die het doel van het Platform ondermijnt of toepasselijke wetgeving schendt.

4.7 Verboden Gedrag. Chauffeurs mogen niet:

(a) Hun taxivoertuig exploiteren zonder geldige verzekering, een geldige Chauffeurskaart, of een geldige Taxivergunning;
(b) Enige persoon andere dan zichzelf (of een werknemer of onderaannemer die alle vereiste credentials bezit) toestaan om een voertuig te besturen vermeld op hun Chauffeursprofiel;
(c) Het Platform gebruiken om zich bezighouden met enige frauduleuze, misleidende of bedrieglijke activiteit;
(d) Content uploaden die onwaar, lasterlijk, intimiderend, beledigend, obsceen, discriminerend of anderszins onwettelijk is;
(e) Omzeilen, uitschakelen, of interfereren met enige beveiligingsfuncties van het Platform;
(f) Reverse-engineeren, decompileren, of disassembleren van enig onderdeel van de Platformsoftware.

ARTIKEL 5 — PASSAGIERSVERPLICHTINGEN
5.1 Eerlijk Gebruik. Passagiers moeten het Platform eerlijk en te goeder trouw gebruiken. Passagiers mogen het Platform niet gebruiken om zich bezighouden met enige frauduleuze, misbruikende of onwettige activiteit.

5.2 Respectvol Gedrag. Passagiers moeten Chauffeurs met respect behandelen en mogen Chauffeurs op geen enkele wijze lastigvallen, bedreigen of misbruiken.

5.3 Nauwkeurige Informatie. Waar Passagiers informatie verstrekken aan het Platform (zoals contactgegevens of ophaallocatie), moet die informatie nauwkeurig zijn.

5.4 Directe Relatie. Passagiers erkennen dat hun vervoer wordt verstrekt door een zelfstandige Chauffeur en dat hun contractuele relatie voor de vervoersdienst uitsluitend is met die Chauffeur, niet met HeyCaby.

ARTIKEL 6 — CONTENT EN INTELLECTUELE EIGENDOM
6.1 Gebruikerscontent. U behoudt eigendom van enige Content die u uploadt naar het Platform. Door Content te uploaden, verleent u HeyCaby een niet-exclusieve, royaltyvrije, wereldwijde licentie om die Content te gebruiken, weer te geven, te reproduceren en te distribueren uitsluitend voor de doeleinden van het exploiteren en verbeteren van het Platform.

6.2 Contentnormen. U mag geen Content uploaden die:

(a) Onwaar, misleidend of bedrieglijk is;
(b) Inbreuk maakt op intellectuele eigendomsrechten van derden;
(c) Persoonsgegevens van derden bevat zonder hun toestemming;
(d) Lasterlijk, intimiderend, discriminerend of obsceen is;
(e) Illegale activiteiten promoot;
(f) Malware, virussen of andere schadelijke code bevat.

6.3 HeyCaby Intellectuele Eigendom. Het Platform, inclusief alle software, ontwerp, handelsmerken, logo's en content gemaakt door HeyCaby, is beschermd door intellectuele eigendomsrecht. U mag het intellectuele eigendom van HeyCaby niet gebruiken, kopiëren, wijzigen of distribueren zonder uitdrukkelijke schriftelijke toestemming.

6.4 Contentverwijdering. HeyCaby behoudt zich het recht voor om enige Content te verwijderen die deze Voorwaarden of toepasselijke wetgeving schendt, in overeenstemming met haar verplichtingen onder de Digital Services Act.

ARTIKEL 7 — PLATFORMBESCHIKBAARHEID EN WIJZIGINGEN
7.1 Geen Uptime-garantie. HeyCaby verstrekt het Platform "as is" en "as available". HeyCaby garandeert geen ononderbroken of foutloze toegang tot het Platform. HeyCaby kan het Platform of enige functie daarvan te allen tijde schorsen, wijzigen of stopzetten, met of zonder kennisgeving.

7.2 Onderhoud. HeyCaby kan het Platform offline nemen voor onderhoud. HeyCaby zal proberen voorafgaande kennisgeving te geven van gepland onderhoud maar is hiertoe niet verplicht.

7.3 Wijzigingen aan het Platform. HeyCaby kan functies toevoegen, wijzigen of verwijderen van het Platform te allen tijde. Materiële wijzigingen die van invloed zijn op Chauffeurstoegangstarieven worden gecommuniceerd met ten minste 30 dagen van tevoren.

ARTIKEL 8 — PLATFORMBALANS, BETALING EN GEPAUZEERDE RITVERZOEKEN
8.1 Platformbalans. Chauffeurs kunnen HeyCaby gebruiken zonder vooraf in de app te betalen. HeyCaby kan een openstaande Platformbalans aanmaken voor elke actieve 7-daagse werkperiode. De standaard wekelijkse Platformbalans is €50, exclusief 21% BTW, tenzij een aparte schriftelijke chauffeursovereenkomst anders bepaalt.

8.2 Wanneer Een Balans Verschuldigd Wordt. Een Platformbalans wordt alleen aangemaakt nadat de relevante 7-daagse werkperiode is gestart of voltooid volgens de factureringsregels van HeyCaby. HeyCaby kan een betaaltermijn geven voordat nieuwe ritverzoeken worden gepauzeerd.

8.3 Effect Van Een Openstaande Balans. Als een Platformbalans na de betaaltermijn open blijft, kan HeyCaby nieuwe ritverzoeken voor die chauffeur tijdelijk pauzeren. De chauffeur behoudt toegang tot zijn account, documenten, balansgeschiedenis, ondersteuning en andere functies voor accountbeheer.

8.4 Geen Langdurig Plan. HeyCaby vereist geen langdurig plan. De Platformbalans is gekoppeld aan 7-daagse werkperiodes. Chauffeurs kunnen stoppen met het gebruiken van het Platform voordat een toekomstige periode start.

8.5 Vereffening. Chauffeurs vereffenen een openstaande Platformbalans via de betaalmethoden die HeyCaby of haar betaalpartners beschikbaar maken. Bankoverschrijvingen kunnen een betalingsreferentie vereisen zodat HeyCaby de betaling kan herkennen. Betalingen kunnen tijd nodig hebben voordat ze in de balans zichtbaar zijn.

8.6 Verlies Van Voorkeursstatus. Elke voorkeursstatus van een chauffeur is voorwaardelijk en kan verloren gaan. Een chauffeur kan zo'n status verliezen als deze: (a) platformregels overtreedt; (b) niet op tijd betaalt; (c) gedurende een langere periode inactief blijft; (d) niet langer geldige juridische documenten, vergunningen, verzekeringen of vereiste taxicredentials onderhoudt; of (e) het platform misbruikt, oneigenlijk gebruikt of probeert te manipuleren.

8.7 Toekomstige Prijzen. HeyCaby kan de wekelijkse Platformbalans of toegangstarieven voor toekomstige werkperiodes wijzigen. Materiele wijzigingen die van invloed zijn op Chauffeurstoegangstarieven worden met ten minste 30 dagen vooraf gecommuniceerd waar wet of contract dit vereist.

8.8 Betalingsverwerking. Betalingen worden verwerkt door Mollie B.V., een externe betalingsdienstaanbieder gevestigd in Nederland. Door een betaling te verrichten, gaat u ermee akkoord gebonden te zijn aan de toepasselijke algemene voorwaarden van Mollie. Mollie kan betalingsgerelateerde data verwerken als onafhankelijke verwerkingsverantwoordelijke in overeenstemming met haar eigen privacybeleid. HeyCaby slaat geen betaalkaartgegevens op of verwerkt deze op haar eigen servers.

8.9 Passagiersdiensten. Passagiers hebben gratis toegang tot het Platform. HeyCaby verwerkt geen betalingen voor taxiritten. Betaling voor taxidiensten vindt direct plaats tussen de Passagier en de Chauffeur.

8.10 BTW en Belasting. Chauffeurs zijn uitsluitend verantwoordelijk voor alle belastingverplichtingen voortvloeiend uit hun gebruik van het Platform en uit de taxidiensten die zij verlenen. HeyCaby kan BTW-facturen uitreiken voor Chauffeurstoegangstarieven waar vereist door wetgeving. Het Chauffeurstoegangstarief vormt geen inkomen van de Chauffeur; het is een zakelijke toolkost die aftrekbaar kan zijn voor ZZP-chauffeurs. Chauffeurs dienen een belastingadviseur te raadplegen met betrekking tot hun specifieke situatie.

ARTIKEL 9 — BEPERKING VAN AANSPRAKELIJKHEID
9.1 HeyCaby's Uitsluiting van Aansprakelijkheid voor Vervoersdiensten. Voor zover maximaal toegestaan door dwingend toepasselijk recht:

(a) HeyCaby is niet aansprakelijk voor enig verlies, schade, letsel, overlijden, vertraging, of andere schade voortvloeiend uit of in verband met enige taxirit georganiseerd via het Platform. Alle aansprakelijkheid voor vervoersdiensten rust uitsluitend bij de Chauffeur die deze diensten verleent;
(b) HeyCaby is niet aansprakelijk voor het falen van enige Chauffeur om geldige credentials, verzekering, of enig vereist rijbewijs of vergunning te bezitten;
(c) HeyCaby is niet aansprakelijk voor het gedrag van enige Chauffeur tijdens een taxirit, inclusief maar niet beperkt tot nalatig rijden, ongevallen, diefstal, of persoonlijk letsel;
(d) HeyCaby is niet aansprakelijk voor het gedrag van enige Passagier jegens een Chauffeur;
(e) HeyCaby is niet aansprakelijk voor de nauwkeurigheid of volledigheid van informatie verstrekt door Chauffeurs of Passagiers op het Platform.

9.2 Beperking van Platformaansprakelijkheid. Voor zover maximaal toegestaan door dwingend toepasselijk recht, zal de totale gezamenlijke aansprakelijkheid van HeyCaby aan enige Gebruiker voor enige claims voortvloeiend uit of in verband met de Platformdiensten (als onderscheiden van vervoersdiensten) niet meer bedragen dan de totale Chauffeurstoegangstarieven betaald door die Gebruiker in de drie maanden voorafgaand aan de claim.

9.3 Uitsluiting van Gevolgschade. Voor zover maximaal toegestaan door dwingend toepasselijk recht, is HeyCaby niet aansprakelijk voor enige indirecte, incidentele, speciale, gevolg- of strafschade, inclusief winstderving, gegevensverlies, goodwillverlies, of bedrijfsonderbreking, voortvloeiend uit of in verband met het Platform of deze Voorwaarden.

9.4 Dwingende Consumentenrechten. Niets in deze Voorwaarden beperkt of sluit enige aansprakelijkheid uit die niet kan worden beperkt of uitgesloten onder dwingend Nederlands recht, inclusief aansprakelijkheid voor overlijden of persoonlijk letsel veroorzaakt door eigen grove nalatigheid of opzettelijke verwijtbaarheid van HeyCaby, of enige rechten die consumenten niet kunnen worden ontnomen onder Nederlandse consumentenbeschermingswetgeving.

9.5 Overmacht. HeyCaby is niet aansprakelijk voor enige tekortkoming of vertraging in prestatie veroorzaakt door omstandigheden buiten haar redelijke controle, inclusief maar niet beperkt tot natuurrampen, oorlog, terrorisme, pandemieën, overheidsmaatregelen, stroomuitval, of telecommunicatiestoringen.

ARTIKEL 10 — VRIJWARING DOOR CHAUFFEURS
10.1 Vrijwaringsverplichting Chauffeur. Chauffeurs stemmen ermee in om HeyCaby, haar bestuurders, functionarissen, werknemers, contractanten en agenten ("HeyCaby-partijen") te vrijwaren, verdedigen en schadeloos te stellen van en tegen alle claims, schade, verliezen, aansprakelijkheden, kosten en uitgaven (inclusief redelijke juridische kosten) voortvloeiend uit of in verband met:

(a) Enige door een Chauffeur verleende taxidienst, inclusief enig ongeval, letsel, overlijden, of eigendomsschade plaatsvindend tijdens of in verband met een taxirit;
(b) Enig falen van een Chauffeur om een vereist rijbewijs, vergunning, verzekering, of credential te bezitten, onderhouden of naleven, inclusief maar niet beperkt tot de Chauffeurskaart, Taxivergunning, of WAM-verzekering;
(c) Enige overtreding door een Chauffeur van deze Gebruiksvoorwaarden;
(d) Enige overtreding door een Chauffeur van enige toepasselijke wet of regelgeving;
(e) Enige Content geüpload door een Chauffeur die inbreuk maakt op enig recht van derden of enige toepasselijke wet schendt;
(f) Enige claim door een Passagier of enige derde voortvloeiend uit het gedrag van een Chauffeur.

Opmerking: Het zelfstandige Vrijwarings- en Aansprakelijkheidsverklaringsdocument, dat Chauffeurs afzonderlijk ondertekenen bij registratie, beschrijft de volledige voorwaarden van deze vrijwaringsverplichting.

ARTIKEL 11 — SCHORSING EN BEËINDIGING
11.1 Recht van HeyCaby om te Schorsen of Beëindigen. HeyCaby kan enig Gebruiker-account schorsen of permanent beëindigen, met of zonder voorafgaande kennisgeving, indien:

(a) De Gebruiker deze Gebruiksvoorwaarden schendt;
(b) HeyCaby geloofwaardig bewijs ontvangt dat een Chauffeur opereert zonder geldige vereiste credentials;
(c) HeyCaby geloofwaardig bewijs ontvangt van frauduleus, misleidend, gevaarlijk of illegaal gedrag;
(d) Een 7-daags toegangstarief van een Chauffeur niet wordt betaald en niet binnen 7 dagen wordt hersteld;
(e) HeyCaby hiertoe wordt verplicht door toepasselijke wetgeving of gerechtelijk bevel;
(f) HeyCaby bepaalt, naar haar redelijk oordeel, dat de aanwezigheid van de Gebruiker op het Platform een risico vormt voor andere Gebruikers of voor HeyCaby.

11.2 Kennisgeving van Schorsing. Voor zover haalbaar en niet verhinderd door wetshandhavingsoverwegingen, zal HeyCaby een Chauffeur op de hoogte stellen voordat zijn account wordt geschorst en zal een redelijke mogelijkheid tot reactie bieden. Deze verplichting geldt niet in gevallen van onmiddellijk veiligheidsrisico of wettelijke verplichting.

11.3 Recht van Gebruiker om te Beëindigen. U kunt uw account te allen tijde beëindigen via de Platform-instellingen. Chauffeurstoegangstarieven die al zijn betaald, zijn niet-restitueerbaar zoals bepaald in artikel 8.5.

11.4 Effect van Beëindiging. Bij beëindiging van uw account, houdt uw recht op toegang tot het Platform onmiddellijk op. HeyCaby zal uw persoonsgegevens bewaren en verwerken in overeenstemming met haar Privacybeleid en toepasselijke wetgeving.

ARTIKEL 12 — GESCHILLENBESLECHTING
12.1 Klachten. Als u een klacht heeft over het Platform, neem dan eerst contact op met HeyCaby-support via support@heycaby.nl. HeyCaby zal redelijke inspanningen leveren om klachten binnen 14 dagen op te lossen.

12.2 Consumentenbemiddeling. Als u een consument bent en uw klacht niet direct met HeyCaby kan worden opgelost, kunt u mogelijk het recht hebben om uw klacht voor te leggen aan de Geschillencommissie of andere toepasselijke consumentengeschillenbeslechtingsorganen, of aan het Europese Online Geschillenbeslechtingsplatform op https://ec.europa.eu/consumers/odr.

12.3 Chauffeurgeschillen. Geschillen tussen HeyCaby en Chauffeurs die niet kunnen worden opgelost door goede trouw onderhandelingen, worden voorgelegd aan de exclusieve jurisdictie van de bevoegde rechtbank in Rotterdam, Nederland.

12.4 Passagier-Chauffeurgeschillen. Geschillen tussen Passagiers en Chauffeurs met betrekking tot taxidiensten zijn uitsluitend tussen de Passagier en de Chauffeur. HeyCaby is geen bemiddelaar en is niet verantwoordelijk voor het beslechten van dergelijke geschillen. HeyCaby kan, naar haar eigen goeddunken, een Chauffeur verwijderen van het Platform die het onderwerp is van meerdere geloofwaardige klachten van Passagiers.

12.5 Toepasselijk Recht. Deze Voorwaarden worden beheerst door Nederlands recht. De toepassing van het UN-Verdrag inzake internationale koopovereenkomsten van goederen is uitgesloten.

ARTIKEL 13 — PRIVACY EN GEGEVENSBESCHERMING
13.1 Privacybeleid. HeyCaby verwerkt persoonsgegevens in overeenstemming met haar Privacybeleid, dat deel uitmaakt van deze Voorwaarden en beschikbaar is op https://www.heycaby.nl/privacy. Het Privacybeleid beschrijft welke gegevens worden verzameld, hoe deze worden gebruikt, hoe lang deze worden bewaard, en de rechten van Gebruikers onder de AVG.

13.2 Rol Gegevensverwerking. HeyCaby is de verwerkingsverantwoordelijke voor persoonsgegevens verwerkt via het Platform. Chauffeurs verwerken persoonsgegevens van Passagiers onafhankelijk in hun hoedanigheid van verwerkingsverantwoordelijke voor de doeleinden van het verlenen van vervoersdiensten. Chauffeurs zijn uitsluitend verantwoordelijk voor het waarborgen dat hun eigen gegevensverwerkingsactiviteiten voldoen aan de AVG.

13.3 Beperkte Gegevensgebruik Passagiers. Passagiers kunnen het Platform gebruiken zonder een account, e-mailadres of telefoonnummer aan te maken. HeyCaby kan een tijdelijke sessie-identificator, ophaal- en afzetinformatie, en een weergavenaam van de passagier verwerken waar nodig om een chauffeur aan te vragen en de ritflow te voltooien.

13.4 Externe Dienstverleners. HeyCaby gebruikt de volgende externe diensten om het Platform te exploiteren. Deze providers kunnen persoonsgegevens verwerken als noodzakelijk om hun diensten te leveren:

(a) Supabase (Supabase Inc.) — Databasehosting, authenticatie en opslag (EU-datacentra, regio Frankfurt);
(b) Mollie (Mollie B.V.) — Betalingsverwerking voor Chauffeurstoegangstarieven;
(c) Firebase / Firebase Cloud Messaging (Google LLC) — pushnotificaties;
(d) Veriff (Veriff Identity OÜ) — Identiteitsverificatie en documentcontroles chauffeur;
(e) RDW (Rijksdienst voor het Wegverkeer) — Publieke voertuigregistratiegegevens opzoeken;
(f) KvK (Kamer van Koophandel) — Publieke bedrijfsregistratieverificatie;
(g) Mapbox (Mapbox, Inc.) — Kaarten en locatiediensten;
(h) AI-ondersteuningsassistent — Geautomatiseerde supportchat aangedreven door externe AI-providers (inclusief OpenAI). Berichten kunnen door deze providers worden verwerkt om reacties te genereren. Gebruikers worden duidelijk geïnformeerd voor eerste gebruik en moeten expliciete toestemming geven voordat enige gegevens worden verwerkt door AI-systemen.

Alle externe providers zijn gebonden door gegevensverwerkingsovereenkomsten die AVG-naleving waarborgen. Gegevens worden niet overgedragen buiten de EEA zonder passende waarborgen.

ARTIKEL 14 — KENNISGEVINGEN EN COMMUNICATIE
14.1 Communicatie naar Gebruikers. HeyCaby kan met Gebruikers communiceren via in-app notificatie, e-mail (waar een e-mailadres is verstrekt), of pushnotificatie.

14.2 Communicatie naar HeyCaby. Juridische kennisgevingen aan HeyCaby moeten schriftelijk worden verzonden naar: HeyCaby, Lindenhof, Rotterdam, Nederland, of per e-mail naar legal@heycaby.nl.

14.3 Contactkanalen. HeyCaby onderhoudt verschillende communicatiekanalen voor specifieke doeleinden:

(a) support@heycaby.nl — klantensupport en technische assistentie;
(b) hello@heycaby.nl — algemene vragen en zakelijke communicatie;
(c) qb@heycaby.nl — melden van juridische, regelgevende of veiligheidszorgen;
(d) legal@heycaby.nl — formele juridische kennisgevingen.

ARTIKEL 15 — ALGEMENE BEPALINGEN
15.1 Volledige Overeenkomst. Deze Voorwaarden, samen met het Privacybeleid en de Vrijwarings- en Aansprakelijkheidsverklaring ondertekend door Chauffeurs, vormen de volledige overeenkomst tussen u en HeyCaby met betrekking tot het Platform en vervangen alle eerdere overeenkomsten.

15.2 Scheidbaarheid. Als enige bepaling van deze Voorwaarden ongeldig, illegaal of niet-afdwingbaar wordt bevonden onder toepasselijke wetgeving, zal die bepaling worden gewijzigd in de minste mate noodzakelijk om deze geldig, legaal en afdwingbaar te maken. Alle andere bepalingen blijven volledig van kracht en effect.

15.3 Geen Verklaring van Afstand. Het nalaten van HeyCaby om enig recht of bepaling van deze Voorwaarden af te dwingen, vormt geen verklaring van afstand van dat recht of die bepaling.

15.4 Overdracht. HeyCaby kan haar rechten en verplichtingen onder deze Voorwaarden overdragen aan een opvolger zonder uw toestemming. U mag uw rechten of verplichtingen onder deze Voorwaarden niet overdragen zonder voorafgaande schriftelijke toestemming van HeyCaby.

15.5 Wijzigingen. HeyCaby kan deze Voorwaarden te allen tijde wijzigen. Gewijzigde Voorwaarden zullen worden gecommuniceerd aan Gebruikers via in-app notificatie en e-mail (waar beschikbaar) ten minste 14 dagen voordat de wijzigingen van kracht worden. Voortgezet gebruik van het Platform na de ingangsdatum vormt acceptatie van de gewijzigde Voorwaarden. Als u de wijzigingen niet accepteert, moet u stoppen met het gebruik van het Platform en uw account beëindigen vóór de ingangsdatum.

15.6 Taal. Deze Voorwaarden zijn beschikbaar in het Engels en Nederlands. In geval van enige discrepantie, prevaleert de Engelse versie.

ARTIKEL 16 — ERKENNING EN AFWIJZING CLAIMS
16.1 Uitdrukkelijke Erkenning. Door het HeyCaby-platform te gebruiken, erkent u uitdrukkelijk dat:

(a) U de gelegenheid hebt gehad om deze Gebruiksvoorwaarden volledig te lezen;
(b) U de gelegenheid hebt gehad om de Vrijwarings- en Aansprakelijkheidsverklaring volledig te lezen;
(c) U uw rechten en verplichtingen onder beide documenten begrijpt.

16.2 Afwijzing van Claims. U doet afstand van elke claim dat u niet op de hoogte was van de inhoud van deze documenten, dat u ze niet begreep, of dat u niet voldoende gelegenheid had om ze te reviewen.

16.3 Bevestiging van Binding. Door het platform te blijven gebruiken, bevestigt u:

Ik heb de Gebruiksvoorwaarden en de Vrijwarings- en Aansprakelijkheidsverklaring gelezen en ga ermee akkoord.

HeyCaby — 42021548 — Lindenhof, Rotterdam, Nederland
Laatst bijgewerkt: 1 mei 2026 — Versie 1.0''';

class DriverIndemnificationScreen extends ConsumerStatefulWidget {
  const DriverIndemnificationScreen({super.key});

  @override
  ConsumerState<DriverIndemnificationScreen> createState() =>
      _DriverIndemnificationScreenState();
}

class _DriverIndemnificationScreenState
    extends ConsumerState<DriverIndemnificationScreen> {
  bool _isDutch = false;
  bool _hasManualLanguageChoice = false;
  bool _isChecked = false;

  void _syncDocumentLanguage() {
    if (_hasManualLanguageChoice) return;
    final locale = ref.watch(localeProvider);
    _isDutch = locale == null || locale.languageCode == 'nl';
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  String get _fullDocumentText => _isDutch ? _fullTermsNl : _fullTermsEn;

  String get _title =>
      _isDutch ? 'Vrijwaringsverklaring' : 'Indemnification Declaration';

  String get _fullText => _fullDocumentText;

  String get _checkboxText => _isDutch
      ? 'Ik heb de Gebruiksvoorwaarden en de Vrijwarings- en Aansprakelijkheidsverklaring gelezen en ga ermee akkoord.'
      : 'I have read and agree to the Terms of Service and the Indemnification & Liability Declaration.';

  String get _waiverText => _isDutch
      ? 'U doet afstand van elke claim dat u niet op de hoogte was van de inhoud van deze documenten, dat u ze niet begreep, of dat u niet voldoende gelegenheid had om ze te reviewen.'
      : 'You waive any claim that you were not aware of the contents of these documents, that you did not understand them, or that you did not have adequate opportunity to review them.';

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.copiedToClipboard)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    _syncDocumentLanguage();

    return DriverLiabilityAcknowledgmentBody(
      title: _title,
      colors: colors,
      typography: typography,
      documentText: _fullDocumentText,
      waiverText: _waiverText,
      checkboxText: _checkboxText,
      isDutch: _isDutch,
      isChecked: _isChecked,
      onBack: _handleBack,
      onSelectEnglish: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = false;
      }),
      onSelectDutch: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = true;
      }),
      onToggleLanguage: () => setState(() {
        _hasManualLanguageChoice = true;
        _isDutch = !_isDutch;
      }),
      onCopy: _copyToClipboard,
      onCheckedChanged: (checked) => setState(() => _isChecked = checked),
    );
  }
}
