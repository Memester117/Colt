export interface EncounterDef {
  id: string;
  name: string;
  intro: string[];
  threat: number;
  hp: number;
  tags: string[];
  canFlee: boolean;
  regions: string[];
  loot?: Array<{ id: string; name: string; description: string; tags: string[]; quantity: number }>;
  onWinFlags?: string[];
  chronicle?: string;
}

export const ENCOUNTERS: EncounterDef[] = [
  {
    id: 'ash_wolves',
    name: 'Ash-wolves',
    intro: [
      'Pale shapes peel from the roadside scrub — ash-wolves, eyes like dull coins.',
      'A low chorus of growls stitches the air shut. The pack has noticed you.',
    ],
    threat: 12,
    hp: 18,
    tags: ['beast', 'pack'],
    canFlee: true,
    regions: ['ashroad', 'burntwatch', 'reedfen'],
    loot: [
      { id: 'wolf_ear', name: 'Ash-wolf ear', description: 'Proof for Mira\'s bounty.', tags: ['proof', 'quest'], quantity: 1 },
    ],
    onWinFlags: ['wolves_thinned'],
    chronicle: 'You fought ash-wolves and lived to smell like victory and wet fur.',
  },
  {
    id: 'road_brigands',
    name: 'Road brigands',
    intro: [
      'Three figures step onto the track with the confidence of people who have practiced this speech.',
      '"Toll," says the tallest, almost politely. The knives are less polite.',
    ],
    threat: 13,
    hp: 16,
    tags: ['human', 'greedy'],
    canFlee: true,
    regions: ['ashroad', 'millcreek'],
    loot: [
      { id: 'stolen_purse', name: 'Stolen purse', description: 'Someone else\'s bad day, now yours.', tags: ['loot'], quantity: 1 },
    ],
    chronicle: 'Brigands tested the road. You tested them back.',
  },
  {
    id: 'fen_lurker',
    name: 'Fen lurker',
    intro: [
      'The water bulges. Something with too many joints decides you look edible.',
      'Reeds explode outward as a lurker hauls itself into imperfect daylight.',
    ],
    threat: 14,
    hp: 20,
    tags: ['beast', 'wet'],
    canFlee: true,
    regions: ['reedfen', 'sunken_chapel', 'millcreek'],
    loot: [
      { id: 'lurker_oil', name: 'Lurker oil', description: 'Foul, useful, conversation-ending.', tags: ['alchemy'], quantity: 1 },
    ],
    chronicle: 'A fen lurker learned that curiosity cuts both ways.',
  },
  {
    id: 'watch_shade',
    name: 'Watch-shade',
    intro: [
      'Smoke gathers into a soldier\'s outline and raises a weapon made of regret.',
      'The ruin exhales a shade that still thinks the war is today\'s shift.',
    ],
    threat: 15,
    hp: 14,
    tags: ['spirit', 'war'],
    canFlee: false,
    regions: ['burntwatch'],
    loot: [
      { id: 'ash_medal', name: 'Ash-stained medal', description: 'Valor, oxidized.', tags: ['story', 'loot'], quantity: 1 },
    ],
    onWinFlags: ['shade_laid'],
    chronicle: 'You laid a watch-shade to something like rest.',
  },
  {
    id: 'camp_duel',
    name: 'Camp challenger',
    intro: [
      'A fighter from Ash Camp steps forward, grin sharp. "Practice. Or pride. Your choice how hard."',
      'Spears tap shields in a rhythm that means: entertain us.',
    ],
    threat: 13,
    hp: 15,
    tags: ['human', 'honor'],
    canFlee: true,
    regions: ['ashcamp'],
    loot: [
      { id: 'camp_favor', name: 'Camp favor token', description: 'A scrap that opens fewer doors than it claims.', tags: ['story'], quantity: 1 },
    ],
    chronicle: 'You traded blows with Ash Camp and left standing.',
  },
];

export function encountersFor(locationId: string): EncounterDef[] {
  return ENCOUNTERS.filter((e) => e.regions.includes(locationId));
}
