import { useMemo, useState } from 'react';
import { CLASSES, type ClassDef } from '../content/classes';
import { classFromPrompt } from '../engine/customClass';
import { ATTR_LABEL } from '../engine/dice';
import type { Attribute } from '../engine/types';

interface Props {
  onBack: () => void;
  onStart: (name: string, classId: string, custom?: ClassDef) => void;
}

export function CharacterCreate({ onBack, onStart }: Props) {
  const [name, setName] = useState('');
  const [mode, setMode] = useState<'preset' | 'custom'>('preset');
  const [classId, setClassId] = useState(CLASSES[0]!.id);
  const [prompt, setPrompt] = useState('');

  const custom = useMemo(() => {
    if (mode !== 'custom' || prompt.trim().length < 3) return null;
    return classFromPrompt(prompt);
  }, [mode, prompt]);

  const selected: ClassDef | null =
    mode === 'custom' ? custom : (CLASSES.find((c) => c.id === classId) ?? null);

  function start() {
    if (mode === 'custom') {
      if (!custom) return;
      onStart(name.trim() || 'Wanderer', 'custom', custom);
      return;
    }
    onStart(name.trim() || 'Wanderer', classId);
  }

  return (
    <section className="create-screen">
      <h1>Who walks the Marches?</h1>
      <p>Name yourself. Pick a calling — or describe one in a line.</p>

      <div className="field">
        <label htmlFor="hero-name">Name</label>
        <input
          id="hero-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Rowan Vale"
          maxLength={24}
          autoFocus
        />
      </div>

      <div className="mode-toggle" role="tablist" aria-label="Calling mode">
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'preset'}
          className={`mode-toggle__btn${mode === 'preset' ? ' is-on' : ''}`}
          onClick={() => setMode('preset')}
        >
          Callings
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'custom'}
          className={`mode-toggle__btn${mode === 'custom' ? ' is-on' : ''}`}
          onClick={() => setMode('custom')}
        >
          Make my own
        </button>
      </div>

      {mode === 'preset' ? (
        <div className="class-grid" role="listbox" aria-label="Character calling">
          {CLASSES.map((c) => (
            <button
              key={c.id}
              type="button"
              role="option"
              aria-selected={classId === c.id}
              className={`class-option${classId === c.id ? ' is-selected' : ''}`}
              onClick={() => setClassId(c.id)}
            >
              <strong>{c.name}</strong>
              <span>{c.blurb}</span>
            </button>
          ))}
        </div>
      ) : (
        <div className="field">
          <label htmlFor="class-prompt">Describe your calling</label>
          <input
            id="class-prompt"
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder="e.g. quiet fen witch, sharp-tongued merchant, tired knight"
            maxLength={80}
          />
          <p className="field-hint">No AI — keywords shape stats and gear (fighter, scout, healer, mage, thief, bard…).</p>
        </div>
      )}

      {selected && (
        <div className="class-preview" aria-live="polite">
          <strong>{selected.name}</strong>
          <span>{selected.blurb}</span>
          <div className="class-preview__stats">
            {(Object.keys(selected.attributes) as Attribute[]).map((k) => (
              <span key={k}>
                {ATTR_LABEL[k].slice(0, 3)} {selected.attributes[k]}
              </span>
            ))}
            <span>HP {selected.hp}</span>
          </div>
        </div>
      )}

      <div className="title-actions">
        <button
          type="button"
          className="btn btn--primary"
          disabled={mode === 'custom' && !custom}
          onClick={start}
        >
          Enter Hollowmere
        </button>
        <button type="button" className="btn btn--ghost" onClick={onBack}>
          Back
        </button>
      </div>
    </section>
  );
}
