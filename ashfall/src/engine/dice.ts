import type { Attribute, Attributes } from './types';

export function rollDie(rng: () => number, sides: number): number {
  return 1 + Math.floor(rng() * sides);
}

export function attributeMod(score: number): number {
  return Math.floor((score - 10) / 2);
}

export function check(
  rng: () => number,
  attributes: Attributes,
  attribute: Attribute,
  dc: number,
  bonus = 0,
): { roll: number; mod: number; total: number; dc: number; success: boolean; crit: boolean; fumble: boolean } {
  const roll = rollDie(rng, 20);
  const mod = attributeMod(attributes[attribute]) + bonus;
  const total = roll + mod;
  const crit = roll === 20;
  const fumble = roll === 1;
  const success = crit || (!fumble && total >= dc);
  return { roll, mod, total, dc, success, crit, fumble };
}

export const ATTR_LABEL: Record<Attribute, string> = {
  might: 'Might',
  grace: 'Grace',
  wits: 'Wits',
  spirit: 'Spirit',
  presence: 'Presence',
  endurance: 'Endurance',
};
