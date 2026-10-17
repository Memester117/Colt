import { ENCOUNTERS, encountersFor, type EncounterDef } from '../content/encounters';
import { getLocation } from '../content/locations';
import { getNpc } from '../content/npcs';
import { ATTR_LABEL, check } from './dice';
import { createRng, pick, chance, hashSeed } from './rng';
import { composeScene } from './scene';
import type { ActionInput, Choice, GameState, TimeOfDay, Weather } from './types';
import {
  addChronicle,
  addItem,
  advanceQuest,
  clamp,
  completeQuest,
  ensureQuest,
  flagTrue,
  hasItem,
  pushLog,
  removeItem,
  setNpcAttitude,
} from './helpers';
import { parseFreeText } from './parse';

const TIME_ORDER: TimeOfDay[] = ['dawn', 'day', 'dusk', 'night'];
const WEATHERS: Weather[] = ['clear', 'mist', 'rain', 'ashwind', 'storm'];

function advanceTime(state: GameState, hours: number, rng: () => number): void {
  let steps = Math.max(1, Math.round(hours / 3));
  while (steps-- > 0) {
    const idx = TIME_ORDER.indexOf(state.time);
    if (idx === TIME_ORDER.length - 1) {
      state.time = 'dawn';
      state.day += 1;
      if (chance(rng, 0.45)) state.weather = pick(rng, WEATHERS);
      // clocks tick daily
      state.clocks.wolf_pressure = (state.clocks.wolf_pressure ?? 0) + 1;
      state.clocks.fen_tide = (state.clocks.fen_tide ?? 0) + 1;
      state.clocks.ridge_tension = (state.clocks.ridge_tension ?? 0) + (flagTrue(state, 'serra_terms') ? 0 : 1);
      state.clocks.war_echo = (state.clocks.war_echo ?? 0) + (state.locationId === 'burntwatch' ? 2 : 0);
    } else {
      state.time = TIME_ORDER[idx + 1]!;
    }
  }
}

function applyStress(state: GameState, amount: number): void {
  state.stress = clamp(state.stress + amount, 0, state.maxStress);
  if (state.stress >= state.maxStress) {
    state.hp = clamp(state.hp - 2, 1, state.maxHp);
    state.stress = Math.floor(state.maxStress / 2);
    pushLog(state, {
      kind: 'system',
      text: 'Stress breaks over you like weather. You keep going, but something in you frays (−2 HP).',
    });
  }
}

function heal(state: GameState, amount: number): void {
  state.hp = clamp(state.hp + amount, 0, state.maxHp);
}

function startEncounter(state: GameState, def: EncounterDef, rng: () => number): void {
  state.encounter = {
    id: def.id,
    name: def.name,
    threat: def.threat,
    hp: def.hp,
    maxHp: def.hp,
    tags: def.tags,
    canFlee: def.canFlee,
  };
  pushLog(state, { kind: 'narration', text: pick(rng, def.intro) });
  applyStress(state, 1);
}

function maybeRandomEncounter(state: GameState, risk: 'low' | 'mid' | 'high', rng: () => number): boolean {
  if (state.encounter) return false;
  const p = risk === 'low' ? 0.08 : risk === 'mid' ? 0.28 : 0.48;
  const wolfBoost = (state.clocks.wolf_pressure ?? 0) > 4 && state.locationId === 'ashroad' ? 0.12 : 0;
  if (!chance(rng, p + wolfBoost)) return false;
  const pool = encountersFor(state.locationId);
  if (!pool.length) return false;
  startEncounter(state, pick(rng, pool), rng);
  return true;
}

function resolveRoll(
  state: GameState,
  choice: Choice,
  rng: () => number,
  bonus = 0,
): { success: boolean; total: number; dc: number } {
  const attr = choice.attribute ?? 'wits';
  const dc = choice.dc ?? 12;
  const result = check(rng, state.attributes, attr, dc, bonus);
  pushLog(state, {
    kind: 'roll',
    text: `${ATTR_LABEL[attr]} check: ${result.roll}${result.mod >= 0 ? '+' : ''}${result.mod} = ${result.total} vs DC ${dc} — ${result.success ? (result.crit ? 'critical success' : 'success') : result.fumble ? 'fumble' : 'failure'}`,
    roll: { label: ATTR_LABEL[attr], total: result.total, dc, success: result.success },
  });
  return { success: result.success, total: result.total, dc };
}

function talk(state: GameState, npcId: string, rng: () => number): void {
  const npc = getNpc(npcId);
  if (!npc) {
    pushLog(state, { kind: 'narration', text: 'No one answers. The Marches keep some silences on purpose.' });
    return;
  }
  if (!state.npcs[npcId]) state.npcs[npcId] = { met: true, attitude: 0, secretsKnown: [] };
  else state.npcs[npcId]!.met = true;

  const attitude = state.npcs[npcId]!.attitude;
  pushLog(state, { kind: 'narration', text: pick(rng, npc.greetings) });

  // Pick a topic keyed to flags / inventory / location
  const topicKeys = Object.keys(npc.topics);
  let topic = pick(rng, topicKeys);
  if (npcId === 'mira' && hasItem(state, 'letter')) topic = 'letter';
  if (npcId === 'mira' && (state.clocks.wolf_pressure ?? 0) >= 1) topic = chance(rng, 0.6) ? 'wolves' : topic;
  if (npcId === 'garrick') topic = 'apprentice';
  if (npcId === 'lina') topic = 'brother';
  if (npcId === 'fenwitch' && state.quests.apprentice) topic = chance(rng, 0.7) ? 'boy' : 'chapel';
  if (npcId === 'brenna' && hasItem(state, 'letter')) topic = 'letter';
  if (npcId === 'pilgrim') topic = chance(rng, 0.5) ? 'spiral' : 'road';
  if (npcId === 'tamsin') topic = chance(rng, 0.5) ? 'jobs' : 'chapel';
  if (npcId === 'serra') topic = 'camp';
  if (npcId === 'kel') topic = 'wolves';
  if (npcId === 'captain_rhel' && hasItem(state, 'dispatch')) topic = 'dispatch';
  if (npcId === 'echo') topic = flagTrue(state, 'boy_found') ? 'boy' : 'spiral';

  const lines = npc.topics[topic] ?? npc.topics[topicKeys[0]!]!;
  let line = pick(rng, lines);
  if (attitude <= -2) line = `${line} Their tone is winter-thin.`;
  if (attitude >= 2) line = `${line} There's warmth under the words.`;
  pushLog(state, { kind: 'narration', text: line });
  state.npcs[npcId]!.lastTopic = topic;

  // Quest hooks from conversation
  if (npc.questHook === 'wolves') {
    ensureQuest(state, 'wolves', 0);
    advanceQuest(state, 'wolves', 0);
  }
  if (npc.questHook === 'apprentice') {
    ensureQuest(state, 'apprentice', 0);
    if (npcId === 'fenwitch') {
      advanceQuest(state, 'apprentice', 1);
      state.flags.knows_chapel = true;
      pushLog(state, {
        kind: 'narration',
        text: 'Ila sketches a path in mud with a stick. "Follow the drowned steps. The chapel listens for feet."',
      });
      setNpcAttitude(state, 'fenwitch', 1);
    } else {
      advanceQuest(state, 'apprentice', 0);
    }
  }
  if (npc.questHook === 'chapel') {
    ensureQuest(state, 'chapel', 0);
    state.flags.knows_chapel = true;
    advanceQuest(state, 'chapel', 0);
  }
  if (npc.questHook === 'dispatch' && !state.flags.dispatch_taken) {
    pushLog(state, {
      kind: 'narration',
      text: 'Tamsin taps a sealed case on the board. "Burnt Watch. Don\'t open it. Opening it is its own adventure, and I already have enough plot."',
    });
  }
  if (npc.questHook === 'alliance') {
    ensureQuest(state, 'alliance', 0);
  }
  if (npcId === 'echo') {
    ensureQuest(state, 'chapel', 0);
    advanceQuest(state, 'chapel', 1);
    state.flags.boy_found = true;
    state.flags.knows_chapel = true;
    if (!hasItem(state, 'spiral_key')) {
      addItem(state, {
        id: 'spiral_key',
        name: 'Spiral key',
        description: 'Cold metal marked with a listening spiral.',
        tags: ['story', 'key'],
        quantity: 1,
      });
      pushLog(state, { kind: 'result', text: 'You take the spiral key from the altar niche. It feels heavier than metal.' });
    }
    advanceQuest(state, 'chapel', 2);
  }

  // Presence soft check for attitude
  const roll = check(rng, state.attributes, 'presence', 11 + Math.max(0, -attitude));
  if (roll.success) setNpcAttitude(state, npcId, 1);
  else if (roll.fumble) setNpcAttitude(state, npcId, -1);

  addChronicle(state, `Spoke with ${npc.name} about ${topic}.`, ['talk', npcId]);
}

function investigate(state: GameState, rng: () => number, success: boolean): void {
  const loc = getLocation(state.locationId);
  if (success) {
    const hook = pick(rng, loc.investigateHooks);
    pushLog(state, { kind: 'narration', text: `You find something: ${hook}` });
    if (loc.id === 'reedfen' || loc.id === 'millcreek') {
      state.flags.knows_chapel = true;
      pushLog(state, {
        kind: 'narration',
        text: 'The evidence leans toward a drowned chapel deeper in the fen — a place songs warn about and maps omit.',
      });
      ensureQuest(state, 'apprentice', 0);
    }
    if (loc.id === 'ashroad' || loc.id === 'burntwatch') {
      state.flags.saw_ashcamp = true;
      pushLog(state, {
        kind: 'narration',
        text: 'Fresh tracks climb toward a camp on the ridge. Ash Camp is not a rumor today.',
      });
    }
    if (loc.id === 'burntwatch' && chance(rng, 0.4)) {
      const pool = encountersFor('burntwatch');
      if (pool.length) startEncounter(state, pick(rng, pool), rng);
    }
    if (loc.id === 'candleinn' && chance(rng, 0.5)) {
      pushLog(state, {
        kind: 'narration',
        text: 'Brenna notices your snooping. "Curiosity is free. Consequences have a menu."',
      });
      setNpcAttitude(state, 'brenna', chance(rng, 0.5) ? 0 : -1);
    }
    addChronicle(state, `Investigated ${loc.name}: ${hook}`, ['investigate', loc.id]);
  } else {
    pushLog(state, {
      kind: 'narration',
      text: pick(rng, [
        'You search until your eyes ache. The place keeps its cards close.',
        'Nothing useful reveals itself — only the ordinary stubbornness of objects.',
        'A red herring would be more helpful than this silence.',
      ]),
    });
    applyStress(state, 1);
  }
}

function rest(state: GameState, rng: () => number, success: boolean): void {
  const loc = getLocation(state.locationId);
  const safe = loc.tags.includes('safe') || loc.tags.includes('inn');
  if (success) {
    const healed = safe ? 4 + Math.floor(rng() * 3) : 2 + Math.floor(rng() * 2);
    heal(state, healed);
    state.stress = clamp(state.stress - (safe ? 3 : 1), 0, state.maxStress);
    pushLog(state, {
      kind: 'result',
      text: safe
        ? `Sleep takes you kindly. You recover ${healed} HP and shed some stress.`
        : `You rest in fragments. Still, you mend by ${healed} HP.`,
    });
    if (safe && loc.id === 'candleinn' && state.coin >= 2) {
      state.coin -= 2;
      pushLog(state, { kind: 'system', text: 'Brenna collects 2 coin for bed and bowl.' });
    }
  } else {
    pushLog(state, {
      kind: 'narration',
      text: 'Rest frays. Dreams arrive wearing boots. You wake unrestored and slightly more suspicious of pillows.',
    });
    applyStress(state, 1);
    if (!safe && chance(rng, 0.45)) {
      const pool = encountersFor(state.locationId);
      if (pool.length) startEncounter(state, pick(rng, pool), rng);
    }
  }
  advanceTime(state, safe ? 6 : 4, rng);
}

function travel(state: GameState, to: string, rng: () => number): void {
  const from = getLocation(state.locationId);
  const exit = from.exits.find((e) => e.to === to);
  if (!exit) {
    pushLog(state, { kind: 'system', text: 'That path isn\'t open from here.' });
    return;
  }
  if (exit.requiresFlag && !flagTrue(state, exit.requiresFlag)) {
    pushLog(state, { kind: 'narration', text: 'You do not yet know enough of the way.' });
    return;
  }
  pushLog(state, {
    kind: 'narration',
    text: pick(rng, [
      `You set out: ${exit.label.toLowerCase()}. The Marches rearrange themselves around your decision.`,
      `Road underfoot. Sky overhead. ${exit.label}.`,
      `You leave ${from.name} behind and let the path argue with your legs.`,
    ]),
  });
  advanceTime(state, Math.max(1, exit.hours), rng);
  state.locationId = to;
  const dest = getLocation(to);
  addChronicle(state, `Traveled to ${dest.name}.`, ['travel', to]);

  if (to === 'sunken_chapel') {
    ensureQuest(state, 'apprentice', 0);
    advanceQuest(state, 'apprentice', 2);
    ensureQuest(state, 'chapel', 0);
    advanceQuest(state, 'chapel', 1);
  }
  if (to === 'ashcamp') {
    state.flags.saw_ashcamp = true;
    ensureQuest(state, 'alliance', 0);
  }
  if (to === 'burntwatch' && hasItem(state, 'dispatch')) {
    advanceQuest(state, 'dispatch', 1);
  }

  maybeRandomEncounter(state, exit.risk, rng);
}

function resolveCombat(state: GameState, choice: Choice, rng: () => number): void {
  const enc = state.encounter;
  if (!enc) return;

  if (choice.kind === 'flee') {
    const { success } = resolveRoll(state, choice, rng);
    if (success) {
      pushLog(state, {
        kind: 'result',
        text: 'You break contact — dignity optional, lungs mandatory. The threat does not follow.',
      });
      state.encounter = null;
      applyStress(state, 1);
      addChronicle(state, `Fled from ${enc.name}.`, ['combat', 'flee']);
    } else {
      const dmg = 2 + Math.floor(rng() * 3);
      state.hp = clamp(state.hp - dmg, 0, state.maxHp);
      pushLog(state, {
        kind: 'result',
        text: `Fleeing fails. ${enc.name} catches you for ${dmg} damage.`,
      });
      checkDefeat(state);
    }
    return;
  }

  const { success } = resolveRoll(state, { ...choice, dc: choice.dc ?? enc.threat }, rng);
  if (success) {
    const dmg = 4 + Math.floor(rng() * 5) + (choice.kind === 'fight' ? 1 : 0);
    enc.hp -= dmg;
    pushLog(state, { kind: 'result', text: `You land a decisive exchange (−${dmg} to ${enc.name}).` });
    if (enc.hp <= 0) {
      winEncounter(state, rng);
    } else {
      const counter = 1 + Math.floor(rng() * 3);
      state.hp = clamp(state.hp - counter, 0, state.maxHp);
      pushLog(state, { kind: 'result', text: `${enc.name} answers — you take ${counter} damage.` });
      checkDefeat(state);
    }
  } else {
    const dmg = 2 + Math.floor(rng() * 4);
    state.hp = clamp(state.hp - dmg, 0, state.maxHp);
    pushLog(state, {
      kind: 'result',
      text: `The exchange goes badly. You take ${dmg} damage as ${enc.name} presses in.`,
    });
    applyStress(state, 1);
    checkDefeat(state);
  }
}

function winEncounter(state: GameState, rng: () => number): void {
  const enc = state.encounter!;
  const def = ENCOUNTERS.find((e) => e.id === enc.id);
  pushLog(state, { kind: 'result', text: `You prevail over ${enc.name}. The quiet afterward feels earned.` });
  state.encounter = null;
  state.coin += 2 + Math.floor(rng() * 5);
  if (def?.loot) {
    for (const item of def.loot) {
      addItem(state, item);
      pushLog(state, { kind: 'system', text: `Gained: ${item.name}` });
    }
  }
  if (def?.onWinFlags) {
    for (const f of def.onWinFlags) state.flags[f] = true;
  }
  if (enc.id === 'ash_wolves') {
    ensureQuest(state, 'wolves', 0);
    advanceQuest(state, 'wolves', 1);
    state.clocks.wolf_pressure = Math.max(0, (state.clocks.wolf_pressure ?? 1) - 2);
  }
  if (def?.chronicle) addChronicle(state, def.chronicle, ['combat', enc.id], true);
  else addChronicle(state, `Defeated ${enc.name}.`, ['combat', enc.id], true);
}

function checkDefeat(state: GameState): void {
  if (state.hp > 0) return;
  state.hp = 1;
  state.stress = clamp(state.stress + 3, 0, state.maxStress);
  state.coin = Math.max(0, state.coin - 5);
  state.encounter = null;
  state.locationId = 'hollowmere';
  state.time = 'dusk';
  pushLog(state, {
    kind: 'narration',
    text: 'Darkness. Then hands — maybe kind, maybe mercenary. You wake in Hollowmere with a thinner purse, a louder heartbeat, and the humiliating gift of a second chance.',
  });
  addChronicle(state, 'Fell in the Marches and was dragged back to Hollowmere.', ['defeat'], true);
}

function special(state: GameState, choice: Choice, rng: () => number): boolean {
  switch (choice.id) {
    case 'turn_in_wolves': {
      if (!hasItem(state, 'wolf_ear')) return true;
      removeItem(state, 'wolf_ear');
      ensureQuest(state, 'wolves', 0);
      advanceQuest(state, 'wolves', 2);
      completeQuest(state, 'wolves');
      state.coin += 15;
      setNpcAttitude(state, 'mira', 2);
      pushLog(state, {
        kind: 'narration',
        text: 'Mira weighs the proof, then your character. "Paid in full. The east bend will sleep easier — for a week. That\'s a local eternity."',
      });
      pushLog(state, { kind: 'system', text: 'Received 15 coin and Mira\'s favor.' });
      return true;
    }
    case 'deliver_letter': {
      if (!hasItem(state, 'letter')) return true;
      removeItem(state, 'letter');
      ensureQuest(state, 'letter', 0);
      advanceQuest(state, 'letter', 1);
      completeQuest(state, 'letter');
      setNpcAttitude(state, 'brenna', 2);
      heal(state, 2);
      pushLog(state, {
        kind: 'narration',
        text: 'Brenna reads in silence, then folds the letter like a truce. "Stay for stew. On the house. The house insists."',
      });
      return true;
    }
    case 'take_dispatch': {
      ensureQuest(state, 'dispatch', 0);
      advanceQuest(state, 'dispatch', 0);
      state.flags.dispatch_taken = true;
      addItem(state, {
        id: 'dispatch',
        name: 'Sealed dispatch',
        description: 'Wax the color of old bruises. Do not open.',
        tags: ['quest', 'story'],
        quantity: 1,
      });
      pushLog(state, {
        kind: 'narration',
        text: 'Tamsin presses the case into your hands. "Burnt Watch. Captain Rhel, if the tower still answers to names. Coin on delivery — plus whatever story you survive into."',
      });
      return true;
    }
    case 'deliver_dispatch': {
      if (!hasItem(state, 'dispatch')) return true;
      removeItem(state, 'dispatch');
      ensureQuest(state, 'dispatch', 0);
      advanceQuest(state, 'dispatch', 2);
      completeQuest(state, 'dispatch');
      setNpcAttitude(state, 'captain_rhel', 2);
      state.flags.saw_ashcamp = true;
      state.coin += 20;
      pushLog(state, {
        kind: 'narration',
        text: 'Captain Rhel breaks the seal with ceremonial care. Orders rearrange the air. "Ash Camp will want to know we still keep time. You may tell Serra the Watch remembers."',
      });
      pushLog(state, { kind: 'system', text: 'Dispatch delivered. +20 coin. Path to Ash Camp becomes clearer.' });
      return true;
    }
    case 'rescue_boy': {
      const { success } = resolveRoll(state, choice, rng);
      if (success) {
        state.flags.boy_rescued = true;
        advanceQuest(state, 'apprentice', 3);
        pushLog(state, {
          kind: 'narration',
          text: 'The apprentice takes your sleeve with flour-pale fingers. Together you wade toward daylight. Behind you, water settles into something like applause.',
        });
        addChronicle(state, 'Rescued the mill apprentice from the sunken chapel.', ['quest', 'apprentice'], true);
        completeQuest(state, 'chapel');
      } else {
        applyStress(state, 2);
        state.hp = clamp(state.hp - 2, 1, state.maxHp);
        pushLog(state, {
          kind: 'narration',
          text: 'The chapel does not yield easily. Cold water and colder doubt. You can try again — the boy is still humming.',
        });
      }
      return true;
    }
    case 'return_boy': {
      if (!flagTrue(state, 'boy_rescued')) return true;
      completeQuest(state, 'apprentice');
      setNpcAttitude(state, 'garrick', 3);
      setNpcAttitude(state, 'lina', 3);
      state.coin += 12;
      heal(state, 3);
      pushLog(state, {
        kind: 'narration',
        text: 'Garrick makes a sound that is not quite a sob. Lina punches your arm in gratitude. The mill wheel seems to turn lighter. For a moment, the Marches feel finished in one small place.',
      });
      return true;
    }
    case 'ask_alliance': {
      const bonus = state.npcs.serra?.attitude ?? 0;
      const { success } = resolveRoll(state, choice, rng, bonus);
      if (success) {
        state.flags.serra_terms = true;
        ensureQuest(state, 'alliance', 0);
        advanceQuest(state, 'alliance', 1);
        setNpcAttitude(state, 'serra', 1);
        pushLog(state, {
          kind: 'narration',
          text: 'Serra nods once. "Shared watches on the Ashroad. Shared grain in hard weeks. Mira says yes in writing, and we pretend trust until it becomes real."',
        });
      } else {
        setNpcAttitude(state, 'serra', -1);
        pushLog(state, {
          kind: 'narration',
          text: 'Serra\'s mouth flattens. "Come back when you sound like someone who pays costs, not someone who narrates them."',
        });
      }
      return true;
    }
    case 'relay_terms': {
      advanceQuest(state, 'alliance', 2);
      completeQuest(state, 'alliance');
      setNpcAttitude(state, 'mira', 2);
      state.clocks.ridge_tension = 0;
      state.coin += 10;
      pushLog(state, {
        kind: 'narration',
        text: 'Mira listens, grim and grateful. "Tell Serra we agree — and that if she betrays the town, I will become historically inconvenient." A fragile alliance settles over the Marches like useful weather.',
      });
      addChronicle(state, 'Brokered alliance between Hollowmere and Ash Camp.', ['quest', 'alliance'], true);
      if (state.chapter < 3) state.chapter = 3;
      return true;
    }
    case 'use_herbs': {
      if (!removeItem(state, 'herbs')) return true;
      heal(state, 5);
      pushLog(state, { kind: 'result', text: 'Bitter herbs, better blood. You recover 5 HP.' });
      return true;
    }
    default:
      return false;
  }
}

function customAction(state: GameState, text: string, rng: () => number): void {
  const roll = check(rng, state.attributes, pick(rng, ['wits', 'presence', 'spirit', 'grace'] as const), 13);
  pushLog(state, {
    kind: 'choice',
    text: `You try: "${text}"`,
  });
  pushLog(state, {
    kind: 'roll',
    text: `Improvised attempt: ${roll.total} vs DC 13 — ${roll.success ? 'success' : 'failure'}`,
    roll: { label: 'Improvised', total: roll.total, dc: 13, success: roll.success },
  });
  if (roll.success) {
    pushLog(state, {
      kind: 'narration',
      text: pick(rng, [
        'Against modest odds, it works. The Marches allow you a small authorship over the moment.',
        'Your odd approach finds a seam in the situation. Something useful shifts.',
        'Fortune, skill, or stubborn charm — the attempt lands.',
      ]),
    });
    if (chance(rng, 0.4)) {
      state.coin += 1 + Math.floor(rng() * 3);
      pushLog(state, { kind: 'system', text: 'A little coin finds its way to you.' });
    } else {
      heal(state, 1);
      setNpcAttitude(state, pick(rng, getLocation(state.locationId).locals.concat(['mira'])), 1);
    }
    addChronicle(state, `Improvised successfully: ${text}`, ['custom']);
  } else {
    pushLog(state, {
      kind: 'narration',
      text: pick(rng, [
        'The world declines your suggestion. Reality keeps its own script.',
        'It almost works — which is a poet\'s way of saying it doesn\'t.',
        'You invent a clever plan. The Marches invent a counterplan.',
      ]),
    });
    applyStress(state, 1);
    if (chance(rng, 0.25)) maybeRandomEncounter(state, 'mid', rng);
  }
}

export function resolveAction(state: GameState, input: ActionInput): GameState {
  let next = structuredClone(state);
  const rng = createRng(hashSeed(next.seed, next.turns, input.choiceId ?? input.freeText ?? 'x', next.day));

  let choice: Choice | null = null;
  if (input.choiceId) {
    choice = next.choices.find((c) => c.id === input.choiceId) ?? null;
  } else if (input.freeText) {
    choice = parseFreeText(next, input.freeText);
  }
  if (!choice) {
    pushLog(next, { kind: 'system', text: 'Nothing comes of that. Try a clearer intent, or pick a path below.' });
    return composeScene(next, false);
  }

  pushLog(next, { kind: 'choice', text: `> ${choice.label}` });
  next.turns += 1;

  if (special(next, choice, rng)) {
    // handled
  } else if (next.encounter && ['fight', 'sneak', 'flee', 'bargain'].includes(choice.kind)) {
    resolveCombat(next, choice, rng);
  } else {
    switch (choice.kind) {
      case 'talk':
        if (choice.targetId) talk(next, choice.targetId, rng);
        advanceTime(next, 1, rng);
        break;
      case 'investigate': {
        const { success } = resolveRoll(next, choice, rng);
        investigate(next, rng, success);
        advanceTime(next, 1, rng);
        break;
      }
      case 'rest': {
        const { success } = resolveRoll(next, choice, rng);
        rest(next, rng, success);
        break;
      }
      case 'travel':
        if (choice.targetId) travel(next, choice.targetId, rng);
        break;
      case 'wait': {
        pushLog(next, {
          kind: 'narration',
          text: pick(rng, [
            'You let time pass. The Marches continue without needing your permission.',
            'Watching becomes a kind of listening. Hours thin themselves out.',
            'You wait. A dog barks somewhere. History does not.',
          ]),
        });
        advanceTime(next, 3, rng);
        if (chance(rng, 0.2)) maybeRandomEncounter(next, 'low', rng);
        break;
      }
      case 'help':
      case 'bargain':
      case 'use':
      case 'sneak':
      case 'fight': {
        const { success } = resolveRoll(next, choice, rng);
        pushLog(next, {
          kind: 'narration',
          text: success
            ? pick(rng, [
                'It works well enough to change the next few minutes.',
                'Your approach finds purchase. The moment bends.',
              ])
            : pick(rng, [
                'It falters. You adapt, slightly bruised in pride.',
                'The attempt teaches you what not to try twice.',
              ]),
        });
        if (!success) applyStress(next, 1);
        advanceTime(next, 1, rng);
        break;
      }
      case 'custom':
        customAction(next, choice.label, rng);
        advanceTime(next, 1, rng);
        break;
      case 'flee':
        pushLog(next, { kind: 'narration', text: 'There is nothing immediate to flee — only the ordinary gravity of the day.' });
        break;
    }
  }

  // Chapter flavor
  if (next.turns === 15 && next.chapter === 1) {
    next.chapter = 2;
    pushLog(next, {
      kind: 'system',
      text: 'Chapter II — The Marches begin to recognize your silhouette.',
    });
  }

  next.lastSaveAt = Date.now();
  const shouldNarrateLocation = !next.encounter;
  next = composeScene(next, shouldNarrateLocation);
  return next;
}

export function beginPlay(state: GameState): GameState {
  return composeScene(structuredClone(state), true);
}
