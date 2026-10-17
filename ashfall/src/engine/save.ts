import type { GameState } from './types';

const KEY = 'ashfall.save.v1';

export function saveGame(state: GameState): void {
  const payload = { ...state, lastSaveAt: Date.now() };
  localStorage.setItem(KEY, JSON.stringify(payload));
}

export function loadGame(): GameState | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const data = JSON.parse(raw) as GameState;
    if (data.version !== 1) return null;
    return data;
  } catch {
    return null;
  }
}

export function clearSave(): void {
  localStorage.removeItem(KEY);
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
