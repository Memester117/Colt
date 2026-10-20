import { ENCOUNTERS, encountersFor, type EncounterDef } from '../content/encounters';
import { getLocation } from '../content/locations';
import { getNpc } from '../content/npcs';
import {
  CAPELLA_APPROACH,
  CAPELLA_BETWEEN_TOES,
  CAPELLA_CRUSH,
  CAPELLA_FORESHADOW,
  CAPELLA_SHRINK,
  CAPELLA_STEP,
  CAPELLA_STRUGGLE,
  crushLockMs,
  doomChoicesForLoops,
} from '../content/capella';
import {
  COMBAT_HIT,
  FLEE,
  IMPROV,
  INVESTIGATE,
  REST,
  TRAVEL,
  gradeFromCheck,
  type OutcomeGrade,
} from '../content/outcomes';
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
): { success: boolean; total: number; dc: number; grade: OutcomeGrade; crit: boolean; fumble: boolean } {
  const attr = choice.attribute ?? 'wits';
  const dc = choice.dc ?? 12;
  const result = check(rng, state.attributes, attr, dc, bonus);
  const grade = gradeFromCheck(result);
  const gradeLabel: Record<OutcomeGrade, string> = {
    crit: 'critical',
    success: 'success',
    mixed: result.success ? 'bare success' : 'near miss',
    fail: 'failure',
    fumble: 'fumble',
  };
  pushLog(state, {
    kind: 'roll',
    text: `${ATTR_LABEL[attr]}: ${result.roll}${result.mod >= 0 ? '+' : ''}${result.mod} = ${result.total} vs ${dc} — ${gradeLabel[grade]}`,
    roll: { label: ATTR_LABEL[attr], total: result.total, dc, success: result.success },
  });
  return {
    success: result.success,
    total: result.total,
    dc,
    grade,
    crit: result.crit,
    fumble: result.fumble,
  };
}

function lineFrom(
  bank: Record<OutcomeGrade, readonly string[]> | { crit: readonly string[]; success: readonly string[]; mixed: readonly string[]; fail: readonly string[]; fumble: readonly string[] },
  grade: OutcomeGrade,
  rng: () => number,
): string {
  const list = bank[grade] ?? bank.fail;
  return pick(rng, list);
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
  const greet = pick(rng, npc.greetings);
  const approach =
    attitude <= -2
      ? pick(rng, ['They do not bother hiding dislike.', 'The air between you goes thin.'])
      : attitude >= 2
        ? pick(rng, ['They soften when they see you.', 'Recognition warms the greeting.'])
        : chance(rng, 0.4)
          ? pick(rng, ['They size you up in a glance.', 'A beat of silence, then words.'])
          : null;
  pushLog(state, { kind: 'narration', text: approach ? `${greet} ${approach}` : greet });

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

function investigate(state: GameState, rng: () => number, grade: OutcomeGrade): void {
  const loc = getLocation(state.locationId);
  const found = grade === 'crit' || grade === 'success' || (grade === 'mixed' && chance(rng, 0.65));
  pushLog(state, { kind: 'narration', text: lineFrom(INVESTIGATE, grade, rng) });

  if (found) {
    const hook = pick(rng, loc.investigateHooks);
    pushLog(state, { kind: 'narration', text: `You find: ${hook}` });
    if (loc.id === 'reedfen' || loc.id === 'millcreek') {
      state.flags.knows_chapel = true;
      pushLog(state, {
        kind: 'narration',
        text: pick(rng, [
          'The evidence leans toward a drowned chapel deeper in the fen — a place songs warn about and maps omit.',
          'Fen mud keeps footprints like gossip. They point toward drowned stone.',
        ]),
      });
      ensureQuest(state, 'apprentice', 0);
    }
    if (loc.id === 'ashroad' || loc.id === 'burntwatch') {
      state.flags.saw_ashcamp = true;
      pushLog(state, {
        kind: 'narration',
        text: pick(rng, [
          'Fresh tracks climb toward a camp on the ridge. Ash Camp is not a rumor today.',
          'Boot-scuffs and a discarded ration wrap: people live above the burn line.',
        ]),
      });
    }
    if (grade === 'crit' && chance(rng, 0.45)) {
      state.coin += 1 + Math.floor(rng() * 3);
      pushLog(state, { kind: 'system', text: 'A forgotten coin or two finds your palm.' });
    }
    if (grade === 'mixed') {
      applyStress(state, 1);
      if (chance(rng, 0.3)) {
        state.hp = clamp(state.hp - 1, 1, state.maxHp);
        pushLog(state, { kind: 'result', text: 'A splinter, a slip, a small price (−1 HP).' });
      }
    }
    if (loc.id === 'burntwatch' && chance(rng, grade === 'crit' ? 0.55 : 0.35)) {
      const pool = encountersFor('burntwatch');
      if (pool.length) startEncounter(state, pick(rng, pool), rng);
    }
    if (loc.id === 'candleinn' && chance(rng, 0.45)) {
      pushLog(state, {
        kind: 'narration',
        text: pick(rng, [
          'Brenna notices your snooping. "Curiosity is free. Consequences have a menu."',
          'Brenna wipes a glass. "Find what you need. Leave what isn\'t yours."',
        ]),
      });
      setNpcAttitude(state, 'brenna', chance(rng, 0.55) ? 0 : -1);
    }
    addChronicle(state, `Investigated ${loc.name}: ${hook}`, ['investigate', loc.id]);
  } else {
    applyStress(state, grade === 'fumble' ? 2 : 1);
    if (grade === 'fumble' && chance(rng, 0.4)) {
      const locals = getLocation(state.locationId).locals;
      if (locals.length) setNpcAttitude(state, pick(rng, locals), -1);
    }
    if (grade === 'mixed') {
      // Near miss still hints
      pushLog(state, {
        kind: 'narration',
        text: pick(rng, [
          'You almost had it — a shape of meaning that slips. Tomorrow\'s eyes might catch it.',
          'A partial pattern: enough to wonder, not enough to act.',
        ]),
      });
    }
  }
}

function rest(state: GameState, rng: () => number, grade: OutcomeGrade): void {
  const loc = getLocation(state.locationId);
  const safe = loc.tags.includes('safe') || loc.tags.includes('inn');
  pushLog(state, { kind: 'narration', text: lineFrom(REST, grade, rng) });

  if (grade === 'crit' || grade === 'success' || grade === 'mixed') {
    const base = safe ? 4 : 2;
    const bonus = grade === 'crit' ? 3 : grade === 'success' ? Math.floor(rng() * 3) : 1;
    const healed = base + bonus;
    heal(state, healed);
    const stressRelief = grade === 'crit' ? (safe ? 4 : 2) : grade === 'success' ? (safe ? 3 : 1) : 1;
    state.stress = clamp(state.stress - stressRelief, 0, state.maxStress);
    pushLog(state, { kind: 'result', text: `You recover ${healed} HP.` });
    if (grade === 'mixed') applyStress(state, 1);
    if (safe && loc.id === 'candleinn' && state.coin >= 2) {
      state.coin -= 2;
      pushLog(state, { kind: 'system', text: 'Brenna collects 2 coin for bed and bowl.' });
    }
  } else {
    applyStress(state, grade === 'fumble' ? 2 : 1);
    if (!safe && (grade === 'fumble' || chance(rng, 0.45))) {
      const pool = encountersFor(state.locationId);
      if (pool.length) startEncounter(state, pick(rng, pool), rng);
    }
  }
  advanceTime(state, safe ? 6 : 4, rng);
}

function travelRoadEvent(state: GameState, risk: 'low' | 'mid' | 'high', rng: () => number): void {
  const roll = rng();
  if (roll < 0.28) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.uneventful) });
    return;
  }
  if (roll < 0.4) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.weather) });
    if (state.weather === 'storm' || state.weather === 'ashwind') applyStress(state, 1);
    return;
  }
  if (roll < 0.52) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.find_coin) });
    state.coin += 1 + Math.floor(rng() * (risk === 'high' ? 4 : 3));
    return;
  }
  if (roll < 0.64) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.traveler) });
    if (chance(rng, 0.35)) {
      const tip = pick(rng, [
        'They mention ash-wolves favoring the east bend after dusk.',
        'They swear the fen sings when the moon is mean.',
        'They tip you toward Burnt Watch: "Still listening. Bring manners."',
      ]);
      pushLog(state, { kind: 'narration', text: tip });
    }
    return;
  }
  if (roll < 0.76) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.omen) });
    if (chance(rng, 0.4)) state.flags.knows_chapel = true;
    return;
  }
  if (roll < 0.86) {
    pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.snag) });
    applyStress(state, 1);
    if (chance(rng, 0.35)) {
      state.hp = clamp(state.hp - 1, 1, state.maxHp);
      pushLog(state, { kind: 'result', text: 'A scrape for the road (−1 HP).' });
    }
    return;
  }
  // Remaining chance: combat handled by caller via maybeRandomEncounter
  pushLog(state, { kind: 'narration', text: pick(rng, TRAVEL.uneventful) });
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
      `You set out toward ${getLocation(to).name}.`,
      `Leaving ${from.name} behind, you take the path to ${getLocation(to).name}.`,
      `${exit.label}. The road accepts the decision.`,
    ]),
  });
  travelRoadEvent(state, exit.risk, rng);
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
    const { success, grade } = resolveRoll(state, choice, rng);
    pushLog(state, { kind: 'result', text: lineFrom(FLEE, grade, rng) });
    if (success) {
      state.encounter = null;
      applyStress(state, grade === 'mixed' ? 2 : 1);
      if (grade === 'mixed') {
        const dmg = 1 + Math.floor(rng() * 2);
        state.hp = clamp(state.hp - dmg, 1, state.maxHp);
        pushLog(state, { kind: 'result', text: `A parting scratch (−${dmg} HP).` });
      }
      addChronicle(state, `Fled from ${enc.name}.`, ['combat', 'flee']);
    } else {
      const dmg = (grade === 'fumble' ? 3 : 2) + Math.floor(rng() * 3);
      state.hp = clamp(state.hp - dmg, 0, state.maxHp);
      pushLog(state, { kind: 'result', text: `${enc.name} catches you for ${dmg} damage.` });
      checkDefeat(state);
    }
    return;
  }

  const { success, grade } = resolveRoll(state, { ...choice, dc: choice.dc ?? enc.threat }, rng);
  pushLog(state, { kind: 'result', text: lineFrom(COMBAT_HIT, grade, rng) });

  if (success) {
    let dmg = 4 + Math.floor(rng() * 5) + (choice.kind === 'fight' ? 1 : 0);
    if (grade === 'crit') dmg += 3;
    if (grade === 'mixed') dmg = Math.max(2, dmg - 2);
    enc.hp -= dmg;
    pushLog(state, { kind: 'system', text: `−${dmg} to ${enc.name}.` });
    if (grade === 'mixed') {
      const self = 1 + Math.floor(rng() * 2);
      state.hp = clamp(state.hp - self, 0, state.maxHp);
      pushLog(state, { kind: 'result', text: `You take ${self} in the trade.` });
    }
    if (enc.hp <= 0) {
      winEncounter(state, rng, grade);
    } else if (grade !== 'crit' || chance(rng, 0.35)) {
      const counter = grade === 'crit' ? Math.floor(rng() * 2) : 1 + Math.floor(rng() * 3);
      if (counter > 0) {
        state.hp = clamp(state.hp - counter, 0, state.maxHp);
        pushLog(state, { kind: 'result', text: `${enc.name} answers — ${counter} damage.` });
        checkDefeat(state);
      }
    }
  } else {
    const dmg = (grade === 'fumble' ? 3 : 2) + Math.floor(rng() * 4);
    state.hp = clamp(state.hp - dmg, 0, state.maxHp);
    pushLog(state, { kind: 'result', text: `You take ${dmg} damage.` });
    applyStress(state, grade === 'fumble' ? 2 : 1);
    checkDefeat(state);
  }
}

function winEncounter(state: GameState, rng: () => number, grade: OutcomeGrade = 'success'): void {
  const enc = state.encounter!;
  const def = ENCOUNTERS.find((e) => e.id === enc.id);
  pushLog(state, {
    kind: 'result',
    text: pick(rng, [
      `You prevail over ${enc.name}. The quiet afterward feels earned.`,
      `${enc.name} yields the ground. You keep your breath and your name.`,
      `End of exchange. ${enc.name} is no longer a problem with teeth.`,
    ]),
  });
  state.encounter = null;
  const lootCoin = 2 + Math.floor(rng() * 5) + (grade === 'crit' ? 3 : 0);
  state.coin += lootCoin;
  pushLog(state, { kind: 'system', text: `+${lootCoin} coin.` });
  if (def?.loot) {
    for (const item of def.loot) {
      addItem(state, item);
      pushLog(state, { kind: 'system', text: `Gained: ${item.name}` });
    }
  }
  if (grade === 'crit' && chance(rng, 0.5)) {
    heal(state, 2);
    pushLog(state, { kind: 'result', text: 'A clean win steadies you (+2 HP).' });
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
  const attr = pick(rng, ['wits', 'presence', 'spirit', 'grace'] as const);
  const roll = check(rng, state.attributes, attr, 13);
  const grade = gradeFromCheck(roll);
  pushLog(state, {
    kind: 'choice',
    text: `You try: "${text}"`,
  });
  pushLog(state, {
    kind: 'roll',
    text: `Improvised (${ATTR_LABEL[attr]}): ${roll.total} vs 13 — ${grade}`,
    roll: { label: 'Improvised', total: roll.total, dc: 13, success: roll.success },
  });
  pushLog(state, { kind: 'narration', text: lineFrom(IMPROV, grade, rng) });
  if (roll.success) {
    if (grade === 'crit' || chance(rng, 0.45)) {
      state.coin += 1 + Math.floor(rng() * 4);
      pushLog(state, { kind: 'system', text: 'A little coin finds its way to you.' });
    } else {
      heal(state, grade === 'mixed' ? 1 : 2);
      const locals = getLocation(state.locationId).locals.concat(['mira']);
      setNpcAttitude(state, pick(rng, locals), 1);
    }
    if (grade === 'mixed') applyStress(state, 1);
    addChronicle(state, `Improvised successfully: ${text}`, ['custom']);
  } else {
    applyStress(state, grade === 'fumble' ? 2 : 1);
    if (grade === 'mixed') {
      heal(state, 1);
      pushLog(state, { kind: 'result', text: 'A scrap of progress survives the failure (+1 HP).' });
    }
    if (grade === 'fumble' || chance(rng, 0.28)) maybeRandomEncounter(state, 'mid', rng);
  }
}

function loopCount(state: GameState): number {
  const n = state.flags.capella_loops;
  return typeof n === 'number' ? n : Number(n) || 0;
}

export function resolveAction(state: GameState, input: ActionInput): GameState {
  let next = structuredClone(state);
  const rng = createRng(hashSeed(next.seed, next.turns, input.choiceId ?? input.freeText ?? 'x', next.day));
  const loops = loopCount(next);

  let choice: Choice | null = null;
  if (input.choiceId) {
    choice = next.choices.find((c) => c.id === input.choiceId) ?? null;
  } else if (input.freeText) {
    choice = parseFreeText(next, input.freeText);
  }
  if (!choice) {
    if (flagTrue(next, 'crushed_by_capella')) {
      pushLog(next, { kind: 'narration', text: pick(rng, CAPELLA_STRUGGLE) });
      // Struggling extends the lock
      const until = Number(next.flags.crush_unlock_at) || 0;
      next.flags.crush_unlock_at = Math.max(until, Date.now()) + 12000;
      return next;
    }
    pushLog(next, { kind: 'system', text: 'Nothing comes of that. Try a clearer intent, or pick a path below.' });
    return composeScene(next, false);
  }

  pushLog(next, { kind: 'choice', text: `> ${choice.label}` });

  // Fake crush-screen buttons — never free you
  if (
    flagTrue(next, 'crushed_by_capella') &&
    ['capella_struggle', 'capella_beg', 'capella_crawl', 'capella_escape'].includes(choice.id)
  ) {
    pushLog(next, { kind: 'narration', text: pick(rng, CAPELLA_STRUGGLE) });
    const until = Number(next.flags.crush_unlock_at) || Date.now();
    next.flags.crush_unlock_at = until + 18000;
    next.choices = crushScreenChoices(false);
    return next;
  }

  if (choice.id === 'capella_restart') {
    const unlockAt = Number(next.flags.crush_unlock_at) || 0;
    if (Date.now() < unlockAt) {
      pushLog(next, {
        kind: 'narration',
        text: pick(rng, [
          'Not yet. Capella is still enjoying the press.',
          'The sole does not lift on request.',
          '"Patience~" Capella croons. The lock holds.',
        ]),
      });
      next.choices = crushScreenChoices(false);
      return next;
    }

    next.flags.crushed_by_capella = false;
    next.flags.capella_phase = 0;
    next.flags.crush_unlock_at = 0;
    next.turns = 0;
    next.encounter = null;
    next.hp = next.maxHp;
    next.stress = 0;
    next.locationId = 'hollowmere';
    next.log = [];

    const nextDoom = doomChoicesForLoops(loopCount(next));
    if (nextDoom <= 0) {
      // Spawn already bug-sized between her toes
      triggerCapellaCrush(next, rng, { betweenToes: true });
      next.lastSaveAt = Date.now();
      return next;
    }

    pushLog(next, {
      kind: 'narration',
      text:
        loops === 0
          ? 'You wake in Hollowmere. The Marches smell like rain again. Something feels unfinished.'
          : `You wake in Hollowmere with perfume still in your mouth. Capella is closer this time — fewer steps until her foot. (${nextDoom} choice${nextDoom === 1 ? '' : 's'} left.)`,
    });
    next = composeScene(next, true);
    next.lastSaveAt = Date.now();
    return next;
  }

  if (flagTrue(next, 'crushed_by_capella')) {
    next.choices = crushScreenChoices(Date.now() >= (Number(next.flags.crush_unlock_at) || 0));
    return next;
  }

  next.turns += 1;

  if (special(next, choice, rng)) {
    // handled
  } else if (next.encounter) {
    next.encounter = null;
    pushLog(next, {
      kind: 'narration',
      text:
        loops === 0
          ? 'The threat breaks off suddenly — as if the scene lost interest in finishing the fight.'
          : 'The threat dissolves mid-lunge. Something hungrier than wolves has claimed the scene.',
    });
  } else if (choice.kind === 'travel' && choice.targetId) {
    travel(next, choice.targetId, rng);
    next.encounter = null;
  } else if (choice.kind === 'talk' && choice.targetId) {
    talk(next, choice.targetId, rng);
  } else {
    pushLog(next, {
      kind: 'narration',
      text: pick(
        rng,
        loops === 0
          ? [
              'You act. The Marches answer in ordinary ways.',
              'It works well enough. The day continues.',
              'Done. Dust settles. Nothing seems wrong — yet.',
            ]
          : [
              'You act. The Marches answer — briefly — before a sweeter voice overwrites the script.',
              'Your choice lands. Reality files it under "cute attempt."',
              'Done. The road shivers like it knows what owns the ending.',
            ],
      ),
    });
  }

  const doomAt = doomChoicesForLoops(loops);
  if (doomAt <= 0 || next.turns >= doomAt) {
    triggerCapellaCrush(next, rng, { betweenToes: doomAt <= 0 });
  } else {
    // First loop: zero foreshadowing. Later loops: Capella teases.
    if (loops > 0) {
      pushLog(next, { kind: 'narration', text: pick(rng, CAPELLA_FORESHADOW) });
    }
    next.flags.capella_phase = next.turns;
    next = composeScene(next, true);
  }

  next.lastSaveAt = Date.now();
  return next;
}

function crushScreenChoices(unlocked: boolean): Choice[] {
  const fake: Choice[] = [
    { id: 'capella_struggle', label: 'Struggle', kind: 'custom', group: 'pace' },
    { id: 'capella_beg', label: 'Beg', kind: 'custom', group: 'pace' },
    { id: 'capella_crawl', label: 'Crawl away', kind: 'custom', group: 'pace' },
    { id: 'capella_escape', label: 'Escape', kind: 'custom', group: 'pace' },
  ];
  if (!unlocked) return fake;
  return [
    ...fake,
    {
      id: 'capella_restart',
      label: 'Wake again…?',
      kind: 'custom',
      group: 'focus',
      hint: 'if she allows it',
    },
  ];
}

function triggerCapellaCrush(
  state: GameState,
  rng: () => number,
  opts: { betweenToes?: boolean } = {},
): void {
  const loops = loopCount(state);
  state.encounter = null;
  state.flags.crushed_by_capella = true;
  state.flags.capella_phase = 99;
  state.flags.capella_loops = loops + 1;
  state.flags.crush_unlock_at = Date.now() + crushLockMs(loops);
  state.flags.between_toes = Boolean(opts.betweenToes);
  state.hp = 0;
  state.stress = state.maxStress;

  if (opts.betweenToes) {
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_BETWEEN_TOES) });
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_STEP) });
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_CRUSH) });
  } else {
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_APPROACH) });
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_SHRINK) });
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_STEP) });
    pushLog(state, { kind: 'narration', text: pick(rng, CAPELLA_CRUSH) });
  }

  pushLog(state, {
    kind: 'system',
    text: opts.betweenToes
      ? 'Ending — Bug-sized between Capella\'s toes.'
      : 'Ending — Shrunk, then stepped on by Capella Emerada Lugunica.',
  });
  addChronicle(
    state,
    opts.betweenToes
      ? 'Spawned between Capella\'s toes and crushed.'
      : 'Shrunk by Capella, then crushed under her foot.',
    ['ending', 'capella'],
    true,
  );
  state.choices = crushScreenChoices(false);
}

export function beginPlay(state: GameState): GameState {
  return composeScene(structuredClone(state), true);
}

// Kept for content expansion; Capella route currently short-circuits most of these.
void investigate;
void rest;
void resolveCombat;
void customAction;
