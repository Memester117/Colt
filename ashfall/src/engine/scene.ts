import { getLocation } from '../content/locations';
import { getNpc } from '../content/npcs';
import { createRng, pick, chance, hashSeed } from './rng';
import { timeLabel, weatherLabel } from './create';
import type { Choice, GameState } from './types';
import { flagTrue, hasItem, pushLog } from './helpers';

function recentMemory(state: GameState): string | null {
  const important = state.chronicle.filter((c) => c.important).slice(0, 5);
  if (!important.length) return null;
  const rng = createRng(hashSeed(state.seed, state.turns, 'mem'));
  const entry = pick(rng, important);
  return `You remember: ${entry.text}`;
}

const SHORT_DEST: Record<string, string> = {
  hollowmere: 'Hollowmere',
  candleinn: 'Candle & Crow',
  millcreek: 'Millcreek',
  ashroad: 'Ashroad',
  reedfen: 'Reedfen',
  burntwatch: 'Burnt Watch',
  ashcamp: 'Ash Camp',
  sunken_chapel: 'Sunken Chapel',
};

export function composeScene(state: GameState, announce = true): GameState {
  const next = structuredClone(state);
  next.choices = [];

  if (next.encounter) {
    return composeCombat(next, announce);
  }

  const loc = getLocation(next.locationId);
  const rng = createRng(hashSeed(next.seed, next.day, next.time, next.locationId, next.turns));

  if (announce) {
    const atmos = pick(rng, loc.atmosphere);
    const beat = pick(rng, next.time === 'night' || next.time === 'dusk' ? loc.nightBeat : loc.dayBeat);
    const weatherBit =
      next.weather === 'storm'
        ? ' Stormlight makes every decision feel louder.'
        : next.weather === 'ashwind'
          ? ' Ash rides the wind like unfinished business.'
          : next.weather === 'mist'
            ? ' Mist edits the edges of the world.'
            : '';
    const header = `**${loc.name}** — ${timeLabel(next.time)}, ${weatherLabel(next.weather)}.`;
    pushLog(next, { kind: 'narration', text: `${header} ${atmos} ${beat}${weatherBit}` });

    if (chance(rng, 0.35)) {
      const mem = recentMemory(next);
      if (mem) pushLog(next, { kind: 'narration', text: mem });
    }

    if (loc.id === 'hollowmere' && !next.quests.wolves) {
      pushLog(next, {
        kind: 'narration',
        text: 'A notice board flutters in the square. Bounties and missing persons share the same nails.',
      });
    }
    if (flagTrue(next, 'boy_rescued') && loc.id === 'millcreek' && !next.quests.apprentice?.completed) {
      pushLog(next, {
        kind: 'narration',
        text: 'Garrick\'s mill looks like a place waiting for a reunion.',
      });
    }
  }

  // —— Focus (quest-critical) ——
  if (loc.id === 'hollowmere' && hasItem(next, 'wolf_ear') && !flagTrue(next, 'quest_wolves_done')) {
    next.choices.push({
      id: 'turn_in_wolves',
      label: 'Turn in wolf proof',
      kind: 'bargain',
      targetId: 'mira',
      group: 'focus',
      hint: 'Mira · bounty',
    });
  }
  if (hasItem(next, 'letter') && loc.id === 'candleinn') {
    next.choices.push({
      id: 'deliver_letter',
      label: 'Deliver the letter',
      kind: 'use',
      targetId: 'brenna',
      group: 'focus',
      hint: 'Brenna',
    });
  }
  if (hasItem(next, 'dispatch') && loc.id === 'burntwatch') {
    next.choices.push({
      id: 'deliver_dispatch',
      label: 'Deliver the dispatch',
      kind: 'use',
      targetId: 'captain_rhel',
      group: 'focus',
      hint: 'Captain Rhel',
    });
  }
  if (flagTrue(next, 'boy_found') && !flagTrue(next, 'boy_rescued') && loc.id === 'sunken_chapel') {
    next.choices.push({
      id: 'rescue_boy',
      label: 'Lead the apprentice out',
      kind: 'help',
      attribute: 'spirit',
      dc: 11,
      group: 'focus',
    });
  }
  if (flagTrue(next, 'boy_rescued') && loc.id === 'millcreek' && !next.quests.apprentice?.completed) {
    next.choices.push({
      id: 'return_boy',
      label: 'Return the apprentice',
      kind: 'help',
      targetId: 'garrick',
      group: 'focus',
      hint: 'Garrick',
    });
  }
  if (flagTrue(next, 'serra_terms') && loc.id === 'hollowmere' && !flagTrue(next, 'quest_alliance_done')) {
    next.choices.push({
      id: 'relay_terms',
      label: 'Relay Serra\'s terms',
      kind: 'bargain',
      targetId: 'mira',
      group: 'focus',
      hint: 'Mira',
    });
  }
  if (
    loc.id === 'hollowmere' &&
    !hasItem(next, 'dispatch') &&
    !flagTrue(next, 'quest_dispatch_done') &&
    !next.flags.dispatch_taken
  ) {
    next.choices.push({
      id: 'take_dispatch',
      label: 'Take the dispatch job',
      kind: 'help',
      targetId: 'tamsin',
      group: 'focus',
      hint: 'Notice board',
    });
  }
  if (loc.id === 'ashcamp' && !flagTrue(next, 'serra_terms')) {
    next.choices.push({
      id: 'ask_alliance',
      label: 'Ask about alliance',
      kind: 'bargain',
      targetId: 'serra',
      attribute: 'presence',
      dc: 14,
      group: 'focus',
      hint: 'Serra',
    });
  }
  if (hasItem(next, 'herbs') && next.hp < next.maxHp) {
    next.choices.push({
      id: 'use_herbs',
      label: 'Tend wounds',
      kind: 'use',
      targetId: 'herbs',
      group: 'focus',
      hint: 'Herbs',
    });
  }

  // —— People ——
  for (const npcId of loc.locals) {
    const npc = getNpc(npcId);
    if (!npc) continue;
    const mem = next.npcs[npcId];
    next.choices.push({
      id: `talk_${npcId}`,
      label: mem?.met ? npc.name.split(' ')[0]! : shortTitle(npc.title),
      kind: 'talk',
      targetId: npcId,
      hint: mem?.met ? npc.title : 'stranger',
      attribute: 'presence',
      dc: 10,
      group: 'people',
    });
  }

  // —— Travel ——
  for (const exit of loc.exits) {
    if (exit.requiresFlag && !flagTrue(next, exit.requiresFlag)) continue;
    next.choices.push({
      id: `travel_${exit.to}`,
      label: SHORT_DEST[exit.to] ?? exit.label,
      kind: 'travel',
      targetId: exit.to,
      hint: `${exit.hours}h · ${exit.risk}`,
      group: 'travel',
    });
  }

  // —— Pace ——
  next.choices.push({
    id: 'investigate',
    label: 'Look around',
    kind: 'investigate',
    attribute: 'wits',
    dc: 12,
    group: 'pace',
  });
  next.choices.push({
    id: 'rest',
    label: loc.tags.includes('safe') || loc.tags.includes('inn') ? 'Rest' : 'Camp',
    kind: 'rest',
    attribute: 'endurance',
    dc: loc.tags.includes('safe') ? 8 : 13,
    group: 'pace',
  });
  next.choices.push({
    id: 'wait',
    label: 'Wait',
    kind: 'wait',
    group: 'pace',
  });

  const seen = new Set<string>();
  next.choices = next.choices.filter((c: Choice) => {
    if (seen.has(c.id)) return false;
    seen.add(c.id);
    return true;
  });

  return next;
}

function shortTitle(title: string): string {
  const first = title.split(/[\s,]/)[0] ?? title;
  return first.charAt(0).toUpperCase() + first.slice(1);
}

function composeCombat(state: GameState, announce: boolean): GameState {
  const enc = state.encounter!;
  if (announce) {
    pushLog(state, {
      kind: 'narration',
      text: `Encounter: **${enc.name}** — (${enc.hp}/${enc.maxHp}). Your body answers before your doubts do.`,
    });
  }
  state.choices = [
    {
      id: 'fight',
      label: 'Fight',
      kind: 'fight',
      attribute: 'might',
      dc: enc.threat,
      hint: 'Might',
      group: 'focus',
    },
    {
      id: 'sneak_fight',
      label: 'Outmaneuver',
      kind: 'sneak',
      attribute: 'grace',
      dc: enc.threat,
      hint: 'Grace',
      group: 'focus',
    },
    {
      id: 'presence_fight',
      label: 'Stare down',
      kind: 'bargain',
      attribute: 'presence',
      dc: enc.threat + 1,
      hint: 'Presence',
      group: 'focus',
    },
  ];
  if (enc.canFlee) {
    state.choices.push({
      id: 'flee',
      label: 'Flee',
      kind: 'flee',
      attribute: 'grace',
      dc: enc.threat - 1,
      group: 'pace',
    });
  }
  return state;
}
