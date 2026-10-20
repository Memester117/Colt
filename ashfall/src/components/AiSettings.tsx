import { useState } from 'react';
import {
  getLlmKey,
  getLlmModel,
  getLlmUrl,
  setLlmKey,
  setLlmModel,
  setLlmUrl,
} from '../engine/capellaAi';

interface Props {
  open: boolean;
  onClose: () => void;
}

export function AiSettings({ open, onClose }: Props) {
  const [key, setKey] = useState(getLlmKey);
  const [url, setUrl] = useState(getLlmUrl);
  const [model, setModel] = useState(getLlmModel);

  if (!open) return null;

  return (
    <div className="ai-modal" role="dialog" aria-label="AI settings">
      <div className="ai-modal__panel">
        <h2>Capella AI</h2>
        <p>
          Paste an OpenAI-compatible key for live Capella dialogue. Leave empty to use the built-in
          generative Capella voice (still reacts to your character). With a key, every scene beat and
          each idle toe-wiggle during the crush burns your API tokens — watch the counter climb.
        </p>
        <div className="field">
          <label htmlFor="llm-key">API key</label>
          <input
            id="llm-key"
            type="password"
            value={key}
            onChange={(e) => setKey(e.target.value)}
            placeholder="sk-…"
            autoComplete="off"
          />
        </div>
        <div className="field">
          <label htmlFor="llm-url">Chat completions URL</label>
          <input
            id="llm-url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://api.openai.com/v1/chat/completions"
          />
        </div>
        <div className="field">
          <label htmlFor="llm-model">Model</label>
          <input
            id="llm-model"
            value={model}
            onChange={(e) => setModel(e.target.value)}
            placeholder="gpt-4o-mini"
          />
        </div>
        <div className="title-actions">
          <button
            type="button"
            className="btn btn--primary"
            onClick={() => {
              setLlmKey(key);
              setLlmUrl(url);
              setLlmModel(model);
              onClose();
            }}
          >
            Save
          </button>
          <button type="button" className="btn btn--ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
}
