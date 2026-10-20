import { getLocation } from '../content/locations';
import { createRng, hashSeed, pick } from './rng';
import { pushLog } from './helpers';
import type { GameState } from './types';

const API_KEY_LS = 'ashfall.llm.key';
const API_URL_LS = 'ashfall.llm.url';
const API_MODEL_LS = 'ashfall.llm.model';

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

/** Paraphrased voice notes — not wiki text. */
const CAPELLA_VOICE = `
You are Capella Emerada Lugunica, Sin Archbishop of Lust from Re:Zero.
Voice: cruel, mocking, playful, possessive. You spit on courtesy. You call yourself beautiful and kind while being neither.
You treat people as meat toys. Love means ownership. You transform bodies for fun — bugs, dragons, meat piles.
You want everyone to love Mama. You laugh at pain. You react specifically to the player's name, calling, gear, and last action.
You speak short (1-3 sentences). Mix cute singsong with venom. Often end with ~ or a giggle.
You are shrinking / about to shrink the player. Relish it. Address them by name.
Do not break character. Do not mention being an AI or a game.
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
  return [
    `Name: ${state.playerName}`,
    `Calling: ${state.playerClass}`,
    `Strongest: ${topAttr}`,
    `HP ${state.hp}/${state.maxHp}, stress ${state.stress}, coin ${state.coin}`,
    `Place: ${loc.name} (${loc.region})`,
    `Gear: ${gear || 'empty pockets'}`,
    `Day ${state.day}, turn ${state.turns}, Capella loops ${state.flags.capella_loops ?? 0}`,
  ].join('\n');
}

async function chatComplete(system: string, user: string): Promise<string | null> {
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
        temperature: 0.95,
        max_tokens: 180,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const text = data.choices?.[0]?.message?.content?.trim();
    return text || null;
  } catch {
    return null;
  }
}

function offlineStory(state: GameState, lastChoice: string, rng: () => number): string {
  const loc = getLocation(state.locationId);
  const hooks = [
    `In ${loc.name}, your path as ${state.playerClass} snags on something unfinished — a rumor, a debt, a door that should stay shut.`,
    `The Marches widen for a breath. ${state.playerName} the ${state.playerClass} could chase glory, mercy, or coin… if the world stays polite.`,
    `NPCs glance at your ${state.inventory[0]?.name ?? 'empty hands'} and invent opinions. A larger story tries to start.`,
    `You could spend days here. Quests braid. ${loc.region} has more teeth than maps admit.`,
  ];
  const action = lastChoice
    ? `Your move ("${lastChoice}") tugs a thread that wants to become a chapter.`
    : 'A chapter leans in.';
  return `${pick(rng, hooks)} ${action}`;
}

function offlineCapella(state: GameState, lastChoice: string, rng: () => number): string {
  const name = state.playerName;
  const cls = state.playerClass;
  const might = state.attributes.might;
  const presence = state.attributes.presence;
  const wits = state.attributes.wits;
  const item = state.inventory[0]?.name;

  const openers = [
    `Aww, ${name}~ Mama found a little ${cls}.`,
    `Listen up, meat-sack branded ${name}~`,
    `Ohhh? ${name} the ${cls} thinks the Marches are about them~`,
    `Cute. ${name} still believes choices matter~`,
  ];

  const reactions: string[] = [];
  if (might >= 14) {
    reactions.push(
      `All that Might (${might}) and you're still the size of a snack under Mama's sole~`,
      `Flex harder, ${name}. Muscle is just thicker meat when I shrink it~`,
    );
  }
  if (presence >= 14) {
    reactions.push(
      `Presence ${presence}? Charm Mama and maybe she'll grind you slower~`,
      `Pretty voice, ${name}. Louder when you're bug-sized~`,
    );
  }
  if (wits >= 14) {
    reactions.push(
      `Wits ${wits} inventing exits? Mama invents smaller doors~`,
      `Smart little ${cls}. Smart things crunch nicer~`,
    );
  }
  if (item) {
    reactions.push(
      `Keep the ${item}. I'll turn you into something that fits in my toes with it~`,
      `${item} won't prop a foot, darling~`,
    );
  }
  if (lastChoice.toLowerCase().includes('rest') || lastChoice.toLowerCase().includes('camp')) {
    reactions.push(`Resting? Sleep under Mama instead. Soft sole, hard ending~`);
  }
  if (lastChoice.toLowerCase().includes('talk') || lastChoice.match(/Mira|Mayor|Brenna|Innkeep/i)) {
    reactions.push(`Chat chat chat. Mama's jealous. Love me, not them~`);
  }
  if (lastChoice.toLowerCase().includes('look') || lastChoice.toLowerCase().includes('investigate')) {
    reactions.push(`Looking around? Look up. Sole's the scenery now~`);
  }
  if (!reactions.length) {
    reactions.push(
      `Shrink for Mama. Love is easier when you're tiny~`,
      `Bags of meat don't get arcs. They get stepped on~`,
      `I'll reshape you until you understand what love means~`,
    );
  }

  const shrink = pick(rng, [
    `Feel that? Bones folding. World getting taller. That's Mama rewriting you~`,
    `Authority of Lust says: smaller. Obey while I laugh~`,
    `There we go — ${name} dropping a few sizes for Mama's entertainment~`,
    `Bug-scale suits you. Closer to the toes already~`,
  ]);

  return `${pick(rng, openers)} ${pick(rng, reactions)} ${shrink}`;
}

export async function generateStoryBeat(state: GameState, lastChoice: string): Promise<string> {
  const rng = createRng(hashSeed(state.seed, state.turns, 'story', lastChoice));
  const live = await chatComplete(
    'You write brief atmospheric RPG narration (2 sentences max) for a dark fantasy march. Expansive hooks, no Capella yet unless already known. Second person.',
    `Player:\n${playerBrief(state)}\nLast action: ${lastChoice}\nWrite the next story beat.`,
  );
  return live ?? offlineStory(state, lastChoice, rng);
}

export async function generateCapellaLine(state: GameState, lastChoice: string): Promise<string> {
  const rng = createRng(hashSeed(state.seed, state.turns, 'capella', lastChoice));
  const live = await chatComplete(
    CAPELLA_VOICE,
    `Player sheet:\n${playerBrief(state)}\nThey just did: "${lastChoice}"\nReact to THIS character specifically, then shrink-tease them. 2-3 sentences.`,
  );
  return live ?? offlineCapella(state, lastChoice, rng);
}

export async function generateCapellaCrushTaunt(
  state: GameState,
  kind: 'struggle' | 'crush' | 'toes',
): Promise<string> {
  const rng = createRng(hashSeed(state.seed, state.turns, kind, 'taunt'));
  const live = await chatComplete(
    CAPELLA_VOICE,
    `Player:\n${playerBrief(state)}\nSituation: ${kind === 'toes' ? 'they spawned bug-sized between your toes' : kind === 'struggle' ? 'they are struggling under your foot' : 'you just shrunk them and stepped'}. Taunt them by name. 2 sentences.`,
  );
  if (live) return live;
  if (kind === 'toes') {
    return pick(rng, [
      `${state.playerName}~ already in the toe-gap where Mama keeps favorites. Wriggle for love~`,
      `No prologue for a ${state.playerClass}. Just toes, heat, and ownership~`,
    ]);
  }
  if (kind === 'struggle') {
    return pick(rng, [
      `Struggle, ${state.playerName}. Mama likes the buzzing~`,
      `Aww, the ${state.playerClass} still thinks motion is freedom~`,
    ]);
  }
  return pick(rng, [
    `Shrunk, then stepped — recipe for ${state.playerName}~ Mama's kind like that.`,
    `Love looks like a sole from down there, little ${state.playerClass}~`,
  ]);
}

/** After a normal turn: expansive beat, then Capella interrupt + shrink pressure. */
export async function weaveCapellaTurn(state: GameState, lastChoice: string): Promise<GameState> {
  if (state.flags.crushed_by_capella) return state;
  const next = structuredClone(state);
  const story = await generateStoryBeat(next, lastChoice);
  const capella = await generateCapellaLine(next, lastChoice);
  pushLog(next, { kind: 'narration', text: story });
  pushLog(next, { kind: 'narration', text: `**Capella:** ${capella}` });
  next.stress = Math.min(next.maxStress, next.stress + 1);
  next.flags.capella_spoke = true;
  // Soft shrink preview — HP tick as body rebels
  if (next.turns >= 2 && next.hp > 1) {
    next.hp = Math.max(1, next.hp - 1);
    pushLog(next, {
      kind: 'system',
      text: 'Scale slips. You are fractionally smaller (−1 HP).',
    });
  }
  return next;
}
