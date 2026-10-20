import { doomChoicesForLoops } from '../content/capella';
import type { GameState } from './types';

const KEY = 'ashfall.save.v1';
const LOOPS_KEY = 'ashfall.capella.loops.v1';
const FOOT_TITLE_KEY = 'ashfall.capella.footTitle.v1';

export function getCapellaLoops(): number {
  try {
    const n = Number(localStorage.getItem(LOOPS_KEY));
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
  } catch {
    return 0;
  }
}

export function setCapellaLoops(n: number): void {
  const v = Math.max(0, Math.floor(n));
  localStorage.setItem(LOOPS_KEY, String(v));
}

/** Title / escape: one step closer to Capella (fewer choices next run). */
export function tightenCapellaLoop(): number {
  const next = getCapellaLoops() + 1;
  setCapellaLoops(next);
  return next;
}

export function capellaDoomRemaining(): number {
  return doomChoicesForLoops(getCapellaLoops());
}

/** After between-toes ending — next Title is a foot-only zoom of the crush gif. */
export function armFootTitleZoom(): void {
  localStorage.setItem(FOOT_TITLE_KEY, '1');
}

export function hasFootTitleZoom(): boolean {
  return localStorage.getItem(FOOT_TITLE_KEY) === '1';
}

export function clearFootTitleZoom(): void {
  localStorage.removeItem(FOOT_TITLE_KEY);
}

export function saveGame(state: GameState): void {
  const loops = typeof state.flags.capella_loops === 'number'
    ? state.flags.capella_loops
    : getCapellaLoops();
  setCapellaLoops(Number(loops) || 0);
  const payload = {
    ...state,
    flags: { ...state.flags, capella_loops: Number(loops) || 0 },
    lastSaveAt: Date.now(),
  };
  localStorage.setItem(KEY, JSON.stringify(payload));
}

export function loadGame(): GameState | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const data = JSON.parse(raw) as GameState;
    if (data.version !== 1) return null;
    // Prefer the dedicated loop counter (survives new games)
    const persisted = getCapellaLoops();
    const fromSave = Number(data.flags.capella_loops) || 0;
    data.flags.capella_loops = Math.max(persisted, fromSave);
    setCapellaLoops(Number(data.flags.capella_loops) || 0);
    return data;
  } catch {
    return null;
  }
}

export function clearSave(): void {
  // Keep Capella loop progress — Title / new journey still tightens her grip
  localStorage.removeItem(KEY);
}

/** Wipe journey + Capella loop + foot-title arm. Does not clear LLM API settings. */
export function hardResetProgress(): void {
  localStorage.removeItem(KEY);
  localStorage.removeItem(LOOPS_KEY);
  localStorage.removeItem(FOOT_TITLE_KEY);
}

export function hasSave(): boolean {
  return Boolean(localStorage.getItem(KEY));
}

export function exportSave(state: GameState): string {
  return JSON.stringify(state, null, 2);
}

export function importSave(raw: string): GameState | null {
  try {
    const data = JSON.parse(raw) as GameState;
    if (data.version !== 1 || !data.playerName || !data.locationId) return null;
    return data;
  } catch {
    return null;
  }
}
