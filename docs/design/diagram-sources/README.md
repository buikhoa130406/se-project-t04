# Editable PA3 diagram sources

The source files reproduce the consolidated figures used in the Word document. Run with Python and Pillow on Windows (Arial and Segoe UI fonts); generated PNGs go to `output/`.

- `draw_architecture_ui.py`: C4 context, container, components, deployment and UI navigation.
- `draw_classes.py`: entity and service class diagrams.
- `draw_data.py`: consolidated ERD.
- Original domain, sequence and state Mermaid models: `../domain/source/`, `../sequences/source/`, `../states/source/`. Render with a Mermaid-compatible editor.
- Current UI images are baseline-aligned SVG wireframes in `../ui/wireframes/`, with PNG exports used in Word. Historical PA2 mockups stay in requirements and are not the current PA3 screen figures.
- The updated hold lifecycle and release/reload sequence have editable SVG files alongside their PNGs in `../states/` and `../sequences/`; corresponding Mermaid descriptions are also updated.

The Word document and exported design specifications contain the integrated API/database conventions: bigint storage, decimal-string wire IDs, FACILITY_OWNER and notification read state. Conceptual domain/sequence/state models do not define physical database tables.
