import { useEffect, useState } from 'react';
import { CharacterCreate } from './components/CharacterCreate';
import { PlayScreen } from './components/PlayScreen';
import { TitleScreen } from './components/TitleScreen';
import { beginPlay, resolveAction } from './engine/actions';
import { createNewGame } from './engine/create';
import { clearSave, hasSave, loadGame, saveGame } from './engine/save';
import type { GameState, Screen } from './engine/types';
import './styles/app.scss';

export default function App() {
  const [screen, setScreen] = useState<Screen>('title');
  const [state, setState] = useState<GameState | null>(null);
  const [saveExists, setSaveExists] = useState(() => hasSave());
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    if (!toast) return;
    const t = window.setTimeout(() => setToast(null), 2200);
    return () => window.clearTimeout(t);
  }, [toast]);

  // Autosave while playing
  useEffect(() => {
    if (screen !== 'play' || !state) return;
    saveGame(state);
  }, [screen, state]);

  function startNew(name: string, classId: string) {
    clearSave();
    const game = beginPlay(createNewGame(name, classId));
    setState(game);
    setScreen('play');
    setSaveExists(true);
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

  function act(choiceId: string) {
    if (!state) return;
    setState(resolveAction(state, { choiceId }));
  }

  function free(text: string) {
    if (!state) return;
    setState(resolveAction(state, { freeText: text }));
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
        />
      )}
      {screen === 'create' && (
        <CharacterCreate onBack={() => setScreen('title')} onStart={startNew} />
      )}
      {screen === 'play' && state && (
        <PlayScreen
          state={state}
          onChoice={act}
          onFreeText={free}
          onSave={manualSave}
          onTitle={() => {
            saveGame(state);
            setSaveExists(true);
            setScreen('title');
          }}
        />
      )}
      {toast && (
        <div className="toast" role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
