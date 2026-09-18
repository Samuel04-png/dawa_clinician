# AI Model And Gradio

The project has multiple AI paths. CaCx uses Hugging Face/Gradio-style image analysis for online second opinion, and ultrasound uses a Supabase Edge Function that can call Gemini.

## CaCx Active Online Path

The active CaCx online second opinion in `lib/application/cacx/cacx_widget.dart` uses:

```text
https://kmunzwa-medsiglip-demo.hf.space
```

Confirmed request flow:

1. Decode base64 image.
2. Upload the image to `/gradio_api/upload` as multipart form data.
3. Call `/gradio_api/call/predict`.
4. Read the returned `event_id`.
5. Poll `/gradio_api/call/predict/{event_id}`.
6. Parse the response into `AnalysisResult`.

## MedSigLip Notes

`lib/application/cacx/cacx_model.dart` contains documentation comments for a MedSigLip-style model:

- Backbone: `kmunzwa/medsiglip-diagnosis`
- Classes: Negative, CIN1, CIN2, CIN3, Positive
- Response style: plain text with a predicted class and probabilities

That same file also contains a `GradioService` pointing to another Hugging Face Space. I treat that as legacy or alternate service code unless it is wired from the active UI.

## Supabase VIA Edge Function

`supabase/functions/analyze-via-image/index.ts` is present. It expects:

- `HUGGINGFACE_API_TOKEN`
- `HUGGINGFACE_VIA_MODEL`
- `imageBase64` in the request body

It posts raw image bytes to Hugging Face Inference API. I did not confirm that the Flutter CaCx UI currently uses this Edge Function instead of the direct Gradio route.

## Ultrasound AI

The ultrasound module calls:

```dart
supabaseClient.functions.invoke(
  'analyze-ultrasound-image',
  body: {
    'imageBase64': base64Image,
    'gestationalAgeWeeks': gestationalAgeWeeks,
  },
);
```

The Edge Function:

- Validates base64 image input.
- Reads `GEMINI_API_KEY`.
- Uses `GEMINI_ULTRASOUND_MODEL`, `GEMINI_MODEL`, or a default model.
- Requests JSON-only structured findings.
- Returns a fallback clinician-review response if no Gemini key is configured.

## Result Interpretation

CaCx maps AI outputs into:

- Label.
- Confidence.
- Suspicion level.
- Recommendation.
- Raw output.
- Prediction breakdown.
- Optional error.

Ultrasound maps AI outputs into:

- Findings.
- Overall assessment.
- Overall level.
- Recommendation.
- Estimated gestational age.
- Measurements.

## Production Risks

- External Hugging Face Spaces can be unavailable, cold-started, changed, or rate-limited.
- Model outputs need clinical validation.
- Prompt and response parsing should be versioned.
- Online model calls should ideally go through an Edge Function for secret management, audit, and consistent error handling.
- The app should record model name/version with every AI interpretation.
