import { useEffect, useMemo, useRef, useState } from 'react';
import { CAPELLA_YT } from '../content/capella';
import { getLocation } from '../content/locations';
import { QUESTS } from '../content/quests';
import { ATTR_LABEL } from '../engine/dice';
import { timeLabel, weatherLabel } from '../engine/create';
import type { Attribute, Choice, ChoiceGroup, GameState } from '../engine/types';

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

function groupOf(c: Choice): ChoiceGroup {
  return c.group ?? (c.kind === 'travel' ? 'travel' : c.kind === 'talk' ? 'people' : 'pace');
}

function ytEmbed(id: string) {
  return `https://www.youtube.com/embed/${id}?autoplay=1&mute=1&controls=1&loop=1&playlist=${id}&rel=0&modestbranding=1&playsinline=1`;
}

export function PlayScreen({ state, onChoice, onFreeText, onSave, onTitle }: Props) {
  const [text, setText] = useState('');
  const [openTravelFor, setOpenTravelFor] = useState<string | null>(null);
  const [openPaceFor, setOpenPaceFor] = useState<string | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const logRef = useRef<HTMLDivElement>(null);
  const loc = getLocation(state.locationId);
  const sceneKey = `${state.locationId}:${state.encounter?.id ?? 'x'}:${state.turns}`;
  const showTravel = openTravelFor === sceneKey;
  const showPace = openPaceFor === sceneKey;

  const grouped = useMemo(() => {
    const map: Record<ChoiceGroup, Choice[]> = { focus: [], people: [], travel: [], pace: [] };
    for (const c of state.choices) map[groupOf(c)].push(c);
    return map;
  }, [state.choices]);

  const crushed = Boolean(state.flags.crushed_by_capella);
  const betweenToes = Boolean(state.flags.between_toes);
  const unlockAt = Number(state.flags.crush_unlock_at) || 0;
  const unlocked = crushed && now >= unlockAt;
  const remainSec = crushed ? Math.max(0, Math.ceil((unlockAt - now) / 1000)) : 0;

  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [state.log.length]);

  useEffect(() => {
    if (!crushed) return;
    const t = window.setInterval(() => setNow(Date.now()), 500);
    return () => window.clearInterval(t);
  }, [crushed, unlockAt]);

  const attrs = Object.entries(state.attributes) as Array<[Attribute, number]>;
  const activeQuests = Object.values(state.quests).filter((q) => !q.completed);
  const doneQuests = Object.values(state.quests).filter((q) => q.completed);
  const inCombat = Boolean(state.encounter);

  function tryTitle() {
    if (crushed && !unlocked) {
      onChoice('capella_escape');
      return;
    }
    onTitle();
  }

  return (
    <div className={`play${crushed ? ' play--crushed' : ''}`}>
      {!crushed && (
        <aside className={`play-side-left${sheetOpen ? ' is-open' : ''}`}>
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
      )}

      <main className="play-main">
        <header className="play-header">
          <div>
            <h1>{crushed ? (betweenToes ? 'Between her toes' : 'Under Capella') : loc.name}</h1>
            <div className="play-meta">
              {crushed
                ? betweenToes
                  ? 'bug-sized · no exit yet'
                  : 'shrunk · then stepped on'
                : `${timeLabel(state.time)} · ${weatherLabel(state.weather)} · ${loc.region}`}
            </div>
          </div>
          {!crushed && (
            <button
              type="button"
              className="btn btn--ghost sheet-toggle"
              onClick={() => setSheetOpen((o) => !o)}
            >
              {sheetOpen ? 'Hide sheet' : 'Sheet'}
            </button>
          )}
        </header>

        {state.encounter && !crushed && (
          <div className="encounter-banner">
            {state.encounter.name} · {state.encounter.hp}/{state.encounter.maxHp}
          </div>
        )}

        {crushed && (
          <div className="crush-stage">
            <div className="crush-videos">
              {CAPELLA_YT.map((id) => (
                <div key={id} className="crush-yt">
                  <iframe
                    title={`Capella crush ${id}`}
                    src={ytEmbed(id)}
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                  />
                </div>
              ))}
            </div>
            <video
              className="crush-gif"
              src="/capella-crush.mp4"
              poster="/capella-crush.jpg"
              autoPlay
              loop
              muted
              playsInline
            />
            <p className="crush-caption">
              {betweenToes
                ? 'Capella Emerada Lugunica — already bug-sized between her toes.'
                : 'Capella Emerada Lugunica — she shrinks you, then steps.'}
            </p>
            <p className="crush-lock">
              {unlocked
                ? 'Her foot eases… a crack of light. Maybe.'
                : `Held underfoot — ${remainSec}s before anything like mercy.`}
            </p>
          </div>
        )}

        <div className="log" ref={logRef} aria-live="polite">
          {state.log.map((line) => (
            <div key={line.id} className={`log-line log-line--${line.kind}`}>
              {renderText(line.text)}
            </div>
          ))}
        </div>

        <div className="action-dock">
          {crushed ? (
            <>
              <div className="choice-chips">
                {['capella_struggle', 'capella_beg', 'capella_crawl', 'capella_escape'].map((id) => {
                  const labels: Record<string, string> = {
                    capella_struggle: 'Struggle',
                    capella_beg: 'Beg',
                    capella_crawl: 'Crawl away',
                    capella_escape: 'Escape',
                  };
                  return (
                    <button key={id} type="button" className="chip" onClick={() => onChoice(id)}>
                      {labels[id]}
                    </button>
                  );
                })}
              </div>
              {unlocked ? (
                <button
                  type="button"
                  className="choice choice--focus choice--tiny"
                  onClick={() => onChoice('capella_restart')}
                >
                  <span>Wake again…?</span>
                  <small>if she allows it</small>
                </button>
              ) : (
                <p className="crush-hint">Struggle only entertains her. The real exit is sealed.</p>
              )}
            </>
          ) : (
            <>
              {grouped.focus.length > 0 && (
                <div className="choice-row choice-row--focus">
                  {grouped.focus.map((c) => (
                    <button
                      key={c.id}
                      type="button"
                      className="choice choice--focus"
                      onClick={() => onChoice(c.id)}
                    >
                      <span>{c.label}</span>
                      {c.hint && <small>{c.hint}</small>}
                    </button>
                  ))}
                </div>
              )}

              {grouped.people.length > 0 && (
                <div className="choice-block">
                  <span className="choice-label">Talk</span>
                  <div className="choice-chips">
                    {grouped.people.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        className="chip"
                        title={c.hint}
                        onClick={() => onChoice(c.id)}
                      >
                        {c.label}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {grouped.travel.length > 0 && !inCombat && (
                <div className="choice-block">
                  <button
                    type="button"
                    className="disclosure"
                    aria-expanded={showTravel}
                    onClick={() => setOpenTravelFor(showTravel ? null : sceneKey)}
                  >
                    Go somewhere
                    <span>{showTravel ? '−' : '+'}</span>
                  </button>
                  {showTravel && (
                    <div className="choice-chips choice-chips--dest">
                      {grouped.travel.map((c) => (
                        <button
                          key={c.id}
                          type="button"
                          className="chip chip--dest"
                          onClick={() => onChoice(c.id)}
                        >
                          {c.label}
                          {c.hint && <small>{c.hint}</small>}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {grouped.pace.length > 0 && (
                <div className="choice-block">
                  {inCombat ? (
                    <div className="choice-chips">
                      {grouped.pace.map((c) => (
                        <button
                          key={c.id}
                          type="button"
                          className="chip"
                          onClick={() => onChoice(c.id)}
                        >
                          {c.label}
                        </button>
                      ))}
                    </div>
                  ) : (
                    <>
                      <button
                        type="button"
                        className="disclosure"
                        aria-expanded={showPace}
                        onClick={() => setOpenPaceFor(showPace ? null : sceneKey)}
                      >
                        Look · rest · wait
                        <span>{showPace ? '−' : '+'}</span>
                      </button>
                      {showPace && (
                        <div className="choice-chips">
                          {grouped.pace.map((c) => (
                            <button
                              key={c.id}
                              type="button"
                              className="chip"
                              onClick={() => onChoice(c.id)}
                            >
                              {c.label}
                            </button>
                          ))}
                        </div>
                      )}
                    </>
                  )}
                </div>
              )}

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
                  placeholder="Or type what you try…"
                  aria-label="Freeform action"
                />
                <button type="submit" className="btn btn--primary">
                  Try
                </button>
              </form>
            </>
          )}

          <div className="toolbar">
            {!crushed && (
              <button type="button" className="btn" onClick={onSave}>
                Save
              </button>
            )}
            <button type="button" className="btn btn--ghost" onClick={tryTitle}>
              {crushed && !unlocked ? 'Title (sealed)' : 'Title'}
            </button>
          </div>
        </div>
      </main>

      {!crushed && (
        <aside className={`play-side-right${sheetOpen ? ' is-open' : ''}`}>
          <div className="panel">
            <h2>Pack</h2>
            <ul className="inv-list">
              {state.inventory.length === 0 && <li>Empty pockets.</li>}
              {state.inventory.map((item) => (
                <li key={item.id}>
                  <strong>
                    {item.name}
                    {item.quantity > 1 ? ` ×${item.quantity}` : ''}
                  </strong>
                </li>
              ))}
            </ul>
          </div>

          <div className="panel side-block">
            <h2>Quests</h2>
            <ul className="quest-list">
              {activeQuests.length === 0 && doneQuests.length === 0 && <li>No threads yet.</li>}
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
              {state.chronicle.slice(0, 6).map((c) => (
                <li key={c.id}>
                  Day {c.day}: {c.text}
                </li>
              ))}
            </ul>
          </div>
        </aside>
      )}
    </div>
  );
}
