import { useEffect, useState } from 'react';
import { AiSettings } from './components/AiSettings';
import { CharacterCreate } from './components/CharacterCreate';
import { PlayScreen } from './components/PlayScreen';
import { TitleScreen } from './components/TitleScreen';
import type { ClassDef } from './content/classes';
import { beginPlay, resolveAction } from './engine/actions';
import {
  generateCapellaCrushTaunt,
  weaveCapellaTurn,
} from './engine/capellaAi';
import { createNewGame } from './engine/create';
import { pushLog } from './engine/helpers';
import {
  capellaDoomRemaining,
  clearSave,
  hardResetProgress,
  hasSave,
  loadGame,
  saveGame,
  tightenCapellaLoop,
} from './engine/save';
import type { GameState, Screen } from './engine/types';
import './styles/app.scss';

export default function App() {
  const [screen, setScreen] = useState<Screen>('title');
  const [state, setState] = useState<GameState | null>(null);
  const [saveExists, setSaveExists] = useState(() => hasSave());
  const [toast, setToast] = useState<string | null>(null);
  const [aiOpen, setAiOpen] = useState(false);
  const [thinking, setThinking] = useState(false);

  useEffect(() => {
    if (!toast) return;
    const t = window.setTimeout(() => setToast(null), 2800);
    return () => window.clearTimeout(t);
  }, [toast]);

  useEffect(() => {
    if (screen !== 'play' || !state) return;
    saveGame(state);
  }, [screen, state]);

  function startNew(name: string, classId: string, custom?: ClassDef) {
    clearSave();
    const game = beginPlay(createNewGame(name, classId, undefined, custom));
    setState(game);
    setScreen('play');
    setSaveExists(true);
    if (game.flags.crushed_by_capella) {
      void adornCrush(game, 'toes');
    }
  }

  function continueGame() {
    const loaded = loadGame();
    if (!loaded) {
      setToast('No save found.');
      return;
    }
    setState(loaded);
    setScreen('play');
  }

  async function adornCrush(s: GameState, kind: 'struggle' | 'crush' | 'toes' | 'wiggle') {
    const silent = kind === 'wiggle';
    if (!silent) setThinking(true);
    try {
      const { text } = await generateCapellaCrushTaunt(s, kind);
      setState((prev) => {
        const base = prev ?? s;
        const next = structuredClone(base);
        pushLog(next, { kind: 'narration', text: `**Capella:** ${text}` });
        return next;
      });
    } finally {
      if (!silent) setThinking(false);
    }
  }

  async function runTurn(input: { choiceId?: string; freeText?: string }, labelHint?: string) {
    if (!state || thinking) return;
    setThinking(true);
    try {
      let next = resolveAction(state, input);
      setState(next);

      const label =
        labelHint ||
        input.freeText ||
        state.choices.find((c) => c.id === input.choiceId)?.label ||
        'something foolish';

      if (next.flags.crushed_by_capella) {
        const struggle = ['capella_struggle', 'capella_beg', 'capella_crawl', 'capella_escape'].includes(
          input.choiceId ?? '',
        );
        const justCrushed =
          !state.flags.crushed_by_capella && Boolean(next.flags.crushed_by_capella);
        if (struggle) await adornCrush(next, 'struggle');
        else if (justCrushed) {
          await adornCrush(next, next.flags.between_toes ? 'toes' : 'crush');
        }
        return;
      }

      // Expansive AI story + Capella shrink interrupt reacting to this character
      next = await weaveCapellaTurn(next, label);
      setState(next);
    } finally {
      setThinking(false);
    }
  }

  function manualSave() {
    if (!state) return;
    saveGame(state);
    setSaveExists(true);
    setToast('Journey saved.');
  }

  return (
    <div className="app-shell">
      {screen === 'title' && (
        <TitleScreen
          hasSave={saveExists}
          onNew={() => setScreen('create')}
          onContinue={continueGame}
          onOpenAi={() => setAiOpen(true)}
          onHardReset={() => {
            hardResetProgress();
            setState(null);
            setSaveExists(false);
            setToast('Hard restart — Capella forgot you. For now.');
          }}
        />
      )}
      {screen === 'create' && (
        <CharacterCreate onBack={() => setScreen('title')} onStart={startNew} />
      )}
      {screen === 'play' && state && (
        <PlayScreen
          state={state}
          thinking={thinking}
          onToeWiggle={() => {
            if (!state.flags.crushed_by_capella || thinking) return;
            void adornCrush(state, 'wiggle');
          }}
          onChoice={(id) => {
            const label = state.choices.find((c) => c.id === id)?.label;
            void runTurn({ choiceId: id }, label);
          }}
          onFreeText={(text) => void runTurn({ freeText: text }, text)}
          onSave={manualSave}
          onTitle={() => {
            if (state.flags.crushed_by_capella) {
              const unlockAt = Number(state.flags.crush_unlock_at) || 0;
              if (Date.now() < unlockAt) {
                void runTurn({ choiceId: 'capella_escape' }, 'Escape');
                setToast('Capella sealed the exit.');
                return;
              }
            }
            const loops = tightenCapellaLoop();
            const doom = capellaDoomRemaining();
            const next = {
              ...state,
              flags: { ...state.flags, capella_loops: loops },
            };
            saveGame(next);
            setState(next);
            setSaveExists(true);
            setScreen('title');
            setToast(
              state.flags.between_toes
                ? 'Title waits under her sole.'
                : doom <= 0
                  ? 'Next time: no road. Between her toes.'
                  : `Capella closer — ${doom} choice${doom === 1 ? '' : 's'} next run.`,
            );
          }}
        />
      )}
      <AiSettings open={aiOpen} onClose={() => setAiOpen(false)} />
      {toast && (
        <div className="toast" role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
