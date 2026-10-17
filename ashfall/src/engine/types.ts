export type Attribute =
  | 'might'
  | 'grace'
  | 'wits'
  | 'spirit'
  | 'presence'
  | 'endurance';

export type TimeOfDay = 'dawn' | 'day' | 'dusk' | 'night';
export type Weather = 'clear' | 'mist' | 'rain' | 'ashwind' | 'storm';
export type Screen = 'title' | 'create' | 'play';

export type ActionKind =
  | 'travel'
  | 'talk'
  | 'investigate'
  | 'rest'
  | 'fight'
  | 'sneak'
  | 'help'
  | 'bargain'
  | 'use'
  | 'wait'
  | 'flee'
  | 'custom';

export interface Attributes {
  might: number;
  grace: number;
  wits: number;
  spirit: number;
  presence: number;
  endurance: number;
}

export interface Item {
  id: string;
  name: string;
  description: string;
  tags: string[];
  quantity: number;
}

export interface NpcMemory {
  met: boolean;
  attitude: number; // -3..3
  secretsKnown: string[];
  lastTopic?: string;
}

export interface QuestState {
  id: string;
  stage: number;
  completed: boolean;
  failed: boolean;
  notes: string[];
}

export interface ChronicleEntry {
  id: string;
  day: number;
  text: string;
  tags: string[];
  important: boolean;
}

export interface LogLine {
  id: string;
  kind: 'narration' | 'system' | 'roll' | 'choice' | 'result';
  text: string;
  roll?: {
    label: string;
    total: number;
    dc: number;
    success: boolean;
  };
}

export interface Choice {
  id: string;
  label: string;
  kind: ActionKind;
  hint?: string;
  targetId?: string;
  attribute?: Attribute;
  dc?: number;
  requires?: string[];
  hidden?: boolean;
}

export interface EncounterState {
  id: string;
  name: string;
  threat: number;
  hp: number;
  maxHp: number;
  tags: string[];
  canFlee: boolean;
}

export interface GameState {
  version: 1;
  seed: number;
  screen: Screen;
  playerName: string;
  playerClass: string;
  attributes: Attributes;
  hp: number;
  maxHp: number;
  stress: number;
  maxStress: number;
  coin: number;
  day: number;
  time: TimeOfDay;
  weather: Weather;
  locationId: string;
  inventory: Item[];
  npcs: Record<string, NpcMemory>;
  flags: Record<string, boolean | number | string>;
  quests: Record<string, QuestState>;
  clocks: Record<string, number>;
  chronicle: ChronicleEntry[];
  log: LogLine[];
  choices: Choice[];
  encounter: EncounterState | null;
  chapter: number;
  turns: number;
  lastSaveAt: number;
}

export interface ActionInput {
  choiceId?: string;
  freeText?: string;
}

export interface TurnResult {
  state: GameState;
  advanced: boolean;
}
