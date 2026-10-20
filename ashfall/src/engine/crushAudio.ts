/**
 * Procedural crush / bone-crunch bed for the Capella ending.
 * (No YouTube rips — Web Audio only.)
 */

let ctx: AudioContext | null = null;
let bedGain: GainNode | null = null;
let crunchTimer: number | null = null;
let started = false;

function ac(): AudioContext {
  if (!ctx) ctx = new AudioContext();
  return ctx;
}

/** Low nasty rumble under the foot. */
function startBed() {
  const c = ac();
  if (bedGain) return;
  bedGain = c.createGain();
  bedGain.gain.value = 0.04;
  bedGain.connect(c.destination);

  const osc = c.createOscillator();
  osc.type = 'sawtooth';
  osc.frequency.value = 38;
  const filter = c.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.value = 120;
  osc.connect(filter);
  filter.connect(bedGain);
  osc.start();
}

/** One bone-crush sting — noise burst + thump. */
export function playBoneCrunch() {
  const c = ac();
  const now = c.currentTime;

  // Impact thump
  const thump = c.createOscillator();
  const thumpGain = c.createGain();
  thump.type = 'sine';
  thump.frequency.setValueAtTime(90, now);
  thump.frequency.exponentialRampToValueAtTime(35, now + 0.25);
  thumpGain.gain.setValueAtTime(0.55, now);
  thumpGain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
  thump.connect(thumpGain);
  thumpGain.connect(c.destination);
  thump.start(now);
  thump.stop(now + 0.4);

  // Crunch noise
  const seconds = 0.45;
  const buffer = c.createBuffer(1, Math.floor(c.sampleRate * seconds), c.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < data.length; i++) {
    const t = i / data.length;
    const env = Math.exp(-t * 6) * (0.6 + Math.random() * 0.4);
    data[i] = (Math.random() * 2 - 1) * env;
  }
  const noise = c.createBufferSource();
  noise.buffer = buffer;
  const band = c.createBiquadFilter();
  band.type = 'bandpass';
  band.frequency.value = 1800;
  band.Q.value = 0.7;
  const nGain = c.createGain();
  nGain.gain.value = 0.35;
  noise.connect(band);
  band.connect(nGain);
  nGain.connect(c.destination);
  noise.start(now);
}

/** Start bed + first crunch; re-crunch every 15s. Safe to call after a user gesture. */
export async function startCrushAudio() {
  const c = ac();
  if (c.state === 'suspended') await c.resume();
  if (started) return;
  started = true;
  startBed();
  playBoneCrunch();
  crunchTimer = window.setInterval(() => {
    playBoneCrunch();
  }, 15000);
}

export function stopCrushAudio() {
  if (crunchTimer != null) {
    window.clearInterval(crunchTimer);
    crunchTimer = null;
  }
  if (bedGain) {
    try {
      bedGain.disconnect();
    } catch {
      /* ignore */
    }
    bedGain = null;
  }
  started = false;
}
