"use client";

import Image from "next/image";
import { useEffect, useState, type CSSProperties } from "react";
import type { Locale } from "./copy";
import { PhoneMapCanvas } from "./phone-map-canvas";

const sceneCopy = {
  nl: { stages: [["Rit bevestigd","Je chauffeur is onderweg","4 min","Tesla Model Y · HC-24-XY"],["Bijna bij je","Maak je klaar voor vertrek","1 min","Je chauffeur nadert het ophaalpunt"],["Chauffeur is er","Sam staat buiten","Nu","Witte Tesla · HC-24-XY"],["Onderweg","Veilig op weg naar huis","18 min","Deel je rit live met familie"]], verified:"Geverifieerde chauffeur · 4,9 ★", share:"Deel rit", message:"Bericht", safety:"Veiligheid", today:"Vandaag", keeps:"100% van jouw ritprijzen", online:"Je bent online", pause:"Pauze", incoming:"Nieuwe ritten komen direct binnen", breathe:"Neem even de tijd", resume:"Hervat", rate:"Jouw tarief", rides:"Ritten", commission:"Commissie", return:"Taxi Terug", returnBody:"Verdien onderweg naar huis", activate:"Activeer", remains:"blijft van jou" },
  en: { stages: [["Ride confirmed","Your driver is on the way","4 min","Tesla Model Y · HC-24-XY"],["Almost there","Get ready to leave","1 min","Your driver is approaching pickup"],["Driver arrived","Sam is outside","Now","White Tesla · HC-24-XY"],["On the way","Heading home safely","18 min","Share your live ride with family"]], verified:"Verified driver · 4.9 ★", share:"Share ride", message:"Message", safety:"Safety", today:"Today", keeps:"100% of your fares", online:"You are online", pause:"Break", incoming:"New ride requests arrive instantly", breathe:"Take a moment", resume:"Resume", rate:"Your rate", rides:"Rides", commission:"Commission", return:"Taxi Terug", returnBody:"Earn on your way home", activate:"Activate", remains:"stays yours" },
  ar: { stages: [["تم تأكيد الرحلة","سائقك في الطريق","٤ د","Tesla Model Y · HC-24-XY"],["اقترب السائق","استعد للمغادرة","١ د","السائق يقترب من نقطة الالتقاء"],["وصل السائق","سام في الخارج","الآن","Tesla بيضاء · HC-24-XY"],["في الطريق","في طريق آمن إلى المنزل","١٨ د","شارك رحلتك مباشرة مع العائلة"]], verified:"سائق موثّق · ٤٫٩ ★", share:"مشاركة الرحلة", message:"رسالة", safety:"الأمان", today:"اليوم", keeps:"١٠٠٪ من أجور رحلاتك", online:"أنت متصل", pause:"استراحة", incoming:"تصلك الرحلات الجديدة فورًا", breathe:"خذ استراحة", resume:"متابعة", rate:"سعرك", rides:"الرحلات", commission:"العمولة", return:"تاكسي العودة", returnBody:"اكسب في طريق العودة", activate:"تفعيل", remains:"تبقى لك" },
} as const;

function AppChrome({ children, label }: { children: React.ReactNode; label: string }) {
  return (
    <div className="device" aria-label={label}>
      <div className="device-top"><span>9:41</span><i /><b>● ●</b></div>
      <div className="device-screen">{children}</div>
      <div className="home-indicator" />
    </div>
  );
}

export function RiderJourneyScene({ compact = false, locale }: { compact?: boolean; locale: Locale }) {
  const [stage, setStage] = useState(0);
  useEffect(() => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timer = setInterval(() => setStage((value) => (value + 1) % 4), 2800);
    return () => clearInterval(timer);
  }, []);
  const c = sceneCopy[locale];
  const current = c.stages[stage];

  return (
    <div className={`scene-wrap rider-journey ${compact ? "compact" : ""}`}>
      <AppChrome label="Animated HeyCaby rider journey">
        <PhoneMapCanvas />
        <div className="journey-sheet" key={stage}>
          <div className="sheet-handle" />
          <div className="live-label"><i />{current[0]}</div>
          <div className="journey-head"><div><small>HEY CABY</small><h3>{current[1]}</h3></div><strong>{current[2]}</strong></div>
          <p>{current[3]}</p>
          <div className="driver-mini"><span className="avatar">S</span><div><b>Sam</b><small>{c.verified}</small></div><span className="shield">✓</span></div>
          <div className="journey-progress">{c.stages.map((item, index) => <i key={item[0]} className={index <= stage ? "active" : ""} />)}</div>
          <div className="quick-actions"><button>{c.share}</button><button>{c.message}</button><button>{c.safety}</button></div>
        </div>
      </AppChrome>
      <div className="orbit-chip one">{locale === "ar" ? "وصول مباشر" : "Live ETA"}</div><div className="orbit-chip two">{locale === "ar" ? "موثّق" : locale === "en" ? "Verified" : "Geverifieerd"}</div>
    </div>
  );
}

export function DriverControlScene({ locale }: { locale: Locale }) {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timer = setInterval(() => setOnline((value) => !value), 3600);
    return () => clearInterval(timer);
  }, []);

  const c = sceneCopy[locale];
  return (
    <div className="scene-wrap driver-control">
      <AppChrome label="Animated HeyCaby driver control centre">
        <PhoneMapCanvas />
        <div className="driver-status"><span>{c.today}</span><strong>€ 286,40</strong><small>{c.keeps}</small></div>
        <div className="cockpit-sheet">
          <div className="sheet-handle" />
          <div className="online-row"><div><i className={online ? "on" : ""} /><b>{online ? c.online : c.pause}</b><small>{online ? c.incoming : c.breathe}</small></div><button onClick={() => setOnline(!online)}>{online ? "Online" : c.resume}</button></div>
          <div className="metric-row"><div><small>{c.rate}</small><b>€ 2,35/km</b></div><div><small>{c.rides}</small><b>8</b></div><div><small>{c.commission}</small><b>€ 0</b></div></div>
          <div className="return-card"><span>↩</span><div><b>{c.return}</b><small>{c.returnBody}</small></div><em>{c.activate}</em></div>
        </div>
      </AppChrome>
      <div className="earnings-burst"><strong>100%</strong><span>{c.remains}</span></div>
    </div>
  );
}

const safetyStepVisuals = {
  A: {
    src: "/safety/safety-step-a-book-clearly.png",
    alt: {
      nl: "Boek helder — prijs, route en ophaalpunt vooraf zichtbaar",
      en: "Book clearly — price, route and pickup visible upfront",
      ar: "احجز بوضوح — السعر والمسار ونقطة الالتقاء واضحة مسبقًا",
    },
  },
  B: {
    src: "/safety/safety-step-b-know-driver.png",
    alt: {
      nl: "Ken je chauffeur — foto, voertuig, kenteken en beoordeling",
      en: "Know your driver — photo, vehicle, plate and rating",
      ar: "اعرف سائقك — الصورة والسيارة واللوحة والتقييم",
    },
  },
  C: {
    src: "/safety/safety-step-c-follow-live.png",
    alt: {
      nl: "Volg live — positie en aankomsttijd bewegen mee",
      en: "Follow live — position and ETA update with the ride",
      ar: "تابع مباشرة — الموقع ووقت الوصول يتحدثان مع الرحلة",
    },
  },
  D: {
    src: "/safety/safety-step-d-stay-connected.png",
    alt: {
      nl: "Blijf verbonden — deel je rit en bereik hulp",
      en: "Stay connected — share your ride and reach help",
      ar: "ابقَ متصلًا — شارك رحلتك واطلب المساعدة",
    },
  },
  E: {
    src: "/safety/safety-step-e-arrive-assured.png",
    alt: {
      nl: "Kom zeker aan — aankomst en ritdetails bevestigd",
      en: "Arrive assured — arrival and trip details confirmed",
      ar: "صِل بثقة — تأكيد الوصول وتفاصيل الرحلة",
    },
  },
} as const;

export function SafetySequence({ locale }: { locale: Locale }) {
  const steps = locale === "ar" ? [["A","احجز بوضوح","السعر والمسار ونقطة الالتقاء واضحة مسبقًا."],["B","اعرف سائقك","الصورة والسيارة واللوحة والتقييم."],["C","تابع مباشرة","الموقع ووقت الوصول يتحدثان مع الرحلة."],["D","ابقَ متصلًا","شارك رحلتك واطلب المساعدة من مكان واحد."],["E","صِل بثقة","تأكيد الوصول وتفاصيل الرحلة."]] : locale === "en" ? [["A","Book clearly","Price, route and pickup are clear before you ride."],["B","Know your driver","Photo, vehicle, plate and rating."],["C","Follow live","Position and ETA move with the ride."],["D","Stay connected","Share your ride and reach help in one place."],["E","Arrive assured","Arrival and trip details are confirmed."]] : [
    ["A", "Boek helder", "Prijs, route en ophaalpunt vooraf duidelijk."],
    ["B", "Ken je chauffeur", "Foto, voertuig, kenteken en beoordeling."],
    ["C", "Volg live", "ETA en positie bewegen mee met de rit."],
    ["D", "Blijf verbonden", "Deel je rit en bereik hulp vanuit één plek."],
    ["E", "Kom zeker aan", "Aankomst en ritdetails worden bevestigd."],
  ];
  return (
    <div className="safety-sequence">
      {steps.map(([letter, title, body], index) => {
        const visual = safetyStepVisuals[letter as keyof typeof safetyStepVisuals];
        return (
          <article
            key={letter}
            style={{ "--delay": `${index * 90}ms` } as CSSProperties}
          >
            <span>{letter}</span>
            <div className="safety-icon">
              <Image
                className="safety-icon__image"
                src={visual.src}
                alt={visual.alt[locale]}
                width={120}
                height={120}
                sizes="120px"
              />
            </div>
            <h3>{title}</h3>
            <p>{body}</p>
          </article>
        );
      })}
    </div>
  );
}

const driverBenefitVisuals = [
  {
    src: "/driver-benefits/driver-benefit-01-go-online.png",
    alt: {
      nl: "Zet jezelf online — werk wanneer jij wilt",
      en: "Go online your way — work when you want",
      ar: "اتصل بطريقتك — اعمل عندما تريد",
    },
  },
  {
    src: "/driver-benefits/driver-benefit-02-set-rate.png",
    alt: {
      nl: "Bepaal jouw tarief — jouw prijs, jouw kilometers",
      en: "Set your own rate — your price, your business",
      ar: "حدد سعرك — عملك وسعرك",
    },
  },
  {
    src: "/driver-benefits/driver-benefit-03-taxi-terug.png",
    alt: {
      nl: "Verdien op de terugweg — Taxi Terug op jouw route",
      en: "Earn on the way home — Taxi Terug on your route",
      ar: "اكسب في طريق العودة — تاكسي العودة على مسارك",
    },
  },
] as const;

export function DriverBenefitsGrid({
  benefits,
  locale,
}: {
  benefits: [string, string][];
  locale: Locale;
}) {
  return (
    <div className="driver-benefits">
      {benefits.map(([title, body], index) => {
        const visual = driverBenefitVisuals[index];
        return (
          <article key={title}>
            <span>{`0${index + 1}`}</span>
            {visual ? (
              <div className="driver-benefit-icon">
                <Image
                  className="driver-benefit-icon__image"
                  src={visual.src}
                  alt={visual.alt[locale]}
                  width={120}
                  height={120}
                  sizes="120px"
                />
              </div>
            ) : null}
            <h3>{title}</h3>
            <p>{body}</p>
          </article>
        );
      })}
    </div>
  );
}
