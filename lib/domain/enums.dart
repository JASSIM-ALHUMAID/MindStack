/// Where a card came from. `shared` means it was imported from a deck file.
enum CardSource { manual, slide, pdf, photo, shared }

/// The four recall buttons on the Review screen.
enum Rating { again, hard, good, easy }

/// How hard a quiz question is.
enum Difficulty { easy, moderate, hard }
