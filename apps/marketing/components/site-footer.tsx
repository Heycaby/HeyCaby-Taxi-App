import type { Locale } from "./copy";

const footerCopy = {
  nl: {
    tagline: "Nederlands taxiplatform · Gebouwd door chauffeurs",
    blurb:
      "Eerlijk voor chauffeurs. Vertrouwd voor rijders. 0% commissie op ritten — chauffeurs houden 100% van de ritprijs.",
    product: "Product",
    riders: "Voor rijders",
    drivers: "Voor chauffeurs",
    why: "Waarom HeyCaby",
    download: "Download",
    help: "Help",
    faq: "FAQ & support",
    contact: "Contact",
    legal: "Juridisch",
    terms: "Algemene voorwaarden",
    privacy: "Privacyverklaring",
    disclaimer: "Vrijwaring",
    founding: "Founding Member contract",
    rights: "Alle rechten voorbehouden",
  },
  en: {
    tagline: "Dutch taxi platform · Built by drivers",
    blurb:
      "Fair for drivers. Trusted for riders. 0% ride commission — drivers keep 100% of every fare.",
    product: "Product",
    riders: "For riders",
    drivers: "For drivers",
    why: "Why HeyCaby",
    download: "Download",
    help: "Help",
    faq: "FAQ & support",
    contact: "Contact",
    legal: "Legal",
    terms: "Terms of service",
    privacy: "Privacy policy",
    disclaimer: "Disclaimer",
    founding: "Founding Member contract",
    rights: "All rights reserved",
  },
  ar: {
    tagline: "منصة تاكسي هولندية · بناها السائقون",
    blurb:
      "عدل للسائقين. ثقة للركاب. 0% عمولة — يحتفظ السائقون بـ 100% من الأجرة.",
    product: "المنتج",
    riders: "للركاب",
    drivers: "للسائقين",
    why: "لماذا HeyCaby",
    download: "تنزيل",
    help: "المساعدة",
    faq: "الأسئلة الشائعة والدعم",
    contact: "تواصل",
    legal: "قانوني",
    terms: "الشروط العامة",
    privacy: "سياسة الخصوصية",
    disclaimer: "إخلاء المسؤولية",
    founding: "عقد العضو المؤسس",
    rights: "جميع الحقوق محفوظة",
  },
} as const;

export function SiteFooter({ locale }: { locale: Locale }) {
  const f = footerCopy[locale];
  const year = new Date().getFullYear();

  return (
    <footer className="site-footer">
      <div className="site-footer__shell section-shell">
        <div className="site-footer__grid">
          <div className="site-footer__brand">
            <a className="brand" href="#top">
              <span>Hey</span>
              <b>Caby</b>
            </a>
            <p className="site-footer__tagline">{f.tagline}</p>
            <p className="site-footer__blurb">{f.blurb}</p>
            <a className="site-footer__email" href="mailto:support@heycaby.nl">
              support@heycaby.nl
            </a>
          </div>

          <div className="site-footer__col">
            <h3>{f.product}</h3>
            <ul>
              <li>
                <a href="#ritten">{f.riders}</a>
              </li>
              <li>
                <a href="#chauffeurs">{f.drivers}</a>
              </li>
              <li>
                <a href="#waarom">{f.why}</a>
              </li>
              <li>
                <a href="#download">{f.download}</a>
              </li>
            </ul>
          </div>

          <div className="site-footer__col">
            <h3>{f.help}</h3>
            <ul>
              <li>
                <a href="/support#faq">{f.faq}</a>
              </li>
              <li>
                <a href="/support">{f.contact}</a>
              </li>
              <li>
                <a href="mailto:support@heycaby.nl">support@heycaby.nl</a>
              </li>
            </ul>
          </div>

          <div className="site-footer__col">
            <h3>{f.legal}</h3>
            <ul>
              <li>
                <a href="/chauffeur/voorwaarden">{f.terms}</a>
              </li>
              <li>
                <a href="/privacy">{f.privacy}</a>
              </li>
              <li>
                <a href="/chauffeur/vrijwaring">{f.disclaimer}</a>
              </li>
              <li>
                <a href="/chauffeur/founding-member-contract">{f.founding}</a>
              </li>
            </ul>
          </div>
        </div>

        <div className="site-footer__bar">
          <p>
            © {year} HeyCaby B.V. · {f.rights}
          </p>
        </div>
      </div>
    </footer>
  );
}
