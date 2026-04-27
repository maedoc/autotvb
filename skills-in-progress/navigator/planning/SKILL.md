---
name: tvb-navigator-planning
description: Plan and decompose TVB whole-brain modeling tasks into concrete implementation steps. Use when starting a new workflow, writing an initial plan, or deciding how to break a scientific question into code tasks. Triggers on planning, step-by-step, workflow design, decomposition, task breakdown.
---

# TVB Navigator: Planning & Workflow Design

## Planning Template
For any scientific question, produce:
1. **Model choice**: Which neural-mass model and why
2. **Connectivity**: Default 76 or custom; speed value
3. **Coupling**: Type and scaling
4. **Stimulation** (if any): Region IDs, temporal equation, parameters
5. **Integration**: Deterministic vs stochastic; dt; noise level
6. **Monitors**: What to record and at what sampling rate
7. **Analysis / plots**: Expected visualizations
   - Explicitly state whether each analysis is **stimulus-locked** (time-locked to onset) or **ongoing / baseline**.
8. **Termination criteria**: How to know the simulation succeeded

## Rules
- Be explicit: name TVB classes, expected figure types, key parameters.
- Prioritize scientific validity over code polish.
- Keep initial plans under 400 tokens; add detail in review turns.
- Do not request supplementary analyses (e.g., full PSD, global FC, extra monitors) unless the goal explicitly requires them; keep the workflow minimal and focused.
- If the driver is stuck for >2 turns, suggest a simpler intermediate step.
