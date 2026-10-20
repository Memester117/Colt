export interface Exit {
  to: string;
  label: string;
  hours: number;
  risk: 'low' | 'mid' | 'high';
  requiresFlag?: string;
}

export interface LocationDef {
  id: string;
  name: string;
  region: string;
  tags: string[];
  atmosphere: string[];
  dayBeat: string[];
  nightBeat: string[];
  exits: Exit[];
  locals: string[]; // npc ids
  investigateHooks: string[];
}

export const LOCATIONS: Record<string, LocationDef> = {
  hollowmere: {
    id: 'hollowmere',
    name: 'Hollowmere',
    region: 'The Marches',
    tags: ['town', 'safe', 'trade'],
    atmosphere: [
      'Chimney smoke hangs low over wet slate roofs.',
      'The square smells of bread, iron, and damp wool.',
      'A notice board lists missing sheep and one missing person.',
    ],
    dayBeat: [
      'Merchants shout prices as if volume could invent demand.',
      'Children race a dog around the well until an adult ends the game.',
      'A cart axle squeals; someone curses with religious creativity.',
    ],
    nightBeat: [
      'Lanterns pool warm circles on cobbles that remember older wars.',
      'The tavern door opens and closes like a heartbeat.',
      'Somewhere a watchman hums off-key to keep himself company.',
    ],
    exits: [
      { to: 'ashroad', label: 'Take the Ashroad east', hours: 2, risk: 'mid' },
      { to: 'millcreek', label: 'Follow the creek to the mill', hours: 1, risk: 'low' },
      { to: 'candleinn', label: 'Step into the Candle & Crow', hours: 0, risk: 'low' },
    ],
    locals: ['mira', 'osric', 'tamsin'],
    investigateHooks: [
      'The notice board has a fresh scrap: "Ash-wolves at the east bend. Coin for proof."',
      'Boot prints near the well are too large for any local.',
      'Someone has scratched a spiral into the chapel doorframe.',
    ],
  },
  candleinn: {
    id: 'candleinn',
    name: 'The Candle & Crow',
    region: 'Hollowmere',
    tags: ['inn', 'safe', 'social'],
    atmosphere: [
      'Beeswax and stew fight a polite war in the air.',
      'A crow carved above the bar watches every coin change hands.',
      'The hearth is generous; the chairs are less so.',
    ],
    dayBeat: [
      'A traveler nurses tea and a careful silence.',
      'The innkeep polishes glasses that are already clean.',
      'Someone argues softly about road tariffs.',
    ],
    nightBeat: [
      'Dice clatter; laughter arrives late and leaves early.',
      'A fiddler plays something almost like a marching song.',
      'Shadows lean long; conversations get braver.',
    ],
    exits: [
      { to: 'hollowmere', label: 'Return to the square', hours: 0, risk: 'low' },
    ],
    locals: ['brenna', 'pilgrim'],
    investigateHooks: [
      'A room upstairs is locked though the innkeep swears it is empty.',
      'Under a table you find a badge from the old levy.',
      'The guest book has a name written, then violently scratched out.',
    ],
  },
  millcreek: {
    id: 'millcreek',
    name: 'Millcreek',
    region: 'The Marches',
    tags: ['rural', 'work', 'water'],
    atmosphere: [
      'The mill wheel turns with stubborn patience.',
      'Wet moss makes every step a negotiation.',
      'Flour dust softens the edges of everything.',
    ],
    dayBeat: [
      'The miller shouts over the wheel about a missing apprentice.',
      'Ducks argue politics in the shallows.',
      'A broken fence waits for someone with time.',
    ],
    nightBeat: [
      'The wheel keeps time for things that do not sleep.',
      'Frogs sing like they know a secret.',
      'A lantern bobbing near the weir should not be there.',
    ],
    exits: [
      { to: 'hollowmere', label: 'Walk back to Hollowmere', hours: 1, risk: 'low' },
      { to: 'reedfen', label: 'Cut through the reed fen', hours: 2, risk: 'mid' },
    ],
    locals: ['garrick', 'lina'],
    investigateHooks: [
      'Grain sacks have been slit from the inside out.',
      'There are drag marks leading into the reeds.',
      'A child\'s wooden horse floats in the millrace.',
    ],
  },
  ashroad: {
    id: 'ashroad',
    name: 'The Ashroad',
    region: 'The Marches',
    tags: ['road', 'wild', 'travel'],
    atmosphere: [
      'Old fire left the trees pale as bone.',
      'The road is a scar that people still trust.',
      'Crows keep count of travelers.',
    ],
    dayBeat: [
      'Heat shimmers even when the air is cool.',
      'A merchant wagon sits crooked in a ditch.',
      'Hoofprints overlap bootprints; stories overlap too.',
    ],
    nightBeat: [
      'Ash lifts in little ghosts when the wind turns.',
      'Something large moves without announcing itself.',
      'Distant drums — or just your heart — argue for caution.',
    ],
    exits: [
      { to: 'hollowmere', label: 'West to Hollowmere', hours: 2, risk: 'mid' },
      { to: 'burntwatch', label: 'Climb toward Burnt Watch', hours: 3, risk: 'high' },
      { to: 'reedfen', label: 'South into the reed fen', hours: 2, risk: 'mid' },
    ],
    locals: [],
    investigateHooks: [
      'A charred milepost has been recently re-carved with a new arrow.',
      'Blood on the gravel is still tacky.',
      'A cache of arrows is hidden under a fallen signpost.',
    ],
  },
  reedfen: {
    id: 'reedfen',
    name: 'Reedfen',
    region: 'The Wet Marches',
    tags: ['wild', 'wet', 'secret'],
    atmosphere: [
      'Reeds whisper like a crowd that has not decided.',
      'The ground is honest only in patches.',
      'Black water holds the sky upside down.',
    ],
    dayBeat: [
      'A heron stands as if posing for a crest.',
      'Insects write restless letters on your skin.',
      'Someone has laid planks across the worst of the mud.',
    ],
    nightBeat: [
      'Will-o-wisps? Or just swamp gas with ambition?',
      'A boat bumps gently with no boatman.',
      'The reeds part for something that prefers not to be seen.',
    ],
    exits: [
      { to: 'millcreek', label: 'Back toward the mill', hours: 2, risk: 'mid' },
      { to: 'ashroad', label: 'Find the Ashroad again', hours: 2, risk: 'mid' },
      { to: 'sunken_chapel', label: 'Seek the sunken chapel', hours: 2, risk: 'high', requiresFlag: 'knows_chapel' },
    ],
    locals: ['fenwitch'],
    investigateHooks: [
      'A snare has caught nothing but a scrap of red cloth.',
      'Stone steps disappear under tea-colored water.',
      'You find a charm of braided reed meant to ward off "the listening."',
    ],
  },
  burntwatch: {
    id: 'burntwatch',
    name: 'Burnt Watch',
    region: 'The Ridge',
    tags: ['ruin', 'war', 'high'],
    atmosphere: [
      'The tower stands like a blackened tooth.',
      'Wind through arrow-slits sounds almost like speech.',
      'From here the Marches look small and breakable.',
    ],
    dayBeat: [
      'Ravens argue ownership of the battlements.',
      'A cracked signal-mirror still catches noon.',
      'Old barricades remember better days of being useful.',
    ],
    nightBeat: [
      'Cold stars make the ruin feel newly abandoned.',
      'A light flickers in a lower chamber — then dies.',
      'You hear metal on stone, then nothing.',
    ],
    exits: [
      { to: 'ashroad', label: 'Descend to the Ashroad', hours: 3, risk: 'high' },
      { to: 'ashcamp', label: 'Approach the ash camp', hours: 1, risk: 'mid', requiresFlag: 'saw_ashcamp' },
    ],
    locals: ['captain_rhel'],
    investigateHooks: [
      'A ledger of the last garrison is water-stained but readable.',
      'The signal drum has been recently restrung.',
      'A hidden alcove holds a sealed dispatch case.',
    ],
  },
  ashcamp: {
    id: 'ashcamp',
    name: 'Ash Camp',
    region: 'The Ridge',
    tags: ['camp', 'faction', 'tense'],
    atmosphere: [
      'Tents huddle around a careful fire.',
      'Spears lean together like gossiping neighbors.',
      'Everyone here has the posture of people waiting for news.',
    ],
    dayBeat: [
      'A cook stirs something that smells better than it looks.',
      'Scouts compare maps that disagree.',
      'Someone sharpens a blade as a form of prayer.',
    ],
    nightBeat: [
      'Sentries trade soft jokes that do not reach their eyes.',
      'The fire pops; hands go to hilts, then relax.',
      'A messenger arrives late and leaves earlier.',
    ],
    exits: [
      { to: 'burntwatch', label: 'Return to Burnt Watch', hours: 1, risk: 'mid' },
      { to: 'ashroad', label: 'Slip down to the Ashroad', hours: 2, risk: 'mid' },
    ],
    locals: ['serra', 'kel'],
    investigateHooks: [
      'A map marks Hollowmere with a red circle and a question mark.',
      'Supply crates are stamped with a crest you recognize from town.',
      'Someone keeps a locked box under their bedroll.',
    ],
  },
  sunken_chapel: {
    id: 'sunken_chapel',
    name: 'Sunken Chapel',
    region: 'Reedfen',
    tags: ['ruin', 'holy', 'secret'],
    atmosphere: [
      'Half the nave is water; the rest is memory.',
      'Icons stare with paint-flaked patience.',
      'Your footsteps sound too loud for a place that listens.',
    ],
    dayBeat: [
      'Light through a broken rose window makes soft geometry on the flood.',
      'Fish dart between pews like irreverent choirboys.',
      'A dry alcove smells of old incense and newer fear.',
    ],
    nightBeat: [
      'Candles that should not burn, burn.',
      'Water lapping stone becomes almost a chant.',
      'You feel observed by something that prefers manners.',
    ],
    exits: [
      { to: 'reedfen', label: 'Wade back into the fen', hours: 2, risk: 'high' },
    ],
    locals: ['echo'],
    investigateHooks: [
      'An altar niche hides a spiral-marked key.',
      'Mural paint peels to reveal an older map of the Marches.',
      'Offerings here are recent: bread, a coin, a lock of hair.',
    ],
  },
};

export function getLocation(id: string): LocationDef {
  return LOCATIONS[id] ?? LOCATIONS.hollowmere!;
}
