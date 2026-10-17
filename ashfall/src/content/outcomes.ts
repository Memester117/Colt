/** Outcome text banks — picked by grade + action flavor. */

export type OutcomeGrade = 'crit' | 'success' | 'mixed' | 'fail' | 'fumble';

export function gradeFromCheck(result: {
  success: boolean;
  crit: boolean;
  fumble: boolean;
  total: number;
  dc: number;
}): OutcomeGrade {
  if (result.crit) return 'crit';
  if (result.fumble) return 'fumble';
  if (result.success) {
    if (result.total <= result.dc + 1) return 'mixed'; // bare success — cost attached by caller
    return 'success';
  }
  if (result.total >= result.dc - 1) return 'mixed'; // near miss — partial win
  return 'fail';
}

export const INVESTIGATE = {
  crit: [
    'The place unfolds for you — a seam others miss, a truth that wants witnesses.',
    'You catch the pattern under the noise. Something important clicks into place.',
    'Luck and attention kiss. You find more than you meant to.',
  ],
  success: [
    'Patience pays. A detail separates itself from the clutter.',
    'You notice what the room hoped you would not.',
    'Careful eyes earn a careful secret.',
  ],
  mixed: [
    'You find something useful — and also a reason to glance over your shoulder.',
    'Half an answer surfaces. The other half costs you calm.',
    'A clue, yes. Clean hands, no.',
  ],
  fail: [
    'You search until your eyes ache. The place keeps its cards close.',
    'Nothing useful reveals itself — only the ordinary stubbornness of objects.',
    'Dust, old wood, and the insult of wasted minutes.',
  ],
  fumble: [
    'You knock something loose. The noise feels personal.',
    'Your search becomes a small spectacle. Subtlety files a complaint.',
    'You lean too hard on a board that was never a board\'s friend.',
  ],
} as const;

export const REST = {
  crit: [
    'Sleep arrives like forgiveness. You wake clearer than the weather.',
    'Rest remakes you. Even your worries take the night off.',
  ],
  success: [
    'Sleep takes you kindly. The body keeps its bargain.',
    'You mend in the quiet between breaths.',
  ],
  mixed: [
    'You sleep, but dreams rehearse old arguments. Healing comes with grit in it.',
    'Rest helps — partially. Morning arrives with footnotes.',
  ],
  fail: [
    'Rest frays. Dreams arrive wearing boots.',
    'You wake unrestored and slightly more suspicious of pillows.',
  ],
  fumble: [
    'A startle cuts the night open. You gain neither sleep nor dignity.',
    'Something prowls the edge of your camp. Rest becomes a rumor.',
  ],
} as const;

export const COMBAT_HIT = {
  crit: [
    'A perfect line — steel, breath, and timing agree. The foe reels.',
    'You find the opening as if it owed you money.',
  ],
  success: [
    'You land a clean exchange. The fight tilts.',
    'Pressure, then contact. They feel you now.',
  ],
  mixed: [
    'You score a hit — and catch a scrape for the privilege.',
    'Trade blows: yours heavier, theirs annoying.',
  ],
  fail: [
    'Your strike slides wide. They punish the gap.',
    'Bad footing, worse timing. Pain teaches briefly.',
  ],
  fumble: [
    'Your weapon betrays the moment. They do not.',
    'A stumble invites teeth, steel, or both.',
  ],
} as const;

export const FLEE = {
  crit: [
    'You vanish like a rumor with good legs. Nothing follows but dust.',
  ],
  success: [
    'You break contact — dignity optional, lungs mandatory.',
    'Distance becomes a friend. The threat keeps its original appointment.',
  ],
  mixed: [
    'You escape, but not cleanly. Something catches you on the way out.',
  ],
  fail: [
    'Fleeing fails. The threat closes the distance with ugly enthusiasm.',
  ],
  fumble: [
    'You trip into the exact wrong place. Escape becomes a spectator sport.',
  ],
} as const;

export const TRAVEL = {
  uneventful: [
    'Road underfoot. Sky overhead. The Marches rearrange around your decision.',
    'You leave one place and let the path argue with your legs.',
    'Miles pass like unread pages — blank, useful, slightly ominous.',
  ],
  weather: [
    'Weather sharpens its pencils on your cloak. You keep walking anyway.',
    'The sky makes a point. Your boots take notes.',
  ],
  find_coin: [
    'A glint in the mud turns out to be coin with someone else\'s bad day still on it.',
    'You pocket stray coin. Morality files it under "found."',
  ],
  traveler: [
    'A traveler shares a nod, a rumor, and the blessed gift of not asking questions.',
    'You pass a cart. The driver warns you about "listening water" and sells you nothing.',
  ],
  omen: [
    'Crows rearrange themselves into something almost like advice.',
    'A milepost has been freshly carved. Someone wants the road to mean more.',
  ],
  snag: [
    'A snag in the path costs you time and a little blood-price in patience.',
    'Soft ground lies. You learn the hard, muddy way.',
  ],
} as const;

export const WAIT = {
  calm: [
    'You let time pass. The Marches continue without needing your permission.',
    'Watching becomes a kind of listening. Hours thin themselves out.',
  ],
  useful: [
    'Waiting pays. You overhear a scrap that rearranges your map of worry.',
    'A quiet hour gifts you a detail: who left, who lied, who still watches.',
  ],
  tense: [
    'The quiet is not empty. Something in it practices breathing.',
    'You wait. A dog barks somewhere. History clears its throat.',
  ],
} as const;

export const IMPROV = {
  crit: [
    'The Marches briefly agree you are the author of this scene.',
    'Unlikely becomes inevitable under your hands.',
  ],
  success: [
    'Against modest odds, it works. Something useful shifts.',
    'Fortune, skill, or stubborn charm — the attempt lands.',
  ],
  mixed: [
    'It half-works. You get what you need and a bruise you didn\'t order.',
    'Success with splinters. Progress, loudly negotiated.',
  ],
  fail: [
    'The world declines your suggestion. Reality keeps its own script.',
    'It almost works — which is a poet\'s way of saying it doesn\'t.',
  ],
  fumble: [
    'Your clever plan becomes public entertainment. The Marches applaud unkindly.',
    'You invent a counterplan for yourself by accident. It hurts.',
  ],
} as const;

export const GENERIC = {
  crit: [
    'Everything aligns. The moment bends toward you like a reed in good wind.',
  ],
  success: [
    'It works well enough to change the next few minutes.',
    'Your approach finds purchase. The moment bends.',
  ],
  mixed: [
    'You get the result — taxed. Nothing free in the Marches.',
  ],
  fail: [
    'It falters. You adapt, slightly bruised in pride.',
    'The attempt teaches you what not to try twice.',
  ],
  fumble: [
    'Catastrophe in miniature. You will tell this story someday, edited.',
  ],
} as const;
