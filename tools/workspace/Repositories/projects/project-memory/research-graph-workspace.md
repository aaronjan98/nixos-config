# Research Graph Workspace

## Status
Incubation

## Core idea
Build a graph-native mathematical research workspace where the graph is the
primary canvas and everything else is contextual support.

The product is not an Overleaf replacement. Its main value is making the
dependency structure of a research project visible and navigable.

## Product shape
- The graph is the default full-screen workspace
- A left overlay panel can open over the graph when needed
- The overlay can switch modes such as:
  - conversation thread with a collaborator or professor
  - linked document/resource view
  - notes or metadata later if needed
- A top-right control opens graph selection and graph history/snapshot actions

## Primary value
- Show how definitions, lemmas, theorems, proof ideas, papers, and notes relate
- Let a node open the linked external resource or relevant document section
- Keep the graph as the center of attention rather than splitting attention
  evenly across fixed panels

## Non-goals for early versions
- Replacing Overleaf as a full collaborative editor
- Replacing Zoom or live call software
- Building a generic whiteboard

## Likely node types
- `definition`
- `lemma`
- `theorem`
- `proof idea`
- `open question`
- `paper`
- `section`
- `meeting note`

## Likely edge types
- `depends on`
- `uses`
- `motivates`
- `needs proof`
- `appears in`

## Early v1 direction
- Full-screen graph canvas
- Left overlay for conversation and linked resource viewing
- Click a node to open the relevant linked resource in the overlay
- Support multiple graphs plus graph snapshots/history
- Keep document editing external at first

## Why it is separate from `agent-display`
- `agent-display` is conversation-first with future graph features
- this idea is graph-first with conversation as contextual support
- they may share architectural ideas, but they are different products
