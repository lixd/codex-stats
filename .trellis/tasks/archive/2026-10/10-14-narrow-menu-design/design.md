# Design boundary

Production: change MenuPanelView width320→288 and surgically fix narrow wrapping if necessary. Keep runtime behavior and parser untouched. Tests/UIPreview capture width follows production. Main App not auto installed/restarted.

Use prototype skill adapted to native app: separate Tests/MenuDesignPrototype native views and Scripts/render-menu-designs.sh captures native NSHostingView. Two visually distinct variants, same synthetic306.08M sample and model data; light/dark. Local comparison HTML may embed screenshots for side-by-side viewing, it is not runtime UI. No Git repository: keep prototypes labelled in test folder, no fabricated throwaway branch.

A: plain header, prominent total, four aligned list rows/dividers, compact model usage, low emphasis analysis button. B: subtle tinted hero, four grid metric tiles, visible model ranking, colored action. All five Token categories, model, refresh, status and quit shown.
