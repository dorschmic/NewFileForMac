/* NewFileForMac – Website: Interaktion & Scroll-Animationen (GSAP + ScrollTrigger + Lenis) */
(() => {
  'use strict';

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const hasGsap = typeof window.gsap !== 'undefined' && typeof window.ScrollTrigger !== 'undefined';

  /* ---------------- Daten (aus Resources/conversions.json abgeleitet) ---------------- */
  const INPUTS = ['mp4','mov','mkv','webm','avi','m4v','mp3','m4a','wav','flac','aiff','ogg','opus','aac',
    'heic','jpg','png','webp','avif','gif','tiff','psd','dng','cr2','nef','arw',
    'pdf','docx','doc','odt','rtf','xlsx','pptx','epub','html',
    'md','txt','csv','tsv','json','yaml','xml','toml','sh','zsh','py','js','ts','swift','c','cpp','java','go','rs','rb','php','sql','tex','css','log'];

  const CONVERSIONS = [
    ['mp4', 'mp3',  'MP4 → MP3',   'Tonspur aus dem Video ziehen.', 'ffmpeg'],
    ['mov', 'gif',  'MOV → GIF',   'Animiert, 480 px, mit sauberer Farbpalette.', 'ffmpeg'],
    ['heic','jpg',  'HEIC → JPG',  'iPhone-Fotos, die überall aufgehen.', 'sips'],
    ['png', 'webp', 'PNG → WebP',  'Kleiner fürs Web.', 'cwebp'],
    ['md',  'pdf',  'MD → PDF',    'Über HTML zu einem A4-PDF – eine Kette, ein Klick.', 'pandoc + textpdf'],
    ['docx','pdf',  'DOCX → PDF',  'LibreOffice, falls installiert – sonst eingebaut.', 'soffice / textpdf'],
    ['csv', 'docx', 'CSV → DOCX',  'Als echte Tabelle in Word.', 'pandoc'],
    ['sh',  'txt',  'SH → TXT',    'Nur die Endung wechselt, der Inhalt bleibt.', 'copy (eingebaut)'],
    ['pdf', 'txt',  'PDF → TXT',   'Den Text aus dem PDF holen.', 'pdftext (eingebaut)'],
    ['wav', 'flac', 'WAV → FLAC',  'Verlustfrei komprimiert.', 'ffmpeg'],
    ['dng', 'jpg',  'RAW → JPG',   'DNG, CR2, NEF, ARW, RAF, ORF …', 'sips'],
    ['pdf', 'docx', 'PDF → DOCX',  'Bearbeitbar machen – mit LibreOffice.', 'soffice (optional)'],
  ];

  /* ---------------- Inhalte erzeugen ---------------- */
  const docIcon = (ext, cls = '') => `<div class="doc ${cls}" data-ext="${ext}"><b>${ext.toUpperCase()}</b></div>`;

  $('.convert__track').innerHTML = CONVERSIONS.map(([from, to, title, text, tool]) => `
    <article class="conv glass">
      <div class="conv__vis">${docIcon(from)}<span class="conv__arrow"></span>${docIcon(to, 'conv__to')}</div>
      <div><h3>${title}</h3><p>${text}</p></div>
      <span class="tool">${tool}</span>
    </article>`).join('');

  $$('.js-marquee').forEach((el, i) => {
    const half = i === 0 ? INPUTS.slice(0, 30) : INPUTS.slice(30);
    const chips = half.map(e => `<span class="chip"><i>.</i>${e}</span>`).join('');
    el.innerHTML = chips + chips;   // doppelt → nahtlose Schleife bei -50 %
  });

  // Statement Wort für Wort aufteilen
  $$('[data-words]').forEach(el => {
    el.innerHTML = el.textContent.trim().split(/\s+/).map(w => `<span class="w">${w}</span>`).join(' ');
  });

  /* ---------------- Theme ---------------- */
  $('.theme-toggle').addEventListener('click', () => {
    const next = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem('nffm-theme', next); } catch (e) {}
    window.dispatchEvent(new CustomEvent('themechange', { detail: next }));
  });

  /* ---------------- Kopieren ---------------- */
  $('.js-copy').addEventListener('click', async (e) => {
    const btn = e.currentTarget;
    try {
      await navigator.clipboard.writeText($('.js-install').textContent);
      btn.textContent = 'Kopiert ✓';
    } catch (err) {
      btn.textContent = 'Markieren & ⌘C';
    }
    setTimeout(() => (btn.textContent = 'Kopieren'), 1800);
  });

  /* ---------------- Finder auf Container-Breite skalieren ---------------- */
  const finder = $('.finder');
  const tilt = $('.demo__tilt');
  function fitFinder() {
    const s = tilt.parentElement.clientWidth / 880;
    finder.style.setProperty('--s', s);
    tilt.style.height = `${560 * s}px`;
  }
  fitFinder();
  // Spaltenbreite ändert sich auch durch Webfonts → beobachten statt nur resize
  if ('ResizeObserver' in window) new ResizeObserver(fitFinder).observe(tilt.parentElement);
  else window.addEventListener('resize', fitFinder);

  /* ---------------- Ohne GSAP oder bei "weniger Bewegung": statischer Endzustand ---------------- */
  const preloader = $('.preloader');
  if (!hasGsap || reduced) {
    preloader.remove();
    $('.js-notif').style.cssText = 'opacity:1;transform:none';
    $('.js-count-items').dataset.n = '7';
    $$('.statement .w').forEach(w => (w.style.opacity = 1));
    $$('.js-countup').forEach(el => (el.textContent = el.dataset.to));
    $('.convert__pin').style.overflowX = 'auto';
    $$('.demo__steps li').forEach(li => li.classList.add('is-done'));
    return;
  }

  const { gsap, ScrollTrigger } = window;
  gsap.registerPlugin(ScrollTrigger);

  /* ---------------- Smooth Scroll (Lenis) ---------------- */
  let lenis = null;
  if (typeof window.Lenis !== 'undefined') {
    lenis = new window.Lenis({ lerp: 0.1, smoothWheel: true });
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add(t => lenis.raf(t * 1000));
    gsap.ticker.lagSmoothing(0);
    $$('a[href^="#"]').forEach(a => a.addEventListener('click', e => {
      const target = $(a.getAttribute('href'));
      if (!target) return;
      e.preventDefault();
      lenis.scrollTo(target, { offset: a.getAttribute('href') === '#top' ? 0 : -10 });
    }));
  }

  /* ---------------- Preloader → Hero-Intro ---------------- */
  document.body.classList.add('is-loading');
  lenis && lenis.stop();
  gsap.set('.hero__title .line > span', { yPercent: 110 });
  gsap.set(['.reveal-up', '.hero__meta', '.scroll-hint', '.nav'], { autoAlpha: 0, y: 24 });

  const counter = { v: 0 };
  const fontsReady = document.fonts ? document.fonts.ready : Promise.resolve();
  const loadTl = gsap.timeline({ paused: true });
  loadTl
    .to(counter, { v: 100, duration: 1.8, ease: 'power2.inOut',
      onUpdate: () => ($('.js-count').textContent = Math.round(counter.v)) }, 0)
    .to('.preloader__bar span', { scaleX: 1, duration: 1.8, ease: 'power2.inOut' }, 0)
    .to(preloader, { clipPath: 'inset(0 0 100% 0)', duration: 1, ease: 'expo.inOut' }, '+=0.15')
    .add(() => { document.body.classList.remove('is-loading'); lenis && lenis.start(); }, '-=0.4')
    .to('.hero__title .line > span', { yPercent: 0, duration: 1.2, ease: 'expo.out', stagger: 0.11 }, '-=0.55')
    .to(['.nav', '.hero__meta', '.reveal-up', '.scroll-hint'], { autoAlpha: 1, y: 0, duration: 0.9, ease: 'power3.out', stagger: 0.06 }, '-=0.9')
    .add(() => preloader.remove());
  fontsReady.then(() => loadTl.play());

  /* ---------------- Hero: Parallax beim Wegscrollen ---------------- */
  gsap.to('.hero__title', {
    yPercent: -18, opacity: 0.15, ease: 'none',
    scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true },
  });
  gsap.to('.hero__ring', {
    rotate: 40, scale: 1.25, ease: 'none',
    scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true },
  });

  /* ---------------- Problem: Wörter aufleuchten lassen ---------------- */
  gsap.to('.statement .w', {
    opacity: 1, stagger: 0.08, ease: 'none',
    scrollTrigger: { trigger: '.statement', start: 'top 80%', end: 'bottom 45%', scrub: true },
  });
  gsap.from('.compare__card', {
    y: 60, autoAlpha: 0, duration: 1, ease: 'expo.out', stagger: 0.12,
    scrollTrigger: { trigger: '.compare', start: 'top 85%' },
  });

  /* ---------------- Demo: Finder-Fenster kippt in die Ebene ---------------- */
  gsap.fromTo(tilt, { rotateX: 32, scale: 0.86, y: 80 }, {
    rotateX: 0, scale: 1, y: 0, ease: 'none',
    scrollTrigger: { trigger: '.demo', start: 'top bottom', end: 'top top', scrub: true },
  });

  /* ---------------- Demo: die eigentliche Szene ---------------- */
  // Position eines Elements im Finder (Designkoordinaten 880×560), unabhängig von Transform/Skalierung
  function offsetIn(el, root) {
    let x = 0, y = 0;
    for (let n = el; n && n !== root; n = n.offsetParent) { x += n.offsetLeft; y += n.offsetTop; }
    return { x, y, w: el.offsetWidth, h: el.offsetHeight };
  }
  const W = 880, H = 560;
  const cursor = $('.js-cursor');
  const ring = $('.cursor__ring', cursor);
  const mBg = $('.js-menu-bg'), mNew = $('.js-menu-new'), mFile = $('.js-menu-file'),
        mConv = $('.js-menu-conv'), mDoc = $('.js-menu-doc');
  const fileMd = $('.js-new-md'), filePdf = $('.js-new-pdf');

  // Menü an Punkt öffnen (wie macOS: unten/rechts, sonst verschieben)
  function placeMenu(menu, x, y) {
    const left = Math.min(x, W - menu.offsetWidth - 6);
    const top = Math.min(y, H - menu.offsetHeight - 6);
    gsap.set(menu, { left, top });
    return { left, top, w: menu.offsetWidth, h: menu.offsetHeight };
  }
  // Untermenü neben einem Eintrag – rechts, wenn Platz ist, sonst links
  function placeSub(sub, parentBox, item) {
    const it = offsetIn(item, finder);
    let left = parentBox.left + parentBox.w - 4;
    if (left + sub.offsetWidth > W - 6) left = parentBox.left - sub.offsetWidth + 4;
    const top = Math.max(6, Math.min(it.y - 5, H - sub.offsetHeight - 6));
    gsap.set(sub, { left, top });
    return { left, top, w: sub.offsetWidth, h: sub.offsetHeight };
  }
  const center = (el) => { const o = offsetIn(el, finder); return { x: o.x + o.w / 2, y: o.y + o.h / 2 }; };
  const itemPoint = (el, dx = 0.35) => { const o = offsetIn(el, finder); return { x: o.x + o.w * dx, y: o.y + o.h / 2 }; };

  // Die Szene arbeitet in festen Designkoordinaten – bei Resize ändert sich nur --s.
  function buildDemo() {
    // Ausgangszustand
    gsap.set([mBg, mNew, mFile, mConv, mDoc], { autoAlpha: 0, scale: 0.97 });
    gsap.set([fileMd, filePdf], { autoAlpha: 0, scale: 0.6 });
    gsap.set('.js-notif', { autoAlpha: 0, xPercent: 120 });
    $$('.cmenu__item.is-hl, .file.is-selected').forEach(el => el.classList.remove('is-hl', 'is-selected'));

    const hlNew = $('.js-hl-new'), hlMd = $('.js-hl-md'), hlConv = $('.js-hl-conv'),
          hlDoc = $('.js-hl-doc'), hlPdf = $('.js-hl-pdf');

    // Geometrie
    const click1 = { x: 340, y: 336 };
    const bgBox = placeMenu(mBg, click1.x, click1.y);
    const newBox = placeSub(mNew, bgBox, hlNew);
    const mdIcon = center($('.doc', fileMd));
    const fileBox = placeMenu(mFile, mdIcon.x + 4, mdIcon.y + 2);
    const convBox = placeSub(mConv, fileBox, hlConv);
    placeSub(mDoc, convBox, hlDoc);

    const tipX = 5, tipY = 3;   // Spitze des Cursor-SVGs
    const at = (p) => ({ x: p.x - tipX, y: p.y - tipY });
    const pNew = itemPoint(hlNew), pMd = itemPoint(hlMd), pConv = itemPoint(hlConv),
          pDoc = itemPoint(hlDoc), pPdf = itemPoint(hlPdf);

    const tl = gsap.timeline({ defaults: { ease: 'power2.inOut' } });
    const hl = (el, on, pos) => tl.set(el, { attr: { class: el.className.replace(' is-hl', '') + (on ? ' is-hl' : '') } }, pos);
    const sel = (el, on, pos) => tl.set(el, { attr: { class: el.className.replace(' is-selected', '') + (on ? ' is-selected' : '') } }, pos);
    const pulse = (pos) => tl.fromTo(ring, { scale: 0.3, autoAlpha: 0.9 }, { scale: 1.4, autoAlpha: 0, duration: 0.35, ease: 'power1.out' }, pos);
    const show = (m, pos) => tl.to(m, { autoAlpha: 1, scale: 1, duration: 0.15, ease: 'power1.out' }, pos);
    const hide = (ms, pos) => tl.to(ms, { autoAlpha: 0, duration: 0.15 }, pos);
    const items = $('.js-count-items');

    gsap.set(cursor, at({ x: 640, y: 500 }));

    tl.addLabel('s0', 0)
      .to(cursor, { ...at(click1), duration: 1 }, 0);
    pulse(1.0); show(mBg, 1.05);
    tl.addLabel('s1', 1.4)
      .to(cursor, { ...at(pNew), duration: 0.6 }, 1.4);
    hl(hlNew, true, 2.0); show(mNew, 2.05);
    tl.to(cursor, { x: at({ x: newBox.left + 40, y: 0 }).x, duration: 0.35 }, 2.2)
      .to(cursor, { ...at({ x: newBox.left + 60, y: pMd.y }), duration: 0.4 }, 2.55);
    hl(hlMd, true, 3.0);
    pulse(3.3);
    hide([mBg, mNew], 3.4); hl(hlNew, false, 3.55); hl(hlMd, false, 3.55);
    tl.addLabel('s2', 3.45)
      .to(fileMd, { autoAlpha: 1, scale: 1, duration: 0.5, ease: 'back.out(2)' }, 3.5)
      .set(items, { attr: { 'data-n': '6' } }, 3.5);
    sel(fileMd, true, 3.5);
    tl.addLabel('s3', 4.4)
      .to(cursor, { ...at(mdIcon), duration: 0.7 }, 4.4);
    pulse(5.1); show(mFile, 5.2);
    tl.to(cursor, { ...at(pConv), duration: 0.5 }, 5.5);
    hl(hlConv, true, 6.0); show(mConv, 6.05);
    tl.to(cursor, { ...at({ x: convBox.left + 40, y: pConv.y }), duration: 0.3 }, 6.2)
      .to(cursor, { ...at(pDoc), duration: 0.35 }, 6.5);
    hl(hlDoc, true, 6.85); show(mDoc, 6.9);
    const docBox = { left: parseFloat(mDoc.style.left) };
    tl.to(cursor, { ...at({ x: docBox.left + 40, y: pDoc.y }), duration: 0.3 }, 7.05)
      .to(cursor, { ...at(pPdf), duration: 0.35 }, 7.35);
    hl(hlPdf, true, 7.7);
    pulse(7.95);
    hide([mFile, mConv, mDoc], 8.05);
    [hlConv, hlDoc, hlPdf].forEach(el => hl(el, false, 8.2));
    sel(fileMd, false, 8.1);
    tl.to(filePdf, { autoAlpha: 1, scale: 1, duration: 0.5, ease: 'back.out(2)' }, 8.2)
      .set(items, { attr: { 'data-n': '7' } }, 8.2)
      .addLabel('s4', 8.5)
      .to('.js-notif', { autoAlpha: 1, xPercent: 0, duration: 0.6, ease: 'expo.out' }, 8.5)
      .to(cursor, { ...at({ x: 760, y: 470 }), duration: 0.8 }, 8.6)
      .to({}, { duration: 1.2 });   // kurz stehen lassen

    // Schritt-Liste links mitführen
    const labels = ['s0', 's1', 's2', 's3', 's4'].map(l => tl.labels[l]);
    const steps = $$('.demo__steps li');
    const bar = $('.demo__progress span');
    const sync = () => {
      const t = tl.time();
      let active = 0;
      labels.forEach((lt, i) => { if (t >= lt) active = i; });
      steps.forEach((li, i) => {
        li.classList.toggle('is-active', i === active);
        li.classList.toggle('is-done', i < active);
      });
      bar.style.transform = `scaleX(${tl.progress()})`;
    };
    tl.eventCallback('onUpdate', sync);

    ScrollTrigger.create({
      animation: tl,
      trigger: '.demo',
      pin: '.demo__pin',
      start: 'top top',
      end: () => `+=${Math.max(2600, window.innerHeight * 3.2)}`,
      scrub: 0.6,
    });
    sync();
  }
  buildDemo();

  /* ---------------- Konvertieren: horizontale Strecke ---------------- */
  const track = $('.convert__track');
  gsap.to(track, {
    x: () => -(track.scrollWidth - window.innerWidth),
    ease: 'none',
    scrollTrigger: {
      trigger: '.convert',
      pin: '.convert__pin',
      start: 'top top',
      end: () => `+=${track.scrollWidth - window.innerWidth}`,
      scrub: 0.6,
      invalidateOnRefresh: true,
    },
  });
  $$('.js-countup').forEach(el => {
    const o = { v: 0 };
    gsap.to(o, {
      v: +el.dataset.to, duration: 1.6, ease: 'power3.out',
      onUpdate: () => (el.textContent = Math.round(o.v)),
      scrollTrigger: { trigger: el, start: 'top 85%', once: true },
    });
  });

  /* ---------------- Sektionen "aufbauen" ---------------- */
  $$('.h2').forEach(h => gsap.from(h, {
    y: 60, autoAlpha: 0, duration: 1.1, ease: 'expo.out',
    scrollTrigger: { trigger: h, start: 'top 88%' },
  }));
  gsap.set('.card, .plan', { autoAlpha: 0 });
  ScrollTrigger.batch('.card, .plan', {
    start: 'top 90%',
    onEnter: batch => gsap.fromTo(batch, { y: 70, autoAlpha: 0, rotateX: -8 },
      { y: 0, autoAlpha: 1, rotateX: 0, duration: 1.1, ease: 'expo.out', stagger: 0.08, overwrite: true }),
  });

  // Marquee-Geschwindigkeit reagiert auf Scroll-Tempo
  if (lenis) {
    const marquees = $$('.marquee, .band__track');
    lenis.on('scroll', ({ velocity }) => {
      const rate = 1 + Math.min(Math.abs(velocity) / 12, 3);
      marquees.forEach(m => m.getAnimations().forEach(a => (a.playbackRate = rate)));
    });
  }

  /* ---------------- Footer: Riesen-Typo ---------------- */
  gsap.set('.footer__huge .line > span', { yPercent: 105 });
  gsap.to('.footer__huge .line > span', {
    yPercent: 0, duration: 1.2, ease: 'expo.out', stagger: 0.12,
    scrollTrigger: { trigger: '.footer', start: 'top 75%' },
  });

  /* ---------------- Resize ---------------- */
  let rt;
  window.addEventListener('resize', () => {
    clearTimeout(rt);
    rt = setTimeout(() => ScrollTrigger.refresh(), 200);
  });
  // Nach dem Laden der Webfonts ändern sich Höhen
  fontsReady.then(() => ScrollTrigger.refresh());
})();
