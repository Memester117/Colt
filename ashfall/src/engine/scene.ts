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
    const header = `**${loc.name}** — ${timeLabel(next.time)}, ${weatherLabel(next.weather)}.`;
    pushLog(next, { kind: 'narration', text: `${header} ${atmos} ${beat}` });

    if (chance(rng, 0.35)) {
      const mem = recentMemory(next);
      if (mem) pushLog(next, { kind: 'narration', text: mem });
    }

    // Soft quest nudges
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

  // Travel choices
  for (const exit of loc.exits) {
    if (exit.requiresFlag && !flagTrue(next, exit.requiresFlag)) continue;
    next.choices.push({
      id: `travel_${exit.to}`,
      label: exit.label,
      kind: 'travel',
      targetId: exit.to,
      hint: `${exit.hours}h · ${exit.risk} risk`,
    });
  }

  // Talk to locals
  for (const npcId of loc.locals) {
    const npc = getNpc(npcId);
    if (!npc) continue;
    const mem = next.npcs[npcId];
    const known = mem?.met ? npc.name : npc.title;
    next.choices.push({
      id: `talk_${npcId}`,
      label: mem?.met ? `Talk with ${npc.name}` : `Approach the ${npc.title}`,
      kind: 'talk',
      targetId: npcId,
      hint: known,
      attribute: 'presence',
      dc: 10,
    });
  }

  next.choices.push({
    id: 'investigate',
    label: 'Look around carefully',
    kind: 'investigate',
    attribute: 'wits',
    dc: 12,
  });

  next.choices.push({
    id: 'rest',
    label: loc.tags.includes('safe') || loc.tags.includes('inn') ? 'Rest and recover' : 'Make a wary camp',
    kind: 'rest',
    attribute: 'endurance',
    dc: loc.tags.includes('safe') ? 8 : 13,
  });

  next.choices.push({
    id: 'wait',
    label: 'Wait and watch the hours turn',
    kind: 'wait',
  });

  // Contextual help / bargain / use
  if (loc.id === 'hollowmere' && hasItem(next, 'wolf_ear') && !flagTrue(next, 'quest_wolves_done')) {
    next.choices.unshift({
      id: 'turn_in_wolves',
      label: 'Turn in ash-wolf proof to Mira',
      kind: 'bargain',
      targetId: 'mira',
    });
  }
  if (hasItem(next, 'letter') && loc.id === 'candleinn') {
    next.choices.unshift({
      id: 'deliver_letter',
      label: 'Deliver the letter to Brenna',
      kind: 'use',
      targetId: 'brenna',
    });
  }
  if (hasItem(next, 'dispatch') && loc.id === 'burntwatch') {
    next.choices.unshift({
      id: 'deliver_dispatch',
      label: 'Deliver the sealed dispatch',
      kind: 'use',
      targetId: 'captain_rhel',
    });
  }
  if (flagTrue(next, 'boy_found') && !flagTrue(next, 'boy_rescued') && loc.id === 'sunken_chapel') {
    next.choices.unshift({
      id: 'rescue_boy',
      label: 'Lead the apprentice out of the chapel',
      kind: 'help',
      attribute: 'spirit',
      dc: 11,
    });
  }
  if (flagTrue(next, 'boy_rescued') && loc.id === 'millcreek' && !next.quests.apprentice?.completed) {
    next.choices.unshift({
      id: 'return_boy',
      label: 'Return the apprentice to Garrick',
      kind: 'help',
      targetId: 'garrick',
    });
  }
  if (loc.id === 'ashcamp' && !flagTrue(next, 'serra_terms') && (next.npcs.serra?.met || next.chapter >= 1)) {
    next.choices.push({
      id: 'ask_alliance',
      label: 'Ask Serra about an alliance with Hollowmere',
      kind: 'bargain',
      targetId: 'serra',
      attribute: 'presence',
      dc: 14,
    });
  }
  if (flagTrue(next, 'serra_terms') && loc.id === 'hollowmere' && !flagTrue(next, 'quest_alliance_done')) {
    next.choices.unshift({
      id: 'relay_terms',
      label: 'Relay Serra\'s terms to Mira',
      kind: 'bargain',
      targetId: 'mira',
    });
  }
  if (loc.id === 'hollowmere' && !hasItem(next, 'dispatch') && !flagTrue(next, 'quest_dispatch_done') && !next.flags.dispatch_taken) {
    next.choices.push({
      id: 'take_dispatch',
      label: 'Accept the sealed dispatch job from the notice board',
      kind: 'help',
      targetId: 'tamsin',
    });
  }

  // Inventory use: herbs
  if (hasItem(next, 'herbs') && next.hp < next.maxHp) {
    next.choices.push({
      id: 'use_herbs',
      label: 'Use herb satchel to tend wounds',
      kind: 'use',
      targetId: 'herbs',
    });
  }

  // Deduplicate by id
  const seen = new Set<string>();
  next.choices = next.choices.filter((c: Choice) => {
    if (seen.has(c.id)) return false;
    seen.add(c.id);
    return true;
  });

  return next;
}

function composeCombat(state: GameState, announce: boolean): GameState {
  const enc = state.encounter!;
  if (announce) {
    pushLog(state, {
      kind: 'narration',
      text: `Encounter: **${enc.name}** — threat looming (${enc.hp}/${enc.maxHp}). Your body answers before your doubts do.`,
    });
  }
  state.choices = [
    {
      id: 'fight',
      label: 'Fight',
      kind: 'fight',
      attribute: 'might',
      dc: enc.threat,
      hint: 'Steel and stubbornness',
    },
    {
      id: 'sneak_fight',
      label: 'Outmaneuver',
      kind: 'sneak',
      attribute: 'grace',
      dc: enc.threat,
      hint: 'Feet smarter than fists',
    },
    {
      id: 'presence_fight',
      label: 'Face them down',
      kind: 'bargain',
      attribute: 'presence',
      dc: enc.threat + 1,
      hint: 'Voice as weapon',
    },
  ];
  if (enc.canFlee) {
    state.choices.push({
      id: 'flee',
      label: 'Flee',
      kind: 'flee',
      attribute: 'grace',
      dc: enc.threat - 1,
    });
  }
  return state;
}
