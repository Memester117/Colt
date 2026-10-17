import type { Attribute, Attributes } from './types';
import type { ClassDef } from '../content/classes';

const BASE: Attributes = {
  might: 11,
  grace: 11,
  wits: 11,
  spirit: 11,
  presence: 11,
  endurance: 11,
};

const ARCHETYPES: Array<{
  words: string[];
  name: string;
  boosts: Partial<Attributes>;
  hp: number;
  gear: ClassDef['gear'];
  blurb: string;
}> = [
  {
    words: ['fighter', 'warrior', 'soldier', 'knight', 'blade', 'sword', 'guard', 'mercenary', 'brawler'],
    name: 'Blade',
    boosts: { might: 4, endurance: 3, grace: 1 },
    hp: 16,
    gear: [
      { id: 'blade', name: 'Service blade', description: 'Holds an edge and a grudge.', tags: ['weapon', 'melee'], quantity: 1 },
      { id: 'kit', name: 'Field kit', description: 'Bandages, oil, stubbornness.', tags: ['gear'], quantity: 1 },
    ],
    blurb: 'Someone who solves problems with steel and stance.',
  },
  {
    words: ['scout', 'ranger', 'hunter', 'tracker', 'archer', 'woods', 'forest', 'trail', 'warden'],
    name: 'Pathfinder',
    boosts: { grace: 4, wits: 2, endurance: 2 },
    hp: 13,
    gear: [
      { id: 'bow', name: 'Hunting bow', description: 'Quiet string, quieter steps.', tags: ['weapon', 'ranged'], quantity: 1 },
      { id: 'trail_ration', name: 'Trail rations', description: 'Enough for two hard days.', tags: ['food'], quantity: 2 },
    ],
    blurb: 'Reads land the way others read faces.',
  },
  {
    words: ['healer', 'herbalist', 'doctor', 'medic', 'priest', 'cleric', 'monk', 'caretaker', 'midwife'],
    name: 'Mender',
    boosts: { spirit: 4, wits: 2, presence: 2 },
    hp: 12,
    gear: [
      { id: 'herbs', name: 'Herb satchel', description: 'Bitter leaves, better odds.', tags: ['medicine'], quantity: 3 },
      { id: 'charm', name: 'Quiet charm', description: 'More comfort than magic — usually.', tags: ['gear'], quantity: 1 },
    ],
    blurb: 'Keeps people upright when the Marches try otherwise.',
  },
  {
    words: ['mage', 'wizard', 'witch', 'sorcerer', 'seer', 'oracle', 'mystic', 'scholar', 'rune'],
    name: 'Ash-scholar',
    boosts: { wits: 4, spirit: 3, presence: 1 },
    hp: 10,
    gear: [
      { id: 'grimoire', name: 'Ash-stained notes', description: 'Half theory, half warning.', tags: ['tool', 'story'], quantity: 1 },
      { id: 'chalk', name: 'Spiral chalk', description: 'For marks that listen back.', tags: ['tool'], quantity: 1 },
    ],
    blurb: 'Treats the world as a text with dangerous footnotes.',
  },
  {
    words: ['thief', 'rogue', 'assassin', 'sneak', 'shadow', 'cutpurse', 'spy', 'burglar'],
    name: 'Shadehand',
    boosts: { grace: 4, wits: 3, presence: 1 },
    hp: 11,
    gear: [
      { id: 'dagger', name: 'Hidden dagger', description: 'Polite until it isn\'t.', tags: ['weapon', 'melee'], quantity: 1 },
      { id: 'lockpicks', name: 'Lockpicks', description: 'Curiosity with teeth.', tags: ['tool'], quantity: 1 },
    ],
    blurb: 'Enters rooms sideways and leaves richer in options.',
  },
  {
    words: ['bard', 'singer', 'poet', 'story', 'musician', 'actor', 'diplomat', 'merchant', 'trader'],
    name: 'Voice',
    boosts: { presence: 4, wits: 2, grace: 2 },
    hp: 11,
    gear: [
      { id: 'instrument', name: 'Travel instrument', description: 'Tuned for rooms that need softening.', tags: ['instrument', 'tool'], quantity: 1 },
      { id: 'favor_token', name: 'Favor token', description: 'Someone owes someone.', tags: ['story'], quantity: 1 },
    ],
    blurb: 'Turns conversation into leverage and leverage into survival.',
  },
  {
    words: ['smith', 'crafter', 'builder', 'engineer', 'tinker', 'cook', 'farmer', 'laborer'],
    name: 'Maker',
    boosts: { might: 2, wits: 2, endurance: 3, spirit: 1 },
    hp: 14,
    gear: [
      { id: 'tools', name: 'Work tools', description: 'Fix first, fight later.', tags: ['tool', 'weapon'], quantity: 1 },
      { id: 'scrap', name: 'Useful scrap', description: 'Wire, nails, optimism.', tags: ['gear'], quantity: 1 },
    ],
    blurb: 'Builds what the road breaks — including morale.',
  },
];

const ATTR_WORDS: Array<{ words: string[]; attr: Attribute; amount: number }> = [
  { words: ['strong', 'mighty', 'brutal', 'powerful'], attr: 'might', amount: 2 },
  { words: ['agile', 'swift', 'quick', 'nimble', 'silent'], attr: 'grace', amount: 2 },
  { words: ['clever', 'smart', 'wise', 'sharp', 'cunning'], attr: 'wits', amount: 2 },
  { words: ['faithful', 'holy', 'brave', 'calm', 'devout'], attr: 'spirit', amount: 2 },
  { words: ['charming', 'pretty', 'silver', 'persuasive', 'loud'], attr: 'presence', amount: 2 },
  { words: ['tough', 'hardy', 'sturdy', 'resilient', 'durable'], attr: 'endurance', amount: 2 },
];

function titleCase(s: string): string {
  return s
    .split(/\s+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ')
    .slice(0, 22);
}

function clampAttr(n: number): number {
  return Math.max(7, Math.min(18, n));
}

function normalizeAttrs(attrs: Attributes): Attributes {
  const out = { ...attrs };
  for (const k of Object.keys(out) as Attribute[]) {
    out[k] = clampAttr(out[k]);
  }
  // Soft budget so customs aren't all 18s
  let sum = Object.values(out).reduce((a, b) => a + b, 0);
  while (sum > 78) {
    const keys = (Object.keys(out) as Attribute[]).sort((a, b) => out[b] - out[a]);
    const top = keys[0]!;
    if (out[top] <= 10) break;
    out[top] -= 1;
    sum -= 1;
  }
  while (sum < 66) {
    const keys = (Object.keys(out) as Attribute[]).sort((a, b) => out[a] - out[b]);
    const low = keys[0]!;
    out[low] += 1;
    sum += 1;
  }
  return out;
}

/** Build a class from a short free-text prompt — no AI, keyword tables only. */
export function classFromPrompt(prompt: string): ClassDef {
  const raw = prompt.trim().replace(/\s+/g, ' ');
  const lower = raw.toLowerCase();

  let bestScore = 0;
  let matched = ARCHETYPES[0]!;
  for (const a of ARCHETYPES) {
    let score = 0;
    for (const w of a.words) {
      if (lower.includes(w)) score += w.length > 5 ? 2 : 1;
    }
    if (score > bestScore) {
      bestScore = score;
      matched = a;
    }
  }
  if (bestScore === 0) {
    matched = {
      words: [],
      name: 'Wanderer',
      boosts: { wits: 1, endurance: 2, presence: 1 },
      hp: 12,
      gear: [
        { id: 'pack', name: 'Worn pack', description: 'Holds what hope doesn\'t.', tags: ['gear'], quantity: 1 },
        { id: 'knife', name: 'Utility knife', description: 'Food, rope, and arguments.', tags: ['tool', 'weapon'], quantity: 1 },
      ],
      blurb: 'Self-made for the road ahead.',
    };
  }

  const attrs: Attributes = { ...BASE };
  for (const [k, v] of Object.entries(matched.boosts) as Array<[Attribute, number]>) {
    attrs[k] += v;
  }
  for (const rule of ATTR_WORDS) {
    if (rule.words.some((w) => lower.includes(w))) {
      attrs[rule.attr] += rule.amount;
    }
  }

  // Optional custom name: "named X" / "called X" / first capitalized token before "who/that"
  let name = matched.name;
  const named = lower.match(/\b(?:named|called|as a|as an)\s+([a-z][a-z\s-]{1,20})/);
  if (named?.[1]) {
    name = titleCase(named[1].replace(/\b(who|that|with|from)\b.*$/, '').trim());
  } else {
    // If prompt is short like "fox witch" use it as the class name
    const words = raw.split(' ').filter((w) => w.length > 1);
    if (words.length > 0 && words.length <= 3 && raw.length <= 28) {
      name = titleCase(raw);
    }
  }
  if (!name) name = matched.name;

  const gear = [...matched.gear];
  if (/\b(letter|message|parcel)\b/.test(lower) && !gear.some((g) => g.id === 'letter')) {
    gear.push({
      id: 'letter',
      name: 'Unopened letter',
      description: 'Addressed to someone in Hollowmere.',
      tags: ['quest', 'story'],
      quantity: 1,
    });
  }
  if (/\b(herb|medicine|potion)\b/.test(lower) && !gear.some((g) => g.id === 'herbs')) {
    gear.push({
      id: 'herbs',
      name: 'Herb satchel',
      description: 'For wounds and worse days.',
      tags: ['medicine'],
      quantity: 2,
    });
  }

  const blurb =
    raw.length > 8
      ? raw.slice(0, 110) + (raw.length > 110 ? '…' : '')
      : matched.blurb;

  return {
    id: 'custom',
    name,
    blurb,
    attributes: normalizeAttrs(attrs),
    gear,
    hp: matched.hp,
  };
}

export function previewCustomClass(prompt: string): ClassDef | null {
  if (!prompt.trim()) return null;
  return classFromPrompt(prompt);
}
