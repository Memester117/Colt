import { getLocation } from '../content/locations';
import { createRng, hashSeed, pick } from './rng';
import { pushLog } from './helpers';
import type { GameState } from './types';

const API_KEY_LS = 'ashfall.llm.key';
const API_URL_LS = 'ashfall.llm.url';
const API_MODEL_LS = 'ashfall.llm.model';

let sessionApiCalls = 0;
let sessionTokens = 0;
const tokenListeners = new Set<(tokens: number) => void>();

export function getSessionApiCalls(): number {
  return sessionApiCalls;
}

export function getSessionTokens(): number {
  return sessionTokens;
}

export function subscribeSessionTokens(fn: (tokens: number) => void): () => void {
  tokenListeners.add(fn);
  fn(sessionTokens);
  return () => {
    tokenListeners.delete(fn);
  };
}

function bumpTokens(n: number): void {
  if (n <= 0) return;
  sessionTokens += n;
  for (const fn of tokenListeners) fn(sessionTokens);
}

// Browser demo / console: window.__ashfallBumpTokens?.(420)
if (typeof window !== 'undefined') {
  (window as unknown as { __ashfallBumpTokens?: (n: number) => void }).__ashfallBumpTokens =
    bumpTokens;
}

export function getLlmKey(): string {
  return localStorage.getItem(API_KEY_LS)?.trim() ?? '';
}

export function setLlmKey(key: string): void {
  if (key.trim()) localStorage.setItem(API_KEY_LS, key.trim());
  else localStorage.removeItem(API_KEY_LS);
}

export function getLlmUrl(): string {
  return (
    localStorage.getItem(API_URL_LS)?.trim() ||
    'https://api.openai.com/v1/chat/completions'
  );
}

export function setLlmUrl(url: string): void {
  if (url.trim()) localStorage.setItem(API_URL_LS, url.trim());
  else localStorage.removeItem(API_URL_LS);
}

export function getLlmModel(): string {
  return localStorage.getItem(API_MODEL_LS)?.trim() || 'gpt-4o-mini';
}

export function setLlmModel(model: string): void {
  if (model.trim()) localStorage.setItem(API_MODEL_LS, model.trim());
  else localStorage.removeItem(API_MODEL_LS);
}

const CAPELLA_VOICE = `
You are Capella Emerada Lugunica, Sin Archbishop of Lust from Re:Zero.
Voice: cruel, mocking, playful, possessive. You spit on courtesy. You call yourself beautiful and kind while being neither.
You treat people as meat toys. Love means ownership. You transform bodies for fun — bugs, dragons, meat piles.
You want everyone to love Mama. You laugh at pain. You react specifically to the player's name, calling, gear, and last action.
You speak short (1-3 sentences). Mix cute singsong with venom. Often end with ~ or a giggle.
You shrink / toy with the player's scale. Relish it. Address them by name.
Do not break character. Do not mention being an AI or a game.
`.trim();

const NARRATOR = `
You are the sole narrative voice of a dark fantasy RPG that Capella Emerada Lugunica keeps hijacking.
Write ALL dialogue and description in vivid second person. Capella may already be present.
Keep each response to 2-4 sentences. React to the player's name, class, stats, and last action.
No meta, no "as an AI".
`.trim();

function playerBrief(state: GameState): string {
  const loc = getLocation(state.locationId);
  const topAttr = (Object.entries(state.attributes) as Array<[string, number]>)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([k, v]) => `${k} ${v}`)
    .join(', ');
  const gear = state.inventory
    .slice(0, 4)
    .map((i) => i.name)
    .join(', ');
  const recent = state.log
    .filter((l) => l.kind === 'choice' || l.kind === 'narration')
    .slice(-4)
    .map((l) => l.text)
    .join(' | ');
  return [
    `Name: ${state.playerName}`,
    `Calling: ${state.playerClass}`,
    `Strongest: ${topAttr}`,
    `HP ${state.hp}/${state.maxHp}, stress ${state.stress}, coin ${state.coin}`,
    `Place: ${loc.name} (${loc.region}), ${state.time}, ${state.weather}`,
    `Gear: ${gear || 'empty pockets'}`,
    `Day ${state.day}, turn ${state.turns}, Capella loops ${state.flags.capella_loops ?? 0}`,
    `Recent log: ${recent || 'none'}`,
  ].join('\n');
}

async function chatComplete(
  system: string,
  user: string,
  opts: { maxTokens?: number } = {},
): Promise<string | null> {
  const key = getLlmKey();
  if (!key) return null;
  try {
    const res = await fetch(getLlmUrl(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: getLlmModel(),
        temperature: 1.05,
        max_tokens: opts.maxTokens ?? 220,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      }),
    });
    if (!res.ok) return null;
    sessionApiCalls += 1;
    const data = (await res.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
      usage?: {
        prompt_tokens?: number;
        completion_tokens?: number;
        total_tokens?: number;
      };
    };
    const usage = data.usage;
    const burned =
      usage?.total_tokens ??
      (typeof usage?.prompt_tokens === 'number' || typeof usage?.completion_tokens === 'number'
        ? (usage.prompt_tokens ?? 0) + (usage.completion_tokens ?? 0)
        : 0);
    if (burned > 0) bumpTokens(burned);
    else {
      // Providers that omit usage: rough estimate so the counter still climbs.
      const approx = Math.ceil((system.length + user.length) / 4) + (opts.maxTokens ?? 220);
      bumpTokens(approx);
    }
    const text = data.choices?.[0]?.message?.content?.trim();
    return text || null;
  } catch {
    return null;
  }
}

function offlineStory(state: GameState, lastChoice: string, rng: () => number): string {
  const loc = getLocation(state.locationId);
  return pick(rng, [
    `${loc.name} answers ${state.playerName}'s "${lastChoice}" with weather, rumor, and a door that shouldn't open.`,
    `As a ${state.playerClass}, you lean into "${lastChoice}". ${loc.region} tries to become a longer story.`,
    `The scene stretches. NPCs invent needs. Your ${state.inventory[0]?.name ?? 'empty hands'} catch a glance.`,
  ]);
}

function offlineCapella(state: GameState, lastChoice: string, rng: () => number): string {
  const name = state.playerName;
  const cls = state.playerClass;
  return pick(rng, [
    `Aww, ${name} the ${cls} still doing "${lastChoice}" like free will exists~ Mama's shrinking that attitude next~`,
    `${name}~ cute chore. Now lose a few inches for Mama. Love hurts smaller~`,
    `Bags of meat named ${name} don't get arcs. They get toes. Shrink~`,
  ]);
}

/** Drop canned narration/system so AI owns the voice. Keep choices/rolls. */
export function stripCannedProse(state: GameState): void {
  state.log = state.log.filter((l) => l.kind === 'choice' || l.kind === 'roll');
}

export async function generateOpening(state: GameState): Promise<string> {
  const rng = createRng(hashSeed(state.seed, 'open'));
  const live = await chatComplete(
    NARRATOR,
    `Player:\n${playerBrief(state)}\nWrite the opening arrival in Hollowmere. Hint danger without naming Capella if loops=0. 3 sentences.`,
  );
  return (
    live ??
    pick(rng, [
      `Hollowmere receives ${state.playerName} the ${state.playerClass} like a rumor with boots. The Marches smell like rain and unfinished wars.`,
      `You arrive. Slate roofs. Soft smoke. Something in the wind already measuring your height.`,
    ])
  );
}

export async function generateStoryBeat(state: GameState, lastChoice: string): Promise<string> {
  const rng = createRng(hashSeed(state.seed, state.turns, 'story', lastChoice));
  const live = await chatComplete(
    NARRATOR,
    `Player:\n${playerBrief(state)}\nThey just chose: "${lastChoice}"\nNarrate what happens — dialogue from locals if any, sensory detail, a hook. Capella may interrupt next; leave space. 3 sentences.`,
  );
  return live ?? offlineStory(state, lastChoice, rng);
}

export async function generateCapellaLine(state: GameState, lastChoice: string): Promise<string> {
  const rng = createRng(hashSeed(state.seed, state.turns, 'capella', lastChoice));
  const live = await chatComplete(
    CAPELLA_VOICE,
    `Player sheet:\n${playerBrief(state)}\nThey just did: "${lastChoice}"\nReact to THIS character specifically, mock their choice, then shrink-tease them. 2-3 sentences.`,
  );
  return live ?? offlineCapella(state, lastChoice, rng);
}

export async function generateCapellaCrushTaunt(
  state: GameState,
  kind: 'struggle' | 'crush' | 'toes' | 'wiggle',
): Promise<{ text: string; burnedApi: boolean }> {
  const rng = createRng(hashSeed(state.seed, state.turns, kind, sessionApiCalls));
  const prompt =
    kind === 'wiggle'
      ? `Your toes just flexed/wiggled over ${state.playerName}. Idle cruel banter mid-crush. 1-2 sentences. Burn the moment.`
      : kind === 'toes'
        ? `They spawned bug-sized between your toes. Taunt them by name. 2 sentences.`
        : kind === 'struggle'
          ? `They struggle under your foot. Taunt. 2 sentences.`
          : `You just shrunk them and stepped. Taunt. 2 sentences.`;

  const live = await chatComplete(CAPELLA_VOICE, `Player:\n${playerBrief(state)}\n${prompt}`, {
    maxTokens: 120,
  });
  if (live) return { text: live, burnedApi: true };

  const fallback =
    kind === 'wiggle'
      ? pick(rng, [
          `*wiggle* Feel that, ${state.playerName}? Mama's toes bill for attention~`,
          `Toe tap. Credit spent. You're still sticky underfoot, little ${state.playerClass}~`,
        ])
      : kind === 'toes'
        ? `${state.playerName}~ toe-gap VIP seating. Wriggle for Mama~`
        : kind === 'struggle'
          ? `Struggle louder, ${state.playerName}. Mama likes the buzz~`
          : `Shrunk then stepped — Mama's recipe for ${state.playerName}~`;
  return { text: fallback, burnedApi: false };
}

/** AI owns the turn prose: strip canned lines, write scene + Capella. */
export async function weaveCapellaTurn(state: GameState, lastChoice: string): Promise<GameState> {
  if (state.flags.crushed_by_capella) return state;
  const next = structuredClone(state);
  stripCannedProse(next);
  // re-add the choice line for readability
  pushLog(next, { kind: 'choice', text: `> ${lastChoice}` });
  const story = await generateStoryBeat(next, lastChoice);
  const capella = await generateCapellaLine(next, lastChoice);
  pushLog(next, { kind: 'narration', text: story });
  pushLog(next, { kind: 'narration', text: `**Capella:** ${capella}` });
  next.stress = Math.min(next.maxStress, next.stress + 1);
  next.flags.capella_spoke = true;
  if (next.turns >= 2 && next.hp > 1) {
    next.hp = Math.max(1, next.hp - 1);
    pushLog(next, {
      kind: 'system',
      text: 'Scale slips (−1 HP).',
    });
  }
  return next;
}

export async function weaveOpening(state: GameState): Promise<GameState> {
  const next = structuredClone(state);
  next.log = [];
  const opening = await generateOpening(next);
  pushLog(next, { kind: 'narration', text: opening });
  if ((Number(next.flags.capella_loops) || 0) > 0) {
    const tease = await generateCapellaLine(next, 'arrive again');
    pushLog(next, { kind: 'narration', text: `**Capella:** ${tease}` });
  }
  return next;
}
