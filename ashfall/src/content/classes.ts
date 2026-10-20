import type { Attributes } from '../engine/types';

export interface ClassDef {
  id: string;
  name: string;
  blurb: string;
  attributes: Attributes;
  gear: Array<{ id: string; name: string; description: string; tags: string[]; quantity: number }>;
  hp: number;
}

export const CLASSES: ClassDef[] = [
  {
    id: 'warden',
    name: 'Warden',
    blurb: 'A border scout who reads trails the way others read faces.',
    attributes: { might: 13, grace: 14, wits: 12, spirit: 11, presence: 10, endurance: 13 },
    gear: [
      { id: 'shortbow', name: 'Shortbow', description: 'Ashwood, well-kept.', tags: ['weapon', 'ranged'], quantity: 1 },
      { id: 'trail_ration', name: 'Trail rations', description: 'Dried meat and hard bread.', tags: ['food'], quantity: 3 },
      { id: 'cloak', name: 'Travel cloak', description: 'Smells faintly of pine smoke.', tags: ['gear'], quantity: 1 },
    ],
    hp: 14,
  },
  {
    id: 'hearthwright',
    name: 'Hearthwright',
    blurb: 'A fixer of people and places — soft voice, stubborn hands.',
    attributes: { might: 11, grace: 10, wits: 13, spirit: 14, presence: 13, endurance: 12 },
    gear: [
      { id: 'herbs', name: 'Herb satchel', description: 'Feverfew, willow bark, a little luck.', tags: ['medicine'], quantity: 2 },
      { id: 'hammer', name: 'Work hammer', description: 'Useful for nails and, if pressed, knuckles.', tags: ['tool', 'weapon'], quantity: 1 },
      { id: 'letter', name: 'Unopened letter', description: 'Addressed to someone in Hollowmere.', tags: ['quest', 'story'], quantity: 1 },
    ],
    hp: 12,
  },
  {
    id: 'ashblade',
    name: 'Ashblade',
    blurb: 'A former levy soldier still carrying the war in their stance.',
    attributes: { might: 15, grace: 11, wits: 10, spirit: 12, presence: 11, endurance: 14 },
    gear: [
      { id: 'shortsword', name: 'Notched shortsword', description: 'Reliable, if no longer pretty.', tags: ['weapon', 'melee'], quantity: 1 },
      { id: 'shield', name: 'Round shield', description: 'Painted with a faded march crest.', tags: ['armor'], quantity: 1 },
      { id: 'war_token', name: 'War token', description: 'A brass disk that opens doors — and old wounds.', tags: ['story'], quantity: 1 },
    ],
    hp: 16,
  },
  {
    id: 'charmer',
    name: 'Charmer',
    blurb: 'A storyteller who treats truth as a renewable resource.',
    attributes: { might: 9, grace: 12, wits: 14, spirit: 11, presence: 15, endurance: 10 },
    gear: [
      { id: 'lute', name: 'Travel lute', description: 'Two strings have been replaced with fishing line.', tags: ['instrument', 'tool'], quantity: 1 },
      { id: 'coin_pouch', name: 'Thin coin pouch', description: 'Optimism included.', tags: ['gear'], quantity: 1 },
      { id: 'rumor_book', name: 'Rumor ledger', description: 'Names, debts, and half-true maps.', tags: ['story', 'tool'], quantity: 1 },
    ],
    hp: 10,
  },
];
