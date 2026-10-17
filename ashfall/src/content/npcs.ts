export interface NpcDef {
  id: string;
  name: string;
  title: string;
  voice: string[];
  greetings: string[];
  topics: Record<string, string[]>;
  favors: string[];
  distrust: string[];
  questHook?: string;
}

export const NPCS: Record<string, NpcDef> = {
  mira: {
    id: 'mira',
    name: 'Mira Cole',
    title: 'mayor of Hollowmere',
    voice: ['measured', 'tired-kind'],
    greetings: [
      'Mira looks up from a stack of petitions. "If you\'re selling miracles, I\'m buying. If not, keep it short."',
      '"Traveler," Mira says, as if classifying livestock. "The Marches eat the careless. Try not to be food."',
    ],
    topics: {
      town: [
        '"Hollowmere holds because people hold each other. Barely. We need flour, fences, and fewer wolves."',
        '"Taxes are late. Wolves are early. I am not a poet, so I will not make that rhyme mean something."',
      ],
      war: [
        '"The war ended on paper. Paper is optimistic."',
        '"Burnt Watch still watches. Whether it watches for us or against us is the unfinished argument."',
      ],
      wolves: [
        '"Ash-wolves at the east bend. Proof earns coin. Living to collect it earns respect."',
        '"They\'re not just hungry. They\'re being… guided. Or I\'m jumping at shadows. Both are traditional here."',
      ],
      letter: [
        'Mira\'s face softens a fraction. "If that letter is for Old Brenna\'s cousin, take it to the Candle & Crow. Gently."',
      ],
    },
    favors: ['help with wolves', 'bring news from Burnt Watch'],
    distrust: ['soldiers without manners', 'charmers who smile too fast'],
    questHook: 'wolves',
  },
  osric: {
    id: 'osric',
    name: 'Osric',
    title: 'blacksmith',
    voice: ['blunt', 'warm-under-soot'],
    greetings: [
      'Osric doesn\'t stop hammering. "Talk while I work. Silence is expensive."',
      '"If you need steel, I have steel. If you need advice, I have opinions."',
    ],
    topics: {
      gear: [
        '"A notch in a blade is a story. I can erase stories for a fee."',
        '"Shield straps fail before shields do. Check yours."',
      ],
      rumor: [
        '"Ash Camp on the ridge is real. Serra runs it like a ledger that bites."',
        '"Someone\'s buying scrap iron in bulk. Not for horseshoes."',
      ],
      mill: [
        '"Garrick at the mill lost an apprentice. Or the fen took one. Same mud either way."',
      ],
    },
    favors: ['honest work', 'not wasting his time'],
    distrust: ['thieves', 'people who touch hot metal twice'],
  },
  tamsin: {
    id: 'tamsin',
    name: 'Tamsin',
    title: 'notice-board keeper',
    voice: ['bright', 'nosy'],
    greetings: [
      'Tamsin waves a scrap of paper like a flag. "Need a job? Need gossip? Overlap is high."',
      '"You look like someone who can walk into trouble and out of it. Sometimes."',
    ],
    topics: {
      jobs: [
        '"Ash-wolves: coin for proof. Missing apprentice: coin and gratitude. Sunken chapel rumors: coin optional, spine required."',
        '"There\'s a sealed dispatch someone wants carried to Burnt Watch. Pay is good. Questions are free and unwelcome."',
      ],
      chapel: [
        '"Reedfen hides a chapel that drowned itself out of shame. Or so the old songs say. Songs lie attractively."',
        'Tamsin lowers her voice. "If you hear water singing, leave. Or don\'t. I need material either way."',
      ],
    },
    favors: ['juicy details', 'completed postings'],
    distrust: ['boring people'],
    questHook: 'dispatch',
  },
  brenna: {
    id: 'brenna',
    name: 'Brenna',
    title: 'innkeep',
    voice: ['dry', 'protective'],
    greetings: [
      'Brenna slides a mug toward an empty spot that becomes yours. "Drink, rest, don\'t start a war indoors."',
      '"Beds upstairs. Secrets downstairs. Pick carefully which you unpack."',
    ],
    topics: {
      rest: [
        '"Stew is hot. Beds are soft enough. Night is long enough without inventing more of it."',
      ],
      guests: [
        '"There\'s a pilgrim who pays in stories. Some of them are even true."',
        '"A locked room upstairs stays locked. Curious fingers find fewer fingers."',
      ],
      letter: [
        'Brenna takes the letter with both hands. "Ah. Yes. Thank you. The world is slightly less unfinished."',
      ],
    },
    favors: ['paying customers', 'people who quiet fights'],
    distrust: ['blade-flashing braggarts'],
  },
  pilgrim: {
    id: 'pilgrim',
    name: 'The Pilgrim',
    title: 'road-worn stranger',
    voice: ['soft', 'riddle-prone'],
    greetings: [
      'The pilgrim smiles like someone remembering a joke from another century. "Sit. The road is patient."',
      '"You carry ash on your boots. The Marches notice such things."',
    ],
    topics: {
      road: [
        '"Every road is a promise someone made to themselves. Some promises grow teeth."',
        '"Burnt Watch still listens for drums. If you go, bring truth or a convincing substitute."',
      ],
      spiral: [
        '"The spiral is not a cult. It is a reminder: listen inward when the world shouts."',
        '"In the fen, water remembers chants. Do not answer unless you mean it."',
      ],
    },
    favors: ['sincerity', 'quiet attention'],
    distrust: ['mockery'],
    questHook: 'chapel',
  },
  garrick: {
    id: 'garrick',
    name: 'Garrick',
    title: 'miller',
    voice: ['gruff', 'worried'],
    greetings: [
      'Garrick wipes flour from his forehead and leaves more. "If you\'re here about the apprentice, good. If not, still talk."',
      '"Wheel turns. World doesn\'t. That\'s my theology."',
    ],
    topics: {
      apprentice: [
        '"Lina\'s brother went into the reeds after a red cloth scrap. Hasn\'t come back. Neither has sense, apparently."',
        '"Pay what I can if you find him. Or find what found him. I need an ending, not a mystery."',
      ],
      fen: [
        '"Reedfen takes the curious. Bring a rope and a reason."',
      ],
    },
    favors: ['finding the boy', 'fixing the fence'],
    distrust: ['idle gawkers'],
    questHook: 'apprentice',
  },
  lina: {
    id: 'lina',
    name: 'Lina',
    title: 'miller\'s niece',
    voice: ['sharp', 'young-brave'],
    greetings: [
      'Lina looks you over. "If you\'re another adult with empty comfort, keep walking."',
      '"My brother is missing. I am not."',
    ],
    topics: {
      brother: [
        '"He followed a red scrap into the fen. Said it looked like Mom\'s shawl. Mom\'s been gone three winters."',
        '"If the fenwitch knows, she\'ll trade knowing for a favor. That\'s how she breathes."',
      ],
    },
    favors: ['action', 'honesty'],
    distrust: ['pity without help'],
  },
  fenwitch: {
    id: 'fenwitch',
    name: 'Ila of the Reeds',
    title: 'fenwitch',
    voice: ['amused', 'ancient-adjacent'],
    greetings: [
      'Ila does not look surprised. "The mud announced you."',
      '"Speak carefully. The fen edits careless sentences."',
    ],
    topics: {
      boy: [
        '"The boy lives. For now. The chapel took his curiosity as tithe. Bring him out, or leave him to learn drowning manners."',
        '"I can point the way. Pointing costs: a truth you have not told anyone, or a service under the ridge."',
      ],
      chapel: [
        '"Sunken. Not silent. Keys still turn things that prefer to stay locked."',
      ],
    },
    favors: ['interesting truths', 'keeping bargains'],
    distrust: ['liars who enjoy it'],
    questHook: 'apprentice',
  },
  captain_rhel: {
    id: 'captain_rhel',
    name: 'Captain Rhel',
    title: 'ghost of a garrison',
    voice: ['formal', 'hollow'],
    greetings: [
      'A figure in scorched armor regards you. Whether living or habit is unclear. "State your purpose at Burnt Watch."',
      '"The tower remembers orders. Do you bring any?"',
    ],
    topics: {
      watch: [
        '"We held. Then fire. Then paper peace. Holding continues in worse weather."',
        '"Ash Camp is not enemy. Not friend. A question with spears."',
      ],
      dispatch: [
        'Rhel takes the case with ceremonial care. "Orders complete a circle. Circles can be cages or shelter."',
      ],
    },
    favors: ['duty', 'clear reports'],
    distrust: ['deserters', 'tourists'],
  },
  serra: {
    id: 'serra',
    name: 'Serra',
    title: 'ash camp warden',
    voice: ['precise', 'iron'],
    greetings: [
      'Serra\'s gaze inventories you. "Weapons visible. Intentions less so. Speak."',
      '"If Mira sent you, say so. If she didn\'t, invent less."',
    ],
    topics: {
      camp: [
        '"We keep the ridge from becoming a second war. That requires ugly compromises and clean knives."',
        '"Hollowmere wants safety without knowing the cost. I invoice reality."',
      ],
      alliance: [
        '"An alliance means shared watches and shared blame. Bring Mira\'s word, or bring nothing."',
      ],
    },
    favors: ['competence', 'straight deals'],
    distrust: ['performative heroes'],
    questHook: 'alliance',
  },
  kel: {
    id: 'kel',
    name: 'Kel',
    title: 'scout',
    voice: ['quick', 'dry'],
    greetings: [
      'Kel tosses you a strip of dried meat. "Tax for entering camp. It\'s edible. Mostly."',
      '"You walked the Ashroad and lived. Congrats. Lower the bar next time."',
    ],
    topics: {
      wolves: [
        '"Ash-wolves aren\'t natural hungry. Someone\'s teaching them patterns. Patterns have authors."',
        '"Proof means ears or a collar. Collars would be interesting. And bad."',
      ],
      paths: [
        '"Fen paths shift. Ridge paths don\'t. Choose which kind of honest you want."',
      ],
    },
    favors: ['good intel', 'not wasting arrows'],
    distrust: ['loud feet'],
  },
  echo: {
    id: 'echo',
    name: 'The Echo',
    title: 'chapel remnant',
    voice: ['layered', 'gentle-wrong'],
    greetings: [
      'A voice without a clear throat greets you. "Another pair of ears. Welcome to unfinished prayer."',
      '"Do not fear the water. Fear answering it."',
    ],
    topics: {
      boy: [
        '"He is in the dry alcove, humming to stay brave. Take him. Leave the spiral key if you are wise. Take it if you are necessary."',
      ],
      spiral: [
        '"The spiral is listening practice. The world shouted itself hoarse in war. Someone must still hear."',
      ],
    },
    favors: ['reverence', 'rescue without vandalism'],
    distrust: ['loot-first hearts'],
  },
};

export function getNpc(id: string): NpcDef | undefined {
  return NPCS[id];
}
