import { useEffect, useRef, useState } from 'react';
import { getLocation } from '../content/locations';
import { QUESTS } from '../content/quests';
import { ATTR_LABEL } from '../engine/dice';
import { timeLabel, weatherLabel } from '../engine/create';
import type { Attribute, GameState } from '../engine/types';

interface Props {
  state: GameState;
  onChoice: (choiceId: string) => void;
  onFreeText: (text: string) => void;
  onSave: () => void;
  onTitle: () => void;
}

function renderText(text: string) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return parts.map((part, i) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={i}>{part.slice(2, -2)}</strong>;
    }
    return <span key={i}>{part}</span>;
  });
}

export function PlayScreen({ state, onChoice, onFreeText, onSave, onTitle }: Props) {
  const [text, setText] = useState('');
  const logRef = useRef<HTMLDivElement>(null);
  const loc = getLocation(state.locationId);

  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [state.log.length]);

  const attrs = Object.entries(state.attributes) as Array<[Attribute, number]>;
  const activeQuests = Object.values(state.quests).filter((q) => !q.completed);
  const doneQuests = Object.values(state.quests).filter((q) => q.completed);

  return (
    <div className="play">
      <aside className="play-side-left">
        <div className="panel">
          <h2>{state.playerName}</h2>
          <div className="stat-row">
            <span>{state.playerClass}</span>
            <span>Ch. {state.chapter}</span>
          </div>
          <div className="stat-row">
            <span>HP</span>
            <span>
              {state.hp}/{state.maxHp}
            </span>
          </div>
          <div className="meter" aria-hidden="true">
            <i style={{ width: `${(state.hp / state.maxHp) * 100}%` }} />
          </div>
          <div className="stat-row">
            <span>Stress</span>
            <span>
              {state.stress}/{state.maxStress}
            </span>
          </div>
          <div className="meter meter--stress" aria-hidden="true">
            <i style={{ width: `${(state.stress / state.maxStress) * 100}%` }} />
          </div>
          <div className="stat-row">
            <span>Coin</span>
            <span>{state.coin}</span>
          </div>
          <div className="stat-row">
            <span>Day</span>
            <span>{state.day}</span>
          </div>
        </div>

        <div className="panel side-block">
          <h2>Attributes</h2>
          <div className="attr-grid">
            {attrs.map(([k, v]) => (
              <div key={k}>
                <span>{ATTR_LABEL[k]}</span>
                <span>{v}</span>
              </div>
            ))}
          </div>
        </div>
      </aside>

      <main className="play-main">
        <header className="play-header">
          <h1>{loc.name}</h1>
          <div className="play-meta">
            {timeLabel(state.time)} · {weatherLabel(state.weather)} · {loc.region}
          </div>
        </header>

        {state.encounter && (
          <div className="encounter-banner">
            In conflict with {state.encounter.name} ({state.encounter.hp}/{state.encounter.maxHp})
          </div>
        )}

        <div className="log" ref={logRef} aria-live="polite">
          {state.log.map((line) => (
            <div key={line.id} className={`log-line log-line--${line.kind}`}>
              {renderText(line.text)}
            </div>
          ))}
        </div>

        <div className="choices">
          {state.choices.map((c) => (
            <button
              key={c.id}
              type="button"
              className="choice"
              onClick={() => onChoice(c.id)}
            >
              <span>{c.label}</span>
              {c.hint && <small>{c.hint}</small>}
            </button>
          ))}
        </div>

        <form
          className="freeform"
          onSubmit={(e) => {
            e.preventDefault();
            const t = text.trim();
            if (!t) return;
            onFreeText(t);
            setText('');
          }}
        >
          <input
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="Or type what you try… (talk to Mira, search the fen, rest)"
            aria-label="Freeform action"
          />
          <button type="submit" className="btn btn--primary">
            Try
          </button>
        </form>

        <div className="toolbar">
          <button type="button" className="btn" onClick={onSave}>
            Save
          </button>
          <button type="button" className="btn btn--ghost" onClick={onTitle}>
            Title
          </button>
        </div>
      </main>

      <aside className="play-side-right">
        <div className="panel">
          <h2>Pack</h2>
          <ul className="inv-list">
            {state.inventory.length === 0 && <li>Empty pockets, full ambition.</li>}
            {state.inventory.map((item) => (
              <li key={item.id}>
                <strong>
                  {item.name}
                  {item.quantity > 1 ? ` ×${item.quantity}` : ''}
                </strong>
                <div>{item.description}</div>
              </li>
            ))}
          </ul>
        </div>

        <div className="panel side-block">
          <h2>Quests</h2>
          <ul className="quest-list">
            {activeQuests.length === 0 && doneQuests.length === 0 && (
              <li>No threads yet — listen in town.</li>
            )}
            {activeQuests.map((q) => {
              const def = QUESTS[q.id];
              return (
                <li key={q.id}>
                  <strong>{def?.name ?? q.id}</strong>
                  <div>{def?.stages[q.stage] ?? `Stage ${q.stage}`}</div>
                </li>
              );
            })}
            {doneQuests.map((q) => (
              <li key={q.id}>
                <strong>✓ {QUESTS[q.id]?.name ?? q.id}</strong>
              </li>
            ))}
          </ul>
        </div>

        <div className="panel side-block">
          <h2>Chronicle</h2>
          <ul className="chronicle-list">
            {state.chronicle.slice(0, 8).map((c) => (
              <li key={c.id}>
                Day {c.day}: {c.text}
              </li>
            ))}
          </ul>
        </div>
      </aside>
    </div>
  );
}
