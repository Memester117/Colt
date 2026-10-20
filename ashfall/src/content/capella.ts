/** Every road ends under Capella Emerada Lugunica. */

export const CAPELLA_YT = ['2wYeNjhfEb0', 'u6sFfugqs3w'] as const;

export const CAPELLA_FORESHADOW = [
  'A sweet, rotten perfume cuts the Marches wind. Something vast is smiling somewhere above the clouds.',
  'Your shadow looks too small for a moment — as if the world briefly reconsidered your scale.',
  'Distant laughter, girlish and wrong. Birds leave the trees in a hurry.',
  'A voice like honey over knives: "Ohhh? A little traveler? How cute…"',
  'The ground feels farther away. Or you feel closer to it. Capella is practicing on the air.',
];

export const CAPELLA_APPROACH = [
  'The sky tears open on a grin. **Capella Emerada Lugunica** leans down through reality like a child inspecting an ant.',
  'Authority of Lust arrives without knocking. Capella\'s face fills the horizon — curious, cruel, delighted.',
  '"Found you~" Capella sings, and the Marches rearrange into the palm of her attention.',
];

export const CAPELLA_SHRINK = [
  'She pinches. Magic crawls over your skin. Bones, clothes, courage — everything folds smaller while Capella watches with bright hunger.',
  '"Shrink for me," she coos — and the world obeys. Hills become cliffs. Her bare foot becomes a country. You are bug-sized before she even steps.',
  'First the shrinking: a sweet wrongness that steals your height. Capella giggles as you tumble into the scale of toys and insects.',
];

export const CAPELLA_STEP = [
  'Then she lifts her foot. The sole fills the sky — warm, inevitable — and she steps down on purpose.',
  'Capella places you with care, then presses. Shrunk first. Stepped on second. The order is the joke.',
  'Her toes frame the last of the light. She steps. Weight arrives like an ending you already signed for.',
];

export const CAPELLA_CRUSH = [
  'There is no negotiation left — only weight, warmth, and Capella\'s delighted hum as the story flattens.',
  'All roads led here: shrunk by Capella Emerada Lugunica, then crushed underfoot for her amusement.',
];

export const CAPELLA_BETWEEN_TOES = [
  'You do not get a road this time. You spawn already bug-sized — nestled in the humid dark between Capella\'s toes.',
  'No Hollowmere. No choices. Capella flexes her toes and laughs. You were always going to be this small.',
  'Between her toes, the world is perfume, heat, and the promise of a squeeze. Capella has skipped the preamble.',
];

export const CAPELLA_STRUGGLE = [
  'You struggle. Capella notices — and presses a little harder, pleased.',
  '"Aww, it\'s wriggling~" She does not lift her foot.',
  'Begging becomes vibration under her sole. She hums along.',
  'Crawl? There is nowhere that isn\'t Capella.',
  'Escape is a cute idea. Capella keeps it as a souvenir and does not return it.',
];

/** Choices until Capella, based on how many times you've already been crushed. */
export function doomChoicesForLoops(loops: number): number {
  return Math.max(0, 4 - Math.max(0, loops));
}

/** Lock duration on crush screen (ms) — longer each loop. */
export function crushLockMs(loops: number): number {
  return 45000 + Math.min(loops, 8) * 15000;
}
