# Hablemos

A personal iOS app for practising spoken Spanish. You warm up on a scenario's key words and
sentences, then hold a spoken conversation with Lucía, an AI tutor. The app corrects your mistakes,
tracks your weak spots, and moves you up CEFR levels (A1–B2) as you improve.

Everything runs on the device: speech recognition uses Apple's `SpeechAnalyzer`, the tutor is a
Gemma 4 model running through LiteRT-LM, and Lucía's voice is `AVSpeechSynthesizer`. No audio or
text leaves the phone. The only network use is the one-time model download.

## Architecture

```mermaid
flowchart TB
  subgraph UI["SwiftUI app (Hablemos)"]
    Router["AppModel<br/>routes: home · modelSetup · warmup · conversation · summary"]
    Screens["Screens<br/>Home (Practice / Progress / Review tabs) · Warmup<br/>Conversation · Shadow · Summary · Settings · Model setup"]
    WVM["WarmupViewModel<br/>tap-to-talk drill, live word grading"]
    CVM["ConversationViewModel<br/>turns, corrections, session summary"]
  end

  subgraph Core["HablemosCore (Swift package, pure logic, unit-tested)"]
    Protocols["Protocols<br/>SpeechToText · LanguageModel · TextToSpeech"]
    Grading["PhraseMatcher<br/>word-by-word speech grading"]
    Tutor["PromptBuilder · ReplyParser<br/>SentenceChunker"]
    Learning["LevelsConfig · Warmup · Metrics<br/>PromotionRule · MistakeTally · SessionSummary"]
  end

  subgraph Adapters["Device adapters"]
    STT["SpeechAnalyzerSpeechToText<br/>AVAudioEngine → SpeechTranscriber<br/>(volatile + alternative results)"]
    LLM["LiteRTLanguageModel<br/>LiteRTLMKit → Gemma 4 E2B / E4B"]
    TTS["SpeechPlayer · AVSpeechTextToSpeech"]
  end

  subgraph Data["Persistence"]
    Store["ProgressStore<br/>sessions, turns, mistakes, vocab, streaks"]
    SD[("SwiftData")]
    Backup["ProgressBackup<br/>JSON export / import"]
  end

  Download["ModelDownloader<br/>one-time .litertlm download<br/>(Hugging Face, litert-community)"]

  Screens --> Router
  Screens --> WVM & CVM
  WVM --> Grading
  WVM --> Protocols
  CVM --> Protocols
  CVM --> Tutor
  CVM --> Learning
  Protocols -.implemented by.-> STT & LLM & TTS
  CVM --> Store
  Router --> Store
  Store --> SD
  Store --> Backup
  Download --> LLM
```

`HablemosCore` holds all the logic that doesn't touch a device API, behind the three protocols,
so it builds and tests on macOS. The app target plugs in the real speech, model and voice
adapters; tests plug in the mocks from `HablemosCore`.

### How a speaking drill is graded

The warm-up grades speech word by word, an approach borrowed from Duolingo's speak exercises:

```mermaid
sequenceDiagram
  participant You
  participant Drill as WarmupViewModel
  participant STT as SpeechAnalyzer (on device)
  participant PM as PhraseMatcher
  You->>Drill: tap mic
  Drill->>STT: startListening(es-MX)
  loop every partial transcript (+ alternatives)
    STT-->>Drill: TranscriptUpdate
    Drill->>PM: progress(heard, target, previous)
    PM-->>Drill: words recognised so far
    Drill-->>You: matched words turn mint
  end
  alt every word heard
    Drill->>STT: stop, mark correct
  else silence for max(5 s × (1 − progress), 1 s)
    Drill->>STT: stop, show missed words
  end
```

A word counts when it matches exactly once case, punctuation and accents are removed. So "esta" is
accepted for "está", but "quiere" is not accepted for "quiero".

## Project layout

| Path | What's there |
|---|---|
| `Hablemos/` | The SwiftUI app: screens, view models, speech, LLM and persistence adapters |
| `HablemosCore/` | Swift package with the pure logic and its unit tests |
| `HablemosTests/` | App-level tests (view models, persistence, model setup) |
| `LiteRTLMKit/` | Vendored Swift wrapper for Google's LiteRT-LM (Apache 2.0) |

## Requirements

- Xcode 26, iOS 26 (needed for `SpeechAnalyzer`)
- About 2.6 GB (E2B) or 3.7 GB (E4B) of free space for the downloaded model

## Running tests

```sh
cd HablemosCore && swift test   # core logic, runs on macOS
```

The app tests in `HablemosTests` need an iOS simulator. Run them from Xcode with the `Hablemos`
scheme.
