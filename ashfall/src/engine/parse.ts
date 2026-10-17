import type { ActionKind, Choice, GameState } from './types';

const VERBS: Array<{ kind: ActionKind; words: string[] }> = [
  { kind: 'talk', words: ['talk', 'speak', 'ask', 'tell', 'greet', 'chat', 'converse', 'question'] },
  { kind: 'investigate', words: ['look', 'search', 'investigate', 'examine', 'inspect', 'study', 'check', 'read', 'listen'] },
  { kind: 'travel', words: ['go', 'walk', 'travel', 'head', 'move', 'leave', 'enter', 'return', 'climb', 'follow'] },
  { kind: 'rest', words: ['rest', 'sleep', 'camp', 'heal', 'recover', 'nap'] },
  { kind: 'fight', words: ['fight', 'attack', 'strike', 'hit', 'kill', 'engage', 'battle'] },
  { kind: 'sneak', words: ['sneak', 'hide', 'steal', 'slip', 'creep', 'ambush'] },
  { kind: 'help', words: ['help', 'aid', 'rescue', 'save', 'assist', 'fix'] },
  { kind: 'bargain', words: ['bargain', 'trade', 'buy', 'sell', 'bribe', 'offer', 'negotiate'] },
  { kind: 'use', words: ['use', 'give', 'show', 'equip', 'drink', 'eat', 'play'] },
  { kind: 'wait', words: ['wait', 'watch', 'linger', 'pause'] },
  { kind: 'flee', words: ['flee', 'run', 'escape', 'retreat'] },
];

export function parseFreeText(state: GameState, text: string): Choice | null {
  const raw = text.trim().toLowerCase();
  if (!raw) return null;

  let matchedKind: ActionKind | null = null;
  for (const v of VERBS) {
    if (v.words.some((w) => raw.includes(w))) {
      matchedKind = v.kind;
      break;
    }
  }

  // Match against available choices by keyword overlap
  const scored = state.choices
    .filter((c) => !c.hidden)
    .map((c) => {
      const label = c.label.toLowerCase();
      const words = raw.split(/\W+/).filter((w) => w.length > 2);
      let score = 0;
      for (const w of words) {
        if (label.includes(w)) score += 2;
        if (c.targetId && w.includes(c.targetId.slice(0, 4))) score += 1;
        if (matchedKind && c.kind === matchedKind) score += 2;
      }
      if (matchedKind && c.kind === matchedKind) score += 1;
      return { c, score };
    })
    .sort((a, b) => b.score - a.score);

  if (scored[0] && scored[0].score >= 2) {
    return scored[0].c;
  }

  if (matchedKind) {
    const same = state.choices.find((c) => c.kind === matchedKind && !c.hidden);
    if (same) return same;
  }

  return {
    id: 'custom_free',
    label: text.trim(),
    kind: 'custom',
  };
}
