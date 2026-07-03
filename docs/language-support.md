# Language Support

Language support is currently focused on the CaCx recommendation section, not the full app.

## Confirmed Languages

`lib/application/cacx/cacx_widget.dart` includes a result recommendation language selector with:

- English
- Nyanja
- Bemba
- Tonga
- Shona
- Ndebele

## Where It Appears

The selector appears on the CaCx result recommendation card. When a non-English language is selected, the UI also shows the original English recommendation below the localized explanation.

## Current Implementation

The current implementation is hardcoded in Dart, not a full localization framework. The app itself declares:

```dart
supportedLocales: const [Locale('en', '')]
```

That means the broader Flutter app is still English-only from an i18n perspective.

## What Is Translated

The confirmed translated/alternate-language content is a summarized explanation of the current CaCx analysis result. It uses:

- Diagnosis.
- Risk level.
- Confidence.
- Recommendation context.

## Needs Review

- The translations should be checked by fluent speakers and clinical reviewers.
- The app should move to structured localization files if full multilingual support is required.
- Clinical terms should be standardized.
- Language selection should be persisted if users expect the app to remember it.
- Patient-facing text and clinician-facing text should be separated.

## How To Add A New Language

Short-term:

1. Add the language name to the selector list.
2. Add a case in the localized recommendation method.
3. Test long text on mobile widths.
4. Keep the original English text visible until translations are clinically approved.

Long-term:

1. Move translations into ARB or another structured localization format.
2. Add app-wide locale support.
3. Add testing for text overflow.
4. Add clinical review sign-off for each language.
