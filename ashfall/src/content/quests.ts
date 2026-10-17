export interface QuestDef {
  id: string;
  name: string;
  summary: string;
  stages: string[];
}

export const QUESTS: Record<string, QuestDef> = {
  wolves: {
    id: 'wolves',
    name: 'Ash-wolf bounty',
    summary: 'Thin the ash-wolves troubling the east bend and bring proof to Mira.',
    stages: [
      'Heard of the bounty in Hollowmere.',
      'Fought ash-wolves on the road.',
      'Returned proof to Mira.',
    ],
  },
  apprentice: {
    id: 'apprentice',
    name: 'The missing apprentice',
    summary: 'Find Garrick\'s apprentice in the reed fen before the marsh writes its own ending.',
    stages: [
      'Learned the boy followed a red scrap into Reedfen.',
      'Spoke with Ila of the Reeds.',
      'Reached the sunken chapel.',
      'Brought the boy home.',
    ],
  },
  dispatch: {
    id: 'dispatch',
    name: 'Sealed dispatch',
    summary: 'Carry a sealed case to Burnt Watch without opening more trouble than necessary.',
    stages: [
      'Accepted the dispatch from Tamsin\'s board.',
      'Reached Burnt Watch.',
      'Delivered the case to Captain Rhel.',
    ],
  },
  chapel: {
    id: 'chapel',
    name: 'Listening spiral',
    summary: 'Learn what the drowned chapel still remembers.',
    stages: [
      'Heard the pilgrim\'s warning.',
      'Found the chapel in the fen.',
      'Faced the Echo.',
    ],
  },
  alliance: {
    id: 'alliance',
    name: 'Ridge and town',
    summary: 'Broker a wary understanding between Mira and Serra.',
    stages: [
      'Met Serra at Ash Camp.',
      'Carried terms to Mira.',
      'Sealed a fragile alliance.',
    ],
  },
  letter: {
    id: 'letter',
    name: 'Unopened letter',
    summary: 'Deliver a letter that has waited too long.',
    stages: [
      'Carried the letter into the Marches.',
      'Gave it to Brenna at the Candle & Crow.',
    ],
  },
};
