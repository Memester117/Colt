import { CLASSES } from '../content/classes';
import { createRng, pick } from './rng';
import type { GameState, TimeOfDay, Weather } from './types';
import { pushLog, uid } from './helpers';

const WEATHERS: Weather[] = ['clear', 'mist', 'rain', 'ashwind', 'storm'];
const TIMES: TimeOfDay[] = ['dawn', 'day', 'dusk', 'night'];

export function createNewGame(playerName: string, classId: string, seed?: number): GameState {
  const classDef = CLASSES.find((c) => c.id === classId) ?? CLASSES[0]!;
  const actualSeed = seed ?? (Math.floor(Math.random() * 1e9) ^ Date.now());
  const rng = createRng(actualSeed);

  const state: GameState = {
    version: 1,
    seed: actualSeed,
    screen: 'play',
    playerName: playerName.trim() || 'Wanderer',
    playerClass: classDef.name,
    attributes: { ...classDef.attributes },
    hp: classDef.hp,
    maxHp: classDef.hp,
    stress: 0,
    maxStress: 10,
    coin: 12 + Math.floor(rng() * 8),
    day: 1,
    time: pick(rng, TIMES.slice(0, 3)),
    weather: pick(rng, WEATHERS.slice(0, 3)),
    locationId: 'hollowmere',
    inventory: classDef.gear.map((g) => ({ ...g })),
    npcs: {},
    flags: {},
    quests: {},
    clocks: {
      wolf_pressure: 1,
      fen_tide: 0,
      ridge_tension: 1,
      war_echo: 0,
    },
    chronicle: [
      {
        id: uid('chr'),
        day: 1,
        text: `${playerName.trim() || 'Wanderer'} the ${classDef.name} arrived in Hollowmere under ${pick(rng, ['a thin sky', 'low cloud', 'a copper dusk'])}.`,
        tags: ['arrival'],
        important: true,
      },
    ],
    log: [],
    choices: [],
    encounter: null,
    chapter: 1,
    turns: 0,
    lastSaveAt: Date.now(),
  };

  if (classDef.id === 'hearthwright') {
    state.flags.has_letter = true;
  }
  if (classDef.id === 'ashblade') {
    state.flags.has_war_token = true;
  }

  pushLog(state, {
    kind: 'narration',
    text: `You crest the last low hill and Hollowmere unfolds below — slate roofs, a stubborn chapel spire, smoke writing soft letters on the air. This is the Ashfall Marches. The war ended. The land did not get the memo.`,
  });
  pushLog(state, {
    kind: 'narration',
    text: `You are ${state.playerName}, a ${state.playerClass}. Coin in pocket, road behind you, and a town that could use someone who finishes what they start.`,
  });

  return state;
}

export function weatherLabel(w: Weather): string {
  switch (w) {
    case 'clear':
      return 'clear skies';
    case 'mist':
      return 'low mist';
    case 'rain':
      return 'steady rain';
    case 'ashwind':
      return 'an ash-bearing wind';
    case 'storm':
      return 'a breaking storm';
  }
}

export function timeLabel(t: TimeOfDay): string {
  switch (t) {
    case 'dawn':
      return 'dawn';
    case 'day':
      return 'day';
    case 'dusk':
      return 'dusk';
    case 'night':
      return 'night';
  }
}
