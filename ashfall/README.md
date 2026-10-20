# Ashfall

A long-running solo D&D-style RPG with a **rule-based dungeon master** — no AI required.

You play a wanderer in the Ashfall Marches. The game narrates scenes from world state, tables, and memory; you choose actions (or type freeform intents). Dice, relationships, quests, and chronicle entries keep the campaign feeling continuous across sessions.

## Run

```bash
cd ashfall
npm install
npm run dev
```

Then open the local URL Vite prints (usually `http://localhost:5173`).

## Play

1. **Begin a journey** — name your hero and pick a calling (Warden, Hearthwright, Ashblade, or Charmer).
2. Explore **Hollowmere** and the wider Marches: talk, investigate, travel, rest, fight.
3. Follow intertwined quests (wolves, missing apprentice, dispatch, chapel, alliance).
4. Progress **autosaves** to your browser; use **Save** / **Continue** anytime.

## How the DM works (no AI)

- **Scene composer** builds narration from location atmosphere, time, weather, and recent chronicle.
- **Choices** are contextual (exits, NPCs present, inventory, quest flags).
- **Freeform text** is matched to verbs/targets against available actions; unmatched attempts get an improvised skill check.
- **Encounters**, clocks, and NPC attitudes change the world over many turns.

## Build

```bash
npm run build
npm run preview
```
