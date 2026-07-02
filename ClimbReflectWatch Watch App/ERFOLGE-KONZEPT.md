# ERFOLGE-KONZEPT – Katalog & System

Von Claude Code entworfen (Konzept-Doc fehlte im Repo; Björn hat „Katalog
entwerfen + umsetzen" gewählt). **Schwellen sind kalibrierbar** – Zahlen unten
sind ein sinnvoller Startpunkt, kein Dogma.

## Prinzipien
- **Datenehrlich (S6/S27):** Jede Definition ist aus echten Daten berechenbar
  (Sessions, Ascents, Projekte). Keine erfundenen Werte.
- **Grade skalenübergreifend** über `Ascent.canonicalOrder` (S30), getrennt nach
  Disziplin (Boulder/Seil). Ungegradete (`isGraded == false`) zählen nie.
- **Trainingslast/Zeit** über `ClimbSession.activeSeconds` (RP-3).
- **Zeitfenster** B2/G2: **Kalendermonat/-jahr** (nicht rollierend) – einfach,
  nachvollziehbar.
- **Widerrufs-Politik:** Einmal freigeschaltet bleibt freigeschaltet, auch wenn
  Daten später gelöscht werden (Unlock ist ein historisches Ereignis).

## Kinds
- `.once` – einmalig.
- `.tiered([Schwellen])` – Stufen; jede erreichte Stufe ein eigener Unlock.
- `.repeatable` – wiederholbar; ein Unlock je auslösendem Ereignis
  (sessionID bzw. contextValue verhindert Doppelzählung).

## Katalog (23)

### A – Einstieg & Volumen
| id | kind | Kriterium |
|----|------|-----------|
| `first_session` | once | Erste Session aufgezeichnet |
| `sessions_count` | tiered [10,25,50,100] | Anzahl Sessions |
| `tops_count` | tiered [10,50,100,500] | Getoppte Begehungen gesamt |
| `ascents_count` | tiered [50,250,1000] | Begehungen gesamt (inkl. Versuche) |
| `first_outdoor` | once | Erste Outdoor-Session |

### B – Konsistenz
| id | kind | Kriterium |
|----|------|-----------|
| `week_streak` | tiered [4,8,12,24] | Wochen in Folge mit ≥1 Session |
| `active_month` | repeatable | ≥8 Klettertage in einem Kalendermonat |
| `four_in_week` | repeatable | ≥4 Sessions in einer Kalenderwoche |

### C – Grad-Meilensteine (pro Disziplin)
| id | kind | Kriterium |
|----|------|-----------|
| `boulder_pb` | repeatable | Neuer Boulder-Höchstgrad (contextValue = Grad) |
| `route_pb` | repeatable | Neuer Seil-Höchstgrad |
| `boulder_7a` | once | Erster Boulder ab Fb 7A (canonicalOrder) |
| `route_7a` | once | Erste Route ab French 7a |

### D – Stil & Können
| id | kind | Kriterium |
|----|------|-----------|
| `triple_flash` | repeatable | ≥3 Flashes in einer Session |
| `flash_session` | repeatable | ≥5 Tops in einer Session, Flash-Quote ≥50 % |
| `onsight_count` | tiered [1,10,25] | Onsight-Tops gesamt |

### E – Projekte
| id | kind | Kriterium |
|----|------|-----------|
| `project_sent` | repeatable | Projekt gesendet (über Relation) |
| `persistent` | repeatable | Projekt mit ≥10 Versuchen gesendet (Hartnäckig) |
| `projects_count` | tiered [1,5,10] | Anzahl gesendeter Projekte |

### F – Training
| id | kind | Kriterium |
|----|------|-----------|
| `training_count` | tiered [5,25,50] | Anzahl Trainings-Sessions |
| `climbing_hours` | tiered [10,50,100] | Aktive Kletterstunden gesamt |

### G – Kontext
| id | kind | Kriterium |
|----|------|-----------|
| `all_disciplines` | once | Je ≥1 Session Boulder, Vorstieg, Toprope, Autobelay |
| `year_50` | repeatable | Kalenderjahr mit ≥50 Sessions |
| `comeback` | once | Session nach ≥30 Tagen Pause |

## Persistenz
`AchievementUnlock` (SwiftData): `definitionID`, `tier?`, `unlockedAt`,
`contextValue?`, `sessionID?`, `seenByUser`. Idempotenz-Schlüssel:
- `.once` → definitionID
- `.tiered` → (definitionID, tier)
- `.repeatable` → (definitionID, sessionID) bzw. (definitionID, contextValue)

Unlock-Datum = Datum der auslösenden Session (Backfill: historisch korrekt).
