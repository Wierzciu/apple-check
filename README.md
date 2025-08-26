# Apple Check

Monitoruje najnowsze wydania systemów Apple (iOS, iPadOS, macOS, watchOS, tvOS) oraz Xcode. Działa lokalnie w aplikacji i przez GitHub Actions, aby wykrywać nowości nawet bez uruchamiania aplikacji.

## Wymagania

- Xcode 15+ (iOS 17+)
- Swift 5.9+
- macOS 14+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) do wygenerowania projektu Xcode z `project.yml` (opcjonalnie można stworzyć projekt ręcznie)

## Szybki start

1. Zainstaluj XcodeGen (jeśli nie masz):

```bash
brew install xcodegen
```

2. Wygeneruj projekt Xcode:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "apple check"
xcodegen generate
open AppleCheck.xcodeproj
```

3. Ustaw schemat `AppleCheck` i uruchom na iOS 17+.

## Co jest w repo

- `project.yml` – definicja projektu XcodeGen
- `AppleCheck/` – kod aplikacji SwiftUI (MVVM, Core Data-in-code, BGTaskScheduler, powiadomienia)
- `scripts/check_updates.py` – skrypt detekcji dla GitHub Actions
- `scripts/sources.yaml` – definicje źródeł OTA/WWW/RSS
- `.github/workflows/check_updates.yml` – workflow uruchamiany co 5 min

## Funkcje

- Pobieranie danych z OTA (MESU/SoftwareUpdate) i WWW (Apple Developer News Releases HTML + RSS, Apple Support About updates, Apple Newsroom)
- Autodiscovery kanałów i „majorów” (dynamiczne rozwijanie źródeł)
- Scalanie danych z priorytetem: OTA > WWW
- Stany: `device_first`, `announce_first`, `confirmed`
- Tryb re-check co minutę przez 30 minut dla stanów przejściowych
- Historia w Core Data (model programowy, bez .xcdatamodeld)
- BGTaskScheduler do tła, UNUserNotificationCenter do powiadomień lokalnych
- Logi do konsoli i pliku

## Instrukcje w kodzie

W plikach znajdują się komentarze po polsku (szukaj sekcji "Instrukcja:"):

1. Jak dodać nowy katalog OTA/URL WWW: `AppleCheck/Services/Sources.swift`
2. Jak zmienić częstotliwość odświeżania: `AppleCheck/Views/SettingsView.swift` i `AppleCheck/ViewModels/SettingsViewModel.swift`
3. Jak włączyć/wyłączyć kanały: `AppleCheck/Views/SettingsView.swift` i `AppleCheck/Models/Channel.swift`

## Sekrety dla GitHub Actions

- Jeśli chcesz wysyłać webhook po wykryciu nowej wersji, ustaw sekrety repo:
  - `WEBHOOK_URL` – endpoint do POST JSON
  - `WEBHOOK_TOKEN` – opcjonalnie token do autoryzacji (trafia w nagłówku `Authorization: Bearer <token>`)

## Notatki dot. źródeł

- OTA: wykorzystujemy publiczne katalogi MESU (iOS/iPadOS/watchOS/tvOS) i SoftwareUpdate (macOS). Implementacja obsługuje ETag/If-Modified-Since.
- WWW: parsujemy RSS (`https://developer.apple.com/news/releases/rss/releases.rss`), HTML (`https://developer.apple.com/news/releases/`) i strony wsparcia Apple.

## Licencja

MIT


