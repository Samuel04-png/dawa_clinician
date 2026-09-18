# Screenshots And Visuals

I found app visual assets in the repository, but I did not find real captured UI screenshots already committed. I copied only confirmed local assets into this GitBook folder and added diagram coverage with Mermaid.

## Confirmed Visual Assets

![Dawa Health logo](assets/screenshots/dawa-health-logo.png)

Caption: Existing Dawa Health logo asset copied from `assets/images/Logos-06.png`.

![Clinician team asset](assets/screenshots/clinician-team-asset.png)

Caption: Existing clinician illustration copied from `assets/images/doctor_graphic.png`.

## Screenshot Capture TODO

Real screenshots still need to be captured for:

- Login screen.
- Home/dashboard.
- Patient list.
- Patient details.
- Add screening flow.
- CaCx image source modal.
- CaCx analysis progress.
- CaCx results page.
- Clinical recommendations card.
- Screening history detail modal.
- Offline banner.
- Device unavailable state.
- Ultrasound dashboard.
- BP Monitor interpretation screen.

## App Architecture Diagram

```mermaid
flowchart TD
  A["Flutter App"] --> B["Auth Manager"]
  B --> C["Supabase Auth"]
  A --> D["Supabase Firestore Compatibility"]
  D --> E["Supabase Tables"]
  A --> F["Care Tools"]
  F --> G["CaCx"]
  F --> H["Ultrasound"]
  F --> I["BP Monitor"]
  G --> J["Device API"]
  G --> K["Gradio Second Opinion"]
  G --> L["cacx_screening_results"]
```

## Firebase To Supabase Migration Flow

```mermaid
flowchart LR
  A["Firebase Auth Export"] --> B["Migration SQL/Tools"]
  C["Firestore Collections"] --> B
  B --> D["Supabase Auth"]
  B --> E["Supabase Tables"]
  E --> F["FlutterFlow Record Models"]
  F --> G["Supabase Compatibility Layer"]
```

## CaCx Flow

```mermaid
flowchart TD
  A["Select Patient"] --> B["Choose Camera or Gallery"]
  B --> C["Check Connectivity"]
  C -->|Offline| D["Check Device"]
  C -->|Online| E["Send To Device"]
  D -->|Connected| E
  D -->|Not Connected| F["Show Device Required Message"]
  E --> G["Parse Device Result"]
  G --> H["Save Or Queue Primary Result"]
  H --> I{"Second Opinion Needed?"}
  I -->|No| J["Show Results"]
  I -->|Yes And Online| K["Run Online Scan"]
  K --> L["Update Second Opinion"]
  L --> J
```

## Offline Mode Flow

```mermaid
flowchart TD
  A["App Starts"] --> B["Read Supabase Session"]
  B -->|Live Session| C["Cache User"]
  B -->|No Live Session| D["Read Cached User"]
  D --> E["Allow Cached Navigation Where Possible"]
  E --> F["Use Cached Rows"]
  E --> G["CaCx Offline Device Only"]
  G --> H["Queue Result For Sync"]
```

## Arduino / Device Connection Flow

```mermaid
sequenceDiagram
  participant App as Dawa Clinician
  participant Device as Pi/Arduino API
  participant DB as Supabase
  App->>Device: GET /health
  Device-->>App: 2xx ready
  App->>Device: POST /upload/cervical multipart image
  Device-->>App: JSON label/confidence/risk
  App->>DB: Insert cacx_screening_results
  DB-->>App: record id
```
