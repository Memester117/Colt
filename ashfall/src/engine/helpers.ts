import type { ChronicleEntry, GameState, LogLine, QuestState } from './types';
import { QUESTS } from '../content/quests';

let lineCounter = 0;

export function uid(prefix = 'id'): string {
  lineCounter += 1;
  return `${prefix}_${Date.now().toString(36)}_${lineCounter}`;
}

export function cloneState(state: GameState): GameState {
  return structuredClone(state);
}

export function pushLog(state: GameState, line: Omit<LogLine, 'id'>): void {
  state.log.push({ ...line, id: uid('log') });
  if (state.log.length > 80) {
    state.log = state.log.slice(-80);
  }
}

export function addChronicle(
  state: GameState,
  text: string,
  tags: string[],
  important = false,
): void {
  const entry: ChronicleEntry = {
    id: uid('chr'),
    day: state.day,
    text,
    tags,
    important,
  };
  state.chronicle.unshift(entry);
  if (state.chronicle.length > 60) state.chronicle = state.chronicle.slice(0, 60);
}

export function ensureQuest(state: GameState, questId: string, stage = 0): QuestState {
  if (!state.quests[questId]) {
    state.quests[questId] = {
      id: questId,
      stage,
      completed: false,
      failed: false,
      notes: [],
    };
    const def = QUESTS[questId];
    if (def) {
      pushLog(state, {
        kind: 'system',
        text: `Quest begun: ${def.name} — ${def.summary}`,
      });
      addChronicle(state, `Began "${def.name}".`, ['quest', questId], true);
    }
  }
  return state.quests[questId]!;
}

export function advanceQuest(state: GameState, questId: string, stage: number): void {
  const q = ensureQuest(state, questId, stage);
  if (q.completed || q.failed) return;
  if (stage > q.stage) {
    q.stage = stage;
    const def = QUESTS[questId];
    const stageText = def?.stages[stage] ?? `Stage ${stage}`;
    pushLog(state, { kind: 'system', text: `Quest update — ${def?.name ?? questId}: ${stageText}` });
    addChronicle(state, stageText, ['quest', questId], true);
    if (def && stage >= def.stages.length - 1) {
      // not auto-complete; caller marks complete
    }
  }
}

export function completeQuest(state: GameState, questId: string): void {
  const q = ensureQuest(state, questId);
  if (q.completed) return;
  q.completed = true;
  const def = QUESTS[questId];
  pushLog(state, {
    kind: 'system',
    text: `Quest complete: ${def?.name ?? questId}`,
  });
  addChronicle(state, `Completed "${def?.name ?? questId}".`, ['quest', questId, 'done'], true);
  state.coin += 8;
  state.flags[`quest_${questId}_done`] = true;
  const doneCount = Object.values(state.quests).filter((x) => x.completed).length;
  if (doneCount >= 2 && state.chapter < 2) state.chapter = 2;
  if (doneCount >= 4 && state.chapter < 3) state.chapter = 3;
}

export function setNpcAttitude(state: GameState, npcId: string, delta: number): void {
  if (!state.npcs[npcId]) {
    state.npcs[npcId] = { met: true, attitude: 0, secretsKnown: [] };
  }
  const n = state.npcs[npcId]!;
  n.met = true;
  n.attitude = Math.max(-3, Math.min(3, n.attitude + delta));
}

export function hasItem(state: GameState, itemId: string): boolean {
  return state.inventory.some((i) => i.id === itemId && i.quantity > 0);
}

export function addItem(
  state: GameState,
  item: { id: string; name: string; description: string; tags: string[]; quantity: number },
): void {
  const existing = state.inventory.find((i) => i.id === item.id);
  if (existing) existing.quantity += item.quantity;
  else state.inventory.push({ ...item });
}

export function removeItem(state: GameState, itemId: string, qty = 1): boolean {
  const item = state.inventory.find((i) => i.id === itemId);
  if (!item || item.quantity < qty) return false;
  item.quantity -= qty;
  if (item.quantity <= 0) {
    state.inventory = state.inventory.filter((i) => i.id !== itemId);
  }
  return true;
}

export function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n));
}

export function flagTrue(state: GameState, key: string): boolean {
  return Boolean(state.flags[key]);
}
