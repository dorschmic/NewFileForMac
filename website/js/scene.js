/* NewFileForMac – WebGL: lebendiger Farbverlauf + gläserne Datei-Objekte (Three.js)
 *
 * Der Verlauf ist eine Fläche in derselben Szene wie die Glasobjekte. Nur so
 * kann das Glas (MeshPhysicalMaterial mit transmission) ihn wirklich brechen.
 * Fällt WebGL aus, bleiben die CSS-Blobs darunter sichtbar.
 */
import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const canvas = document.querySelector('.webgl');
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

function init() {
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
  } catch (e) {
    return; // kein WebGL → CSS-Fallback
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 100);
  camera.position.set(0, 0, 10);

  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

  /* ---------- Hintergrund-Verlauf (Shader) ---------- */
  const isDark = () => document.documentElement.dataset.theme !== 'light';
  const bgUniforms = {
    uTime: { value: 0 },
    uDark: { value: isDark() ? 1 : 0 },
    uAspect: { value: 1 },
    uScroll: { value: 0 },
  };
  const bgMat = new THREE.ShaderMaterial({
    uniforms: bgUniforms,
    depthWrite: false,
    vertexShader: /* glsl */`
      varying vec2 vUv;
      void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
    fragmentShader: /* glsl */`
      precision highp float;
      varying vec2 vUv;
      uniform float uTime, uDark, uAspect, uScroll;
      float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      float blob(vec2 p, vec2 c, float r) { float d = length(p - c); return smoothstep(r, 0.0, d); }
      void main() {
        vec2 p = vUv; p.x *= uAspect;
        float t = uTime * 0.06;
        float s = uScroll * 0.15;
        vec3 c1 = vec3(1.00, 0.37, 0.43); // Koralle
        vec3 c2 = vec3(1.00, 0.76, 0.44); // Pfirsich
        vec3 c3 = vec3(0.48, 0.64, 1.00); // Himmel
        vec3 c4 = vec3(0.65, 0.55, 0.98); // Lavendel
        vec3 baseD = vec3(0.047, 0.047, 0.063);
        vec3 baseL = vec3(0.933, 0.941, 0.965);
        vec3 col = mix(baseL, baseD, uDark);
        float k = mix(0.55, 0.5, uDark);
        col = mix(col, c1, k * blob(p, vec2(0.25 * uAspect + 0.18 * sin(t * 1.3), 0.78 + 0.12 * cos(t) - s), 0.75));
        col = mix(col, c2, k * 0.8 * blob(p, vec2(0.55 * uAspect + 0.22 * cos(t * 0.9), 0.55 + 0.15 * sin(t * 1.1) - s * 0.6), 0.55));
        col = mix(col, c3, k * blob(p, vec2(0.85 * uAspect + 0.15 * sin(t * 0.7), 0.25 + 0.18 * cos(t * 1.4) + s * 0.4), 0.8));
        col = mix(col, c4, k * 0.9 * blob(p, vec2(0.45 * uAspect + 0.25 * sin(t * 0.5 + 2.0), 0.12 + 0.1 * sin(t * 1.7)), 0.6));
        // Vignette (nur dunkel) + Körnung
        float v = smoothstep(1.25, 0.25, length(vUv - 0.5) * 1.6);
        col *= mix(1.0, 0.55 + 0.45 * v, uDark);
        col += (hash(vUv * 900.0 + uTime) - 0.5) * 0.025;
        gl_FragColor = vec4(col, 1.0);
        #include <colorspace_fragment>
      }`,
  });
  const bg = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), bgMat);
  bg.position.z = -8;
  scene.add(bg);

  /* ---------- Gläserne Dateien ---------- */
  function fileShape(w = 1, h = 1.3, fold = 0.32, r = 0.08) {
    const s = new THREE.Shape();
    const x0 = -w / 2, y0 = -h / 2, x1 = w / 2, y1 = h / 2;
    s.moveTo(x0 + r, y0);
    s.lineTo(x1 - r, y0);
    s.quadraticCurveTo(x1, y0, x1, y0 + r);
    s.lineTo(x1, y1 - fold);          // Eselsohr oben rechts
    s.lineTo(x1 - fold, y1);
    s.lineTo(x0 + r, y1);
    s.quadraticCurveTo(x0, y1, x0, y1 - r);
    s.lineTo(x0, y0 + r);
    s.quadraticCurveTo(x0, y0, x0 + r, y0);
    return s;
  }
  const geo = new THREE.ExtrudeGeometry(fileShape(), {
    depth: 0.14, bevelEnabled: true, bevelThickness: 0.05, bevelSize: 0.045, bevelSegments: 6, curveSegments: 12,
  });
  geo.center();

  const glass = new THREE.MeshPhysicalMaterial({
    color: 0xffffff,
    metalness: 0,
    roughness: 0.06,
    transmission: 1,
    thickness: 0.9,
    ior: 1.45,
    iridescence: 0.55,
    iridescenceIOR: 1.3,
    clearcoat: 1,
    clearcoatRoughness: 0.08,
    envMapIntensity: 1.3,
  });

  function labelTexture(text) {
    const c = document.createElement('canvas');
    c.width = 512; c.height = 256;
    const g = c.getContext('2d');
    g.fillStyle = isDark() ? 'rgba(255,255,255,0.92)' : 'rgba(20,20,30,0.78)';
    g.font = '800 150px Archivo, "Helvetica Neue", Arial, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(text, 256, 132);
    const tex = new THREE.CanvasTexture(c);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 4;
    return tex;
  }

  const LABELS = ['.md', '.py', '.docx', '.mp3', '.pdf', '.json', '.txt'];
  const group = new THREE.Group();
  scene.add(group);
  const files = LABELS.map((label, i) => {
    const obj = new THREE.Group();
    obj.add(new THREE.Mesh(geo, glass));
    const lab = new THREE.Mesh(
      new THREE.PlaneGeometry(0.78, 0.39),
      new THREE.MeshBasicMaterial({ map: labelTexture(label), transparent: true, depthWrite: false, toneMapped: false }),
    );
    lab.position.set(0, -0.22, 0.13);
    obj.add(lab);
    group.add(obj);
    return {
      obj,
      phase: i * 1.7,
      speed: 0.5 + (i % 3) * 0.18,
      scale: 0.75 + ((i * 37) % 10) / 20,
      base: new THREE.Vector3(),
      rot: new THREE.Euler((i % 2 ? -0.25 : 0.2), -0.5 + (i % 4) * 0.35, (i % 3 - 1) * 0.18),
    };
  });

  /* ---------- Layout je nach Seitenverhältnis ---------- */
  // Positionen als Anteil der sichtbaren Breite/Höhe (bei z = 0)
  const LAYOUT_WIDE = [[0.18, 0.22], [0.36, 0.30], [0.27, -0.02], [0.42, 0.02], [0.14, -0.26], [0.33, -0.30], [0.05, 0.36]];
  const LAYOUT_TALL = [[-0.28, 0.36], [0.05, 0.40], [0.32, 0.30], [-0.10, 0.22], [0.22, 0.12], [-0.33, 0.12], [0.36, 0.44]];
  function layout() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();

    const visH = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * camera.position.z;
    const visW = visH * camera.aspect;
    // Hintergrundfläche füllt den Blick bei z = -8
    const bgH = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) * (camera.position.z - bg.position.z);
    bg.scale.set(bgH * camera.aspect * 1.02, bgH * 1.02, 1);
    bgUniforms.uAspect.value = camera.aspect;

    const tall = camera.aspect < 0.9;
    const L = tall ? LAYOUT_TALL : LAYOUT_WIDE;
    const sizeK = tall ? Math.min(1, visW / 5.2) : Math.min(1.25, visW / 13);
    files.forEach((f, i) => {
      f.base.set(L[i][0] * visW, L[i][1] * visH, -((i * 53) % 7) * 0.25);
      f.obj.scale.setScalar(f.scale * sizeK);
    });
  }
  layout();
  window.addEventListener('resize', layout);

  /* ---------- Interaktion ---------- */
  const pointer = { x: 0, y: 0, tx: 0, ty: 0 };
  window.addEventListener('pointermove', (e) => {
    pointer.tx = (e.clientX / window.innerWidth) * 2 - 1;
    pointer.ty = (e.clientY / window.innerHeight) * 2 - 1;
  }, { passive: true });

  let darkTarget = bgUniforms.uDark.value;
  window.addEventListener('themechange', () => { darkTarget = isDark() ? 1 : 0; redrawLabels(); });

  /* ---------- Render-Schleife ---------- */
  const clock = new THREE.Clock();
  function frame() {
    const dt = Math.min(clock.getDelta(), 0.05);
    const t = reduced ? 0 : clock.elapsedTime;
    const scroll = window.scrollY / window.innerHeight;   // 0 = oben, 1 = eine Bildschirmhöhe

    pointer.x += (pointer.tx - pointer.x) * 0.05;
    pointer.y += (pointer.ty - pointer.y) * 0.05;
    bgUniforms.uTime.value = t;
    bgUniforms.uScroll.value = scroll;
    bgUniforms.uDark.value += (darkTarget - bgUniforms.uDark.value) * Math.min(1, dt * 4);

    // Glas schwebt im Hero, fliegt beim Scrollen nach oben weg
    const out = Math.min(scroll, 1.6);
    group.visible = out < 1.5;
    group.position.y = out * 5.5;
    group.rotation.z = out * 0.25;
    group.rotation.y = pointer.x * 0.25;
    group.rotation.x = pointer.y * 0.15;

    files.forEach((f) => {
      f.obj.position.set(
        f.base.x + Math.sin(t * f.speed * 0.6 + f.phase) * 0.12,
        f.base.y + Math.sin(t * f.speed + f.phase) * 0.18,
        f.base.z,
      );
      f.obj.rotation.set(
        f.rot.x + Math.sin(t * 0.4 + f.phase) * 0.15,
        f.rot.y + t * 0.12 * (f.phase % 2 ? 1 : -1) + out * 1.2,
        f.rot.z,
      );
    });

    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }

  // Labels neu zeichnen: nach dem Laden der Schrift und beim Theme-Wechsel
  function redrawLabels() {
    files.forEach((f, i) => {
      const lab = f.obj.children[1];
      lab.material.map.dispose();
      lab.material.map = labelTexture(LABELS[i]);
    });
  }
  (document.fonts ? document.fonts.ready : Promise.resolve()).then(redrawLabels);

  canvas.classList.add('is-ready');
  requestAnimationFrame(frame);
}

init();
