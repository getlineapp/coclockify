# Cocotrack — raport z audytu

**Data:** 2026-07-23
**Zakres:** całe repo `~/Programowanie/cocotrack` (`main` @ `5886e1a`)
**Gałąź z poprawkami:** `feature/audit-fixes`
**Metoda:** rozpoznanie kodu → baseline bramek jakości → audyt funkcjonalny / architektury / danych / security / prywatności / wydajności / dostępności / UX → naprawa → weryfikacja

Ten dokument zawiera **wyłącznie fakty** i status ich potwierdzenia. Wnioski, oceny i propozycje produktowe są w `UX_RECOMMENDATIONS.md`. Wykaz zmian jest w `CHANGELOG_AGENT.md`.

Każdy punkt ma jawny **status potwierdzenia**:

| Status | Znaczenie |
|---|---|
| **POTWIERDZONY** | Zreprodukowany narzędziem — output, probe, test lub odpowiedź API w dokumencie |
| **POTWIERDZONY (statycznie)** | Wynika jednoznacznie z odczytu kodu, bez uruchomienia |
| **WYMAGA TESTU MANUALNEGO** | Mechanizm zidentyfikowany, ale weryfikacja wymaga środowiska, którego nie miałem |
| **OBSERWACJA JAKOŚCIOWA** | Ocena, nie pomiar |

---

## 1. Streszczenie stanu

Cocotrack to jednomodułowa aplikacja macOS (Swift 6.2 / SwiftUI, SwiftPM, zero zależności zewnętrznych), ~2 700 linii Swift w 14 plikach. Klient REST do Clockify API v1, z oknem głównym i ikoną w pasku menu.

Baseline był **zielony**: `swift build`, `swift build -c release` i `swift test` (17 testów) przechodziły bez błędów i bez ostrzeżeń przed jakąkolwiek zmianą. Zielony build nie wykrył żadnego z dwóch najpoważniejszych problemów opisanych niżej — oba dotyczą trwałości danych i oba są niewidoczne dla kompilatora.

Znaleziono **2 problemy P0/P1 klasy utraty danych**, oba zreprodukowane narzędziami, oba naprawione i zweryfikowane. Poza tym: brak jakiejkolwiek warstwy dostępności (0 modyfikatorów `accessibility*` w całym kodzie), 5 par kolorów poniżej progu kontrastu WCAG AA, polska lokalizacja pozbawiona polskich znaków diakrytycznych oraz kilka defektów w skryptach dystrybucyjnych.

---

## 2. Mapa architektury

### Główne komponenty

| Plik | Rola | Linie |
|---|---|---|
| `CocotrackApp.swift` | Punkt wejścia; `WindowGroup` + `MenuBarExtra` | 33 |
| `AppState.swift` | `@MainActor ObservableObject` — cały stan, wywołania API, ustawienia | 684 |
| `ClockifyAPIClient.swift` | Bezstanowy klient REST na `URLSession` | 277 |
| `ClockifyModels.swift` | Typy `Codable` żądań/odpowiedzi | 103 |
| `APIKeyStore.swift` | Przechowywanie klucza API w Keychain | 70 |
| `ContentView.swift` | Okno główne + `SettingsSheet` + `EntryEditSheet` + `CreateProjectSheet` | 808 |
| `MenuBarView.swift` | Popover w pasku menu | 149 |
| `RecentTimeLogView.swift` | Lista ostatnich wpisów pogrupowana dniami | 154 |
| `DesignSystem.swift` | Paleta, typografia, style kontrolek | 344 |
| `Formatters.swift` | Kodowanie ISO 8601, formatowanie czasu, parsowanie kolorów | 104 |
| `L10n.swift` | Stałe łańcuchów lokalizowanych | 149 |
| `Bundle+Localized.swift` | Rozwiązywanie bundle'a zasobów dla `swift run` i `.app` | 22 |

### Przepływ danych

```
Keychain ──► AppState.apiKey ──┐
UserDefaults ──► baseURL, workspaceOverride, favorites
                               │
                               ▼
                    ClockifyAPIClient (X-Api-Key)
                               │
                    api.clockify.me/api/v1
                               │
                               ▼
             AppState.recentEntries / runningEntry / projects
                               │
                    recomputeDerived() (didSet)
                               │
                    quickStartItems, recentEntryGroups
                               │
                  ContentView ──┴── MenuBarView (@EnvironmentObject)
```

### Punkty integracji i przechowywania danych

- **Jedyne zewnętrzne API:** Clockify REST v1. Brak analityki, brak error-reportingu, brak telemetrii — potwierdzone `grep`em po całym drzewie źródeł.
- **Keychain** (`com.cocolab.cocotrack` / `clockify.apiKey`) — klucz API.
- **UserDefaults** — `baseURL`, `baseURL.confirmed`, `workspaceOverride`, `favoriteDescriptions`.
- **Brak lokalnej bazy danych, brak cache'u na dysku, brak migracji schematu.**

### Główne ścieżki użytkownika

1. Pierwsze uruchomienie → Ustawienia → wklejenie klucza API → „Zapisz i połącz"
2. Start timera (okno główne, popover, albo szybki start z historii)
3. Stop timera
4. Edycja istniejącego wpisu (opis, czas, projekt)
5. Zmiana projektu trwającego wpisu
6. Utworzenie projektu
7. Przypięcie/odpięcie ulubionego opisu

### Obszary największego ryzyka (przed audytem)

1. Trwałość poświadczeń — jedyny sekret aplikacji, jeden punkt zapisu, zero obsługi błędów
2. Semantyka `PUT` na wpisach czasu — modyfikacja cudzych danych przez pełne nadpisanie
3. Zerowa warstwa dostępności przy dystrybucji przez Mac App Store
4. Rozjazd między dwoma pipeline'ami buildu (direct vs MAS)

---

## 3. Stan bazowy — przed zmianami

Wszystkie polecenia uruchomione na `main` @ `5886e1a`, przed jakąkolwiek modyfikacją.

| Polecenie | Wynik | Uwagi |
|---|---|---|
| `swift build` | **PASS** (exit 0, 5.41 s) | Zero ostrzeżeń |
| `swift build -c release` | **PASS** | Zero ostrzeżeń |
| `swift test` | **PASS** — 17 testów, 0 błędów | Jeden plik: `ForceProjectsTests.swift` |
| `bash -n scripts/*.sh` | **PASS** | Składnia poprawna |
| `git status` | czysty working tree | Nieśledzone: `Plans/`, `audit/` — nietknięte |

### Bramki niedostępne w tym środowisku

| Bramka | Powód |
|---|---|
| SwiftLint / SwiftFormat | Brak konfiguracji w repo i brak narzędzia w systemie |
| Analiza zależności (audit/outdated) | Projekt nie ma **żadnych** zależności zewnętrznych — `Package.swift` deklaruje wyłącznie własne targety |
| CI | Brak `.github/workflows` ani innej konfiguracji CI w repo |
| Pełny build dystrybucyjny podpisany | Brak certyfikatu Developer ID i profilu provisioningu |
| Interceptor / weryfikacja web | **Nie dotyczy** — to natywna aplikacja macOS, nie ma UI webowego |

### Weryfikacja wizualna

Aplikacja uruchomiona (`swift run`), okno przechwycone zrzutem ekranu, stan: połączony, dane realne załadowane z workspace'u. Użyta do potwierdzenia braku regresji wizualnej po zmianach w palecie i strukturze widoków.

---

## 4. Problemy — P0

### P0-1 · Utrata klucza API przy każdym uruchomieniu — **POTWIERDZONY**

**Lokalizacja:** `Sources/cocotrack/APIKeyStore.swift:16-18,37-39` (przed poprawką) · `Sources/cocotrack/AppState.swift:82-85,588-599` (przed poprawką)

**Objaw zgłoszony przez użytkownika w trakcie audytu:** „appka zapomina mojego klucza api, jestem co chwila wylogowany".

**Reprodukcja i dowody:**

1. Stan zainstalowanej aplikacji:
   ```
   $ codesign -dvvv /Applications/Cocotrack.app
   Identifier=com.cocolab.cocotrack
   CodeDirectory v=20400 flags=0x2(adhoc)
   Signature=adhoc
   TeamIdentifier=not set
   ```
   Aplikacja jest podpisana ad-hoc i **nie ma żadnych entitlementów**.

2. Zawartość Keychaina przed naprawą:
   ```
   $ security find-generic-password -s com.cocolab.cocotrack
   security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.
   ```

3. Zawartość UserDefaults:
   ```
   $ defaults read com.cocolab.cocotrack
   { "clockify.baseURL" = "..."; "clockify.workspaceOverride" = ""; ... }
   ```
   Brak `clockify.apiKey` — kopia zapasowa również nie istnieje.

4. Sonda odtwarzająca dokładne wywołanie z `APIKeyStore`, skompilowana i podpisana ad-hoc (te same warunki co zainstalowana aplikacja):
   ```
   dataProtectionKeychain=true  -> OSStatus -34018 (A required entitlement isn't present.)
   dataProtectionKeychain=false -> OSStatus 0 (No error.)
   ```

**Przyczyna źródłowa:** `APIKeyStore` bezwarunkowo ustawiał `kSecUseDataProtectionKeychain = true`. Ten backend Keychaina wymaga entitlementu `keychain-access-group` pochodzącego z podpisu kodu. Build ad-hoc — czyli dokładnie to, co produkuje `scripts/build_direct_distribution.sh` bez `SIGN_IDENTITY` — nie ma takiego entitlementu, więc **każdy** zapis kończył się `errSecMissingEntitlement` (-34018).

Ten błąd był ignorowany w dwóch miejscach:

- `AppState.persistSettings()` wywoływało `APIKeyStore.save(trimmedKey)` z odrzuconą wartością zwracaną, po czym ustawiało `statusMessage = L10n.connectedAs(...)`. Aplikacja raportowała sukces połączenia mimo niezapisanego klucza.
- `AppState.init()` przy migracji ze starego formatu robiło `APIKeyStore.save(legacyKey)` a następnie **bezwarunkowo** `defaults.removeObject(forKey: Keys.apiKey)` — kasowało jedyną istniejącą kopię poświadczenia bez potwierdzenia, że zapis się powiódł.

Efekt złożony: klucz nie trafiał nigdzie, kopia zapasowa była niszczona, a przy następnym starcie aplikacja wstawała nieskonfigurowana.

**Zakres:** deterministyczny dla każdego builda ad-hoc oraz każdego builda Developer ID bez jawnych entitlementów. Build MAS (sandbox + `com.apple.application-identifier`) ma entitlement, więc go nie dotyczy.

**Poprawka:** `APIKeyStore` próbuje najpierw keychaina data-protection (poprawnego dla builda MAS), a przy jego niedostępności schodzi do klasycznego keychaina logowania. Migracja starej kopii plaintext usuwa ją dopiero po **potwierdzonym** zapisie. Nieudany zapis jest teraz zgłaszany jako błąd (`ClockifyAPIError.keychainUnavailable`) i wyświetlany w Ustawieniach zamiast raportowania sukcesu.

**Weryfikacja:** sonda podpisana ad-hoc, zapis i odczyt w **osobnych procesach**:
```
save -> true
load (new process) -> SECRET-KEY-123
landed in: /Users/…/Library/Keychains/login.keychain-db
delete -> true
load after delete -> <nil>
```
Testy regresyjne (`APIKeyStoreTests`, `APIKeyMigrationTests`) sprawdzone kontrolnie: **failują** przy przywróceniu starego zachowania, przechodzą po poprawce.

**Ryzyko regresji:** klasyczny keychain wiąże ACL z konkretnym podpisem binarki. Przy buildzie ad-hoc każda przebudowa zmienia cdhash, więc macOS może pokazać monit „Cocotrack chce uzyskać dostęp do pęku kluczy". Patrz P1-2 — właściwym rozwiązaniem docelowym jest stabilny podpis Developer ID.

---

## 5. Problemy — P1

### P1-1 · Edycja wpisu kasuje jego tagi i przypisanie do taska — **POTWIERDZONY**

**Lokalizacja:** `Sources/cocotrack/ClockifyModels.swift:42-47` (przed poprawką) · `Sources/cocotrack/AppState.swift:406-434,436-462` (przed poprawką)

**Przyczyna źródłowa:** `PUT /workspaces/{ws}/time-entries/{id}` w Clockify ma semantykę **pełnego zastąpienia** — każde pole nieobecne w ciele żądania jest resetowane po stronie serwera. `ClockifyUpdateTimeEntryRequest` zawierało wyłącznie `start`, `description`, `end` i `projectId`. Pola `tagIds`, `taskId` i `customFields` nie były nawet dekodowane z odpowiedzi, więc nie było czym ich odesłać.

**Reprodukcja na żywym API** (wpis testowy utworzony i skasowany, zgoda uzyskana przed testem):

```
BEFORE: billable=True  tagIds=['65adf014218f7574f3bef77e']  projectId=6620…

# dokładny payload, który aplikacja wysyłała przy samej zmianie opisu:
PUT {"start":"…","description":"renamed in Cocotrack","end":"…","projectId":"6620…"}

AFTER (GET, stan utrwalony):
  billable = True
  tagIds   = None        ← tagi zniszczone
  taskId   = None
```

Sprawdzone `GET`-em po `PUT`, a nie tylko na echu odpowiedzi — stan jest utrwalony na serwerze.

**Dodatkowo potwierdzone w tej samej sesji:** pominięcie `projectId` **kasuje** projekt, a pominięcie `end` **otwiera zakończony wpis z powrotem jako trwający**:
```
BEFORE: projectId=6620…  end=2026-07-20T05:01:00Z
PUT {"start":"…","description":"…"}          ← bez projectId i end
AFTER : projectId=None   end=None
```
To zachowanie działa na korzyść aplikacji w dwóch miejscach (czyszczenie projektu i utrzymanie trwającego wpisu przy życiu są realizowane właśnie przez pominięcie pola), ale oznacza, że **każde** pominięte pole jest destrukcyjne.

**Wpływ:** każde wywołanie „Edytuj wpis" i każda zmiana projektu z poziomu Cocotrack niszczyła tagi i taska wpisu w Clockify. Dla narzędzia rozliczeniowego tagi zwykle niosą informację potrzebną do fakturowania.

**Poprawka:** `ClockifyTimeEntry` dekoduje teraz `tagIds`. `ClockifyUpdateTimeEntryRequest` dostał inicjalizator `preserving:`, który przenosi `taskId`, `billable` i `tagIds` z modyfikowanego wpisu. Oba miejsca wywołania najpierw lokalizują wpis w lokalnym cache'u i **rzucają błąd, jeśli go nie ma** — zamiast wysyłać ślepy `PUT`, który wyzeruje pola.

**Weryfikacja na żywym API po poprawce:**
```
BEFORE: tagIds=['65adf014218f7574f3bef77e']  billable=True
PUT (payload z poprawki, zmiana samego opisu)
AFTER : tagIds=['65adf014218f7574f3bef77e']  billable=True  desc='renamed with fix'
```
Plus 5 testów regresyjnych na kształt payloadu (rename, zmiana projektu, czyszczenie projektu, wpis trwający, wpis bez tagów).

**Sprzątanie:** wszystkie trzy wpisy testowe usunięte (`HTTP 204`), weryfikacja `leftover audit entries: 0`.

**Nadal nieprzeniesione:** `customFields`. Aplikacja ich nie dekoduje, więc nadal będą resetowane przy edycji — dotyczy tylko workspace'ów na planie, który je udostępnia. Patrz „Ograniczenia".

---

### P1-2 · Dystrybucja bezpośrednia jest podpisana ad-hoc — **POTWIERDZONY**

**Lokalizacja:** `scripts/build_direct_distribution.sh:29-34` · zainstalowana `/Applications/Cocotrack.app`

**Fakty:**
- Zainstalowana aplikacja: `flags=0x2(adhoc)`, `Signature=adhoc`, `TeamIdentifier=not set`, zero entitlementów.
- Skrypt dopuszcza to jawnie przez `ALLOW_ADHOC=1` i sam ostrzega w komentarzu: „Ad-hoc signed bundles are blocked by Gatekeeper on first run and must never be published".
- W `dist/` leży 14 artefaktów (`.zip`/`.dmg`) od wersji 1.2.0 do 2.3.1. Katalog jest w `.gitignore` i nie jest śledzony w gitcie, więc **nie da się z repo stwierdzić**, czy publikowane były buildy podpisane, czy ad-hoc.

**Konsekwencje potwierdzone:** ad-hoc jest bezpośrednią przyczyną P0-1. Poza tym Gatekeeper blokuje pierwsze uruchomienie u odbiorcy.

**Nie naprawione** — wymaga certyfikatu Developer ID, którego nie mam. Skrypt już teraz wymusza jawny `ALLOW_ADHOC=1`, więc mechanizm zabezpieczający istnieje.

**Zalecenie:** publikować wyłącznie z `SIGN_IDENTITY` (Developer ID Application) i `NOTARIZE_PROFILE`. Stabilny podpis rozwiązuje przy okazji problem monitów Keychaina po każdej aktualizacji.

---

### P1-3 · Brak jakiejkolwiek warstwy dostępności — **POTWIERDZONY (statycznie)**

**Dowód:**
```
$ grep -rc "accessibility" Sources/
0
```
Zero modyfikatorów `accessibility*` w całym drzewie źródeł przed audytem.

**Konkretne konsekwencje, każda zweryfikowana odczytem kodu:**

| Element | Lokalizacja (przed) | Problem |
|---|---|---|
| Edycja wpisu z listy | `RecentTimeLogView.swift:142` | `.onTapGesture` na `HStack` — niedostępne z klawiatury, niewidoczne dla VoiceOver. Jedyna alternatywa to menu kontekstowe, czyli też mysz |
| Edycja trwającego wpisu | `ContentView.swift:204` | jw. — `.onTapGesture` na `ElapsedText` |
| Przycisk odświeżania | `ContentView.swift:100`, `MenuBarView.swift:23` | Sam `Image(systemName:)`, bez etykiety |
| Przycisk ustawień | `ContentView.swift:109` | jw. |
| Przycisk „nowy projekt" | `ContentView.swift:261` | jw. |
| Gwiazdka ulubionych | `ContentView.swift:369` | jw. — stan komunikowany wyłącznie kształtem ikony |
| Próbki kolorów | `ContentView.swift:790` | Zaznaczenie sygnalizowane samą obwódką, bez nazwy i bez cechy `isSelected` |
| Kropka statusu połączenia | `DesignSystem.swift:150` | Stan komunikowany **wyłącznie kolorem** |
| Pola tekstowe | `DesignSystem.swift:322` | `@FocusState private var focused` zadeklarowany, ale **nigdy niepodpięty**; `.textFieldStyle(.plain)` usuwa natywny pierścień fokusu — brak wskaźnika fokusu klawiatury |
| `LiveDot` | `DesignSystem.swift:144` | `repeatForever` bez sprawdzenia `accessibilityReduceMotion` |

Narusza to wprost zasadę audytu: żadna funkcja nie może być dostępna wyłącznie przez gest, kolor ani hover. Edycja wpisu — jedna z głównych ścieżek — była dostępna wyłącznie myszą.

**Poprawka:** obie ścieżki tap-only zamienione na `Button` ze stylem `.plain` (identyczny wygląd, pełna dostępność z klawiatury i dla VoiceOver); etykiety `accessibilityLabel` + `.help` na wszystkich kontrolkach ikonowych; `StatusDot` eksponuje stan tekstem; `ElapsedText` czytany jako jeden element zamiast pięciu; `LiveDot` respektuje Reduce Motion; `@FocusState` podpięty i sterujący widocznym pierścieniem fokusu.

**Nie zweryfikowane:** faktyczne zachowanie VoiceOver i nawigacji Tab — **wymaga testu manualnego**, patrz checklista QA.

---

### P1-4 · Nieudany zapis nie daje żadnej informacji w arkuszach — **POTWIERDZONY (statycznie)**

**Lokalizacja:** `ContentView.swift:683-695` (EntryEditSheet) · `ContentView.swift:758-770` (CreateProjectSheet), przed poprawką

Obie funkcje zapisu zwracają `Bool`. Przy `false` arkusz po prostu **nie zamykał się i nie pokazywał niczego**. Powód niepowodzenia trafiał do `appState.statusMessage`, renderowanego w pasku statusu okna głównego — **zasłoniętym przez ten arkusz**. Użytkownik klikał „Zapisz" i nie dostawał żadnego sygnału.

Dodatkowo `AppState.runLoadingTask` przy `isLoading == true` wychodzi wcześniej i ustawia tylko `statusMessage` — czyli równoległa operacja daje dokładnie ten sam cichy brak reakcji.

**Poprawka:** oba arkusze mają teraz inline'owy komunikat błędu wyświetlany przy nieudanym zapisie.

---

## 6. Problemy — P2

### P2-1 · Pięć par kolorów poniżej progu kontrastu WCAG AA — **POTWIERDZONY**

Zmierzone algorytmem kontrastu WCAG 2.x na wartościach z `DesignSystem.swift`:

| Para | Przed | Po | Próg |
|---|---|---|---|
| `ink4` na tle (jasny) | **1.92** | 3.05 | 3.0 (dekoracyjne) |
| `ink4` na tle (ciemny) | **2.60** | 3.73 | 3.0 |
| `warn` na tle (jasny) | **2.48** | 5.11 | 4.5 |
| `ok` na tle (jasny) | **2.75** | 5.23 | 4.5 |
| biały na `accent` (ciemny) | **2.41** | 6.24 | 4.5 |
| `ink3` na tle (jasny) | **3.31** | 4.89 | 4.5 |
| `ink3` na karcie (jasny) | **3.22** | 4.76 | 4.5 |
| `bad` na tle (oba) | **4.30** | 5.44 / 5.47 | 4.5 |

`warn` w trybie jasnym niósł komunikat „Projekt wymagany" — czyli **ostrzeżenie blokujące start timera było praktycznie nieczytelne**. `ink3` to kolor większości tekstu drugorzędnego w aplikacji (10,5–12,5 pt), więc było to najszerzej odczuwalne.

**Poprawka:** przesunięta wyłącznie jasność, odcienie zachowane. Dodany `Palette.onAccent` — biel w trybie jasnym, ciemny atrament w ciemnym.

**Świadomie niezmienione:** biel na `accent` w trybie jasnym pozostaje na 3.14. Kolor `#D27B4D` jest udokumentowany w `CLAUDE.md` jako kolor marki; doprowadzenie do 4.5 wymagałoby zmiany terakoty na `#B65E30`, co jest decyzją produktową, nie techniczną. Ujęte jako rekomendacja B-1.

**Weryfikacja:** wartości przeliczone po zmianie; wygląd potwierdzony zrzutem ekranu działającej aplikacji — komunikat „Project required" jest teraz czytelny.

---

### P2-2 · Polska lokalizacja bez polskich znaków — **POTWIERDZONY**

```
$ grep -c '[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]' Sources/cocotrack/Resources/pl.lproj/Localizable.strings
1
$ grep -c '^"' Sources/cocotrack/Resources/pl.lproj/Localizable.strings
81
```

**1 linia na 81** zawierała jakikolwiek znak diakrytyczny — i był to `about.disclaimer`, dodany jako ostatni. Reszta: „Polaczono", „Dzis", „zeby glowny ekran byl", „zakonczenia", „Przywroc domyslny", „Utworz", „Wyjdz".

`Package.swift` deklaruje `defaultLocalization: "pl"`, a `CLAUDE.md` mówi, że polski jest językiem domyślnym UI. Aplikacja jest przygotowywana do publikacji w Mac App Store z polskim jako dodatkowym językiem.

Dodatkowo 4 klucze były w pliku polskim nieprzetłumaczone: `status.autoRefresh` („Auto refresh: 30s"), `settings.userLabel` („User: %@"), `api.error.unknown` („Unknown API error"), `api.error.http`.

**Poprawka:** cały plik przepisany z poprawną polszczyzną, 4 brakujące tłumaczenia uzupełnione. Parytet kluczy pl/en zachowany (weryfikacja skryptem porównującym zbiory kluczy).

---

### P2-3 · Zakresy godzin mogły renderować się w formacie 12-godzinnym — **POTWIERDZONY (statycznie)**

**Lokalizacja:** `Formatters.swift:91-95` (przed poprawką)

```swift
let f = DateFormatter()
f.dateFormat = "HH:mm"     // brak f.locale
```

`DateFormatter` ze sztywnym `dateFormat` i bez ustawionego `locale` przepisuje wzorzec zgodnie z ustawieniami regionalnymi użytkownika. Przy wyłączonym „24-godzinnym formacie czasu" `HH` zostaje przekształcone we wzorzec 12-godzinny — a `dateFormat` nie zawiera `a`, więc znacznik AM/PM nie jest dodawany. Zakres 14:15–15:40 wyświetlałby się jako „2:15 – 3:40", nierozróżnialnie od 02:15–03:40.

**Poprawka:** `locale = Locale(identifier: "en_US_POSIX")`, co czyni `HH:mm` deterministycznym. Test regresyjny sprawdza brak „AM"/„PM" i zgodność ze wzorcem `^\d{2}:\d{2} – \d{2}:\d{2}$`.

**Powiązane, naprawione przy okazji:** `AppState.dayLabelFormatter` używał sztywnego `"EEE, d MMM"`, narzucając angielską kolejność pól każdej lokalizacji. Zamienione na `setLocalizedDateFormatFromTemplate("EEEdMMM")`.

---

### P2-4 · Defekty w skryptach dystrybucyjnych — **POTWIERDZONY (statycznie)**

| # | Lokalizacja | Fakt |
|---|---|---|
| a | `build_direct_distribution.sh:51`, `build_mas.sh:63` | Ścieżka do binarki zaszyta jako `arm64-apple-macosx` — skrypt kończy się błędem na hoście Intel i po cichu produkuje artefakt wyłącznie dla Apple Silicon |
| b | `build_direct_distribution.sh:137` | `codesign … "$DMG_PATH" \|\| true` — nieudane podpisanie DMG dawało zielony build i niepodpisany artefakt |
| c | `build_direct_distribution.sh:116,119` | `codesign --deep` użyte **do podpisywania**; Apple dokumentuje `--deep` jako nieodpowiednie do podpisywania. Pipeline MAS podpisuje ten sam kształt bundle'a bez `--deep` |
| d | `build_direct_distribution.sh:81-112` | Brak `NSHumanReadableCopyright` i `LSApplicationCategoryType`, obecnych w wariancie MAS |
| e | `build_mas.sh:96-131` | Brak `ITSAppUsesNonExemptEncryption` — każde wysłanie do App Store Connect wywołuje ręczne pytanie o zgodność eksportową |
| f | `build_direct_distribution.sh:11` | `VERSION="2.3.1"` zaszyte na sztywno, podczas gdy `build_mas.sh` używa `${VERSION:-2.3.1}` |

**Naprawione:** a, b, c, d, e. **Nie naprawione:** f — kosmetyczna niespójność, zmiana wpłynęłaby na sposób wywoływania skryptu.

**Weryfikacja:** `bash -n` na obu skryptach przechodzi. Pełny przebieg skryptów **nie był uruchamiany** — wymaga certyfikatów, których nie mam.

---

### P2-5 · „Edytuj ostatni wpis" mogło nic nie robić bez informacji — **POTWIERDZONY (statycznie)**

**Lokalizacja:** `ContentView.swift:304-310` (przed poprawką)

Pozycja menu kontekstowego szukała wpisu o opisie dokładnie równym opisowi ulubionego. Ulubiony może przeżyć wszystkie wpisy, które go zrodziły (lista pobiera 50 ostatnich), albo zostać przypięty zanim jakikolwiek powstanie. W takim przypadku `editingEntry` pozostawał `nil` i **nie działo się nic** — bez komunikatu.

**Poprawka:** ustawienie komunikatu w pasku statusu, gdy nie ma dopasowanego wpisu.

---

## 7. Problemy — P3

| # | Lokalizacja | Fakt | Status | Naprawione |
|---|---|---|---|---|
| P3-1 | `ClockifyAPIClient.swift:196-204` | `bulkEditTimeEntries` nie jest wywoływane z żadnego miejsca — martwy kod | POTWIERDZONY (statycznie) | Nie — nieszkodliwe, może być planowane |
| P3-2 | `ContentView.swift:9-10` vs `AppState.swift:55-56` | Okno główne używa lokalnego `@State customDescription`/`selectedProjectId`, popover używa `appState.timerDraftDescription`/`timerDraftProjectId`. Tekst wpisany w oknie nie pojawia się w popoverze; `startTimer(using:)` nadpisuje draft popovera | POTWIERDZONY (statycznie) | Nie — wymaga decyzji, które źródło jest kanoniczne |
| P3-3 | `AppState.swift:294` | `forceProjects = (try? await workspaceInfo)?…  ?? false` — nieudany odczyt ustawień workspace'u cicho daje `false`, więc walidacja „projekt wymagany" znika, a błąd wyjdzie dopiero przy stopie | POTWIERDZONY (statycznie) | Nie — zmiana wymagałaby decyzji, czy blokować połączenie |
| P3-4 | `ContentView.swift:57` | `editingEntry` przechowuje migawkę wpisu; auto-odświeżanie co 30 s podmienia `recentEntries`, ale otwarty arkusz zostaje ze starymi danymi — zapis nadpisze świeższą wersję | POTWIERDZONY (statycznie) | Nie — pojedynczy użytkownik, niskie prawdopodobieństwo |
| P3-5 | `README.md:57-72` | Blok „Architecture" pomija `APIKeyStore.swift`, `DesignSystem.swift`, `RecentTimeLogView.swift`, `Bundle+Localized.swift` | POTWIERDZONY (statycznie) | Nie |
| P3-6 | `marketing.md:31,41` | Subtitle App Store to „A calm Clockify menu bar timer", a słowa kluczowe zaczynają się od `clockify`. Znak towarowy w subtitle i keywords jest typowym powodem odrzucenia przy App Review (Guideline 5.2.1). `CLAUDE.md` dopuszcza „Clockify" tylko w URL-u API, tekście pomocy/błędu i disclaimerze | POTWIERDZONY (statycznie) | Nie — decyzja marketingowa, nie techniczna |
| P3-7 | `ClockifyAPIClient.swift:258-276` | `workspaceId` z pola „Workspace ID" w Ustawieniach trafia do ścieżki URL przez interpolację. `appendingPathComponent` koduje procentowo, a host i schemat są zamknięte przez walidację base URL, więc najgorszy przypadek to trafienie w inną ścieżkę tego samego hosta | POTWIERDZONY (statycznie) | Nie — brak realnego wektora |

---

## 8. Security — ustalenia

Wynik ogólny: **nie znaleziono podatności wymagającej naprawy.** Poprzedni audyt (widoczny w historii gita: „Harden network handling", „Migrate Clockify API key from UserDefaults to Keychain", „Harden build scripts") zaadresował główne ryzyka.

| Obszar | Ustalenie | Status |
|---|---|---|
| Sekrety w repo | `git ls-files` — 39 śledzonych plików, żaden nie zawiera poświadczeń. `.gitignore` blokuje `*.p12`, `*.p8`, `*.key`, `*.cer`, `*.pem`, `*.csr`, profile provisioningu, `.appstoreconnect/`, `.netrc`, `/dist`, `/dist-mas`, zrzuty ekranu w katalogu głównym | Czysto |
| Zrzuty ekranu z App Store Connect | `keys-full.png`, `generate-api-key.png` itd. leżą w katalogu głównym, ale są **nieśledzone** — łapie je reguła `/*.png` | Czysto |
| Transport | Wymuszony HTTPS; `http` dopuszczony **wyłącznie** dla loopbacku (`ClockifyAPIClient.swift:57-65`), pokryte testami | Czysto |
| Niestandardowy base URL | Wymaga jawnego potwierdzenia w oknie dialogowym ostrzegającym, że klucz API trafi do tego hosta (`AppState.swift:110-126`) | Czysto |
| Przechowywanie poświadczeń | Keychain z `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | Czysto (po P0-1) |
| Wyciek w komunikatach błędów | `AppState.sanitizedErrorMessage` mapuje `URLError` na ogólne etykiety zamiast przekazywać `localizedDescription`, które może zawierać URL-e | Czysto |
| Logowanie | Zero `print`, `NSLog` i `os_log` w kodzie produkcyjnym — klucz nie może trafić do logów | Czysto |
| Uprawnienia MAS | `com.apple.security.app-sandbox` + `com.apple.security.network.client`, nic ponadto | Minimalne — czysto |
| Poświadczenia w linii poleceń | `build_mas.sh:152-156` **aktywnie odrzuca** `APPLE_ID`/`APP_SPECIFIC_PASSWORD` z komunikatem o wycieku przez `ps`, wymusza klucze ASC API | Czysto |
| Wstrzyknięcie XML do plist | Oba skrypty walidują `VERSION` i `BUILD_NUMBER` regexem przed wstawieniem do heredoc | Czysto |
| Uwierzytelnianie / autoryzacja | Brak własnego backendu, brak ról, brak sesji — cała autoryzacja po stronie Clockify | Nie dotyczy |
| Deserializacja | Wyłącznie `Codable` z jawnymi typami; nieznane pola ignorowane | Czysto |

**Uwaga dotycząca prywatności:** aplikacja nie zbiera niczego. Brak analityki, telemetrii, crash-reportingu i zewnętrznych SDK — potwierdzone przez `grep` po całym drzewie źródeł oraz przez fakt, że `Package.swift` nie deklaruje żadnych zależności. Jedyne dane opuszczające urządzenie to wywołania Clockify API inicjowane przez użytkownika. `about.disclaimer` w Ustawieniach odpowiada stanowi faktycznemu.

---

## 9. Wydajność — ustalenia

Nie znaleziono problemu wymagającego naprawy. Historia gita pokazuje wcześniejszą optymalizację („Cache derived state and trim 30s polling to cut steady-state CPU").

| Obszar | Ustalenie | Status |
|---|---|---|
| Stan pochodny | `recomputeDerived()` liczony w `didSet`, nie w `body` — poprawnie | OK |
| Odświeżanie projektów | Dławione do 300 s (`projectsRefreshInterval`), nie przy każdym odświeżeniu | OK |
| Timer sekundowy | Jeden `Task` z `Task.sleep`, anulowany gdy nie ma trwającego wpisu | OK |
| Auto-odświeżanie | Jeden `Task` co 30 s, pomijany gdy `isLoading` | OK |
| Rozmiary odpowiedzi | Wpisy: 50, projekty: 200 na stronę — brak paginacji, ale to sufit ograniczony | OK |
| `URLSession` | Współdzielona instancja z timeoutami 20/60 s i wyłączonym cache'em | OK |
| Ciągła animacja | `LiveDot` używał `repeatForever` bez wyjścia; teraz respektuje Reduce Motion | Poprawione przy okazji |
| Pole `SecureField` | `apiKey` jest `@Published`, więc każde naciśnięcie klawisza w Ustawieniach unieważnia cały widok. Realny koszt pomijalny przy tej skali UI | OBSERWACJA JAKOŚCIOWA — nie zmieniane |

Świadomie **nie robiłem** mikrooptymalizacji bez pomiaru, zgodnie z zasadą audytu.

---

## 10. Podsumowanie po zmianach

### Bramki jakości

| Polecenie | Przed | Po |
|---|---|---|
| `swift build` | PASS, 0 ostrzeżeń | **PASS, 0 ostrzeżeń** |
| `swift build -c release` | PASS, 0 ostrzeżeń | **PASS, 0 ostrzeżeń** |
| `swift test` | PASS — 17 testów | **PASS — 52 testy** |
| `bash -n scripts/*.sh` | PASS | **PASS** |
| Parytet kluczy pl/en | 81 / 81 | **90 / 90** |
| Modyfikatory dostępności | 0 | **22** |

### Zweryfikowane automatycznie

- Trwałość Keychaina — sonda w osobnych procesach, cykl zapis/odczyt/usunięcie
- Semantyka `PUT` w Clockify przed i po poprawce — na żywym API, ze sprzątaniem
- Kształt payloadu aktualizacji — 11 testów
- Formatowanie czasu, dat, czasów trwania, parsowanie kolorów, dekodowanie API — 20 testów
- Migracja klucza API — 6 testów, sprawdzone kontrolnie przeciw staremu kodowi
- Kontrasty kolorów — przeliczone algorytmem WCAG
- Składnia skryptów — `bash -n`

### Zweryfikowane manualnie

- Aplikacja uruchamia się, łączy i renderuje realne dane po wszystkich zmianach — zrzut ekranu
- Komunikat „Project required" jest czytelny po zmianie palety — zrzut ekranu

### Niemożliwe do zweryfikowania w tym środowisku

| Element | Powód |
|---|---|
| VoiceOver i nawigacja klawiaturą | Wymaga interaktywnej sesji z włączonym VoiceOver |
| Wygląd w trybie ciemnym | Wymaga przełączenia wyglądu systemu |
| Pełny przebieg skryptów dystrybucyjnych | Brak certyfikatu Developer ID, profilu provisioningu i certyfikatów MAS |
| Zachowanie podpisanego builda Developer ID w Keychainie | jw. |
| Wysyłka do App Store Connect | jw. |
| Reduce Motion / zwiększony tekst / wysoki kontrast | Wymaga zmiany ustawień systemowych |

---

## 11. Ograniczenia audytu

1. **Brak dostępu do certyfikatów podpisujących** — pipeline'y dystrybucyjne przeszły wyłącznie kontrolę składni i przegląd kodu, nie zostały wykonane.
2. **`customFields` nadal nieprzenoszone** przy edycji wpisu (P1-1). Aplikacja ich nie dekoduje. Dotyczy tylko planów Clockify, które je udostępniają; nie miałem takiego workspace'u do testu.
3. **Testy na żywym API ograniczone do wpisów jednorazowych** — utworzonych i skasowanych. Nie testowałem zachowań wieloużytkownikowych, konfliktów ani limitów zapytań.
4. **Brak testów UI/snapshot** — weryfikacja wizualna to pojedynczy zrzut ekranu w trybie jasnym przy jednym rozmiarze okna.
5. **Historia dystrybucji nieweryfikowalna z repo** — `dist/` jest gitignorowany, więc nie da się ustalić, czy wcześniejsze wydania publiczne były podpisane.
6. **Nie sprawdzałem plików w `audit/` i `Plans/`** poza odnotowaniem ich istnienia — są nieśledzone i nietknięte, zgodnie z zasadą nienaruszania niepowiązanych zmian.
7. **Klucz API użyty do testów** został przekazany przez właściciela w trakcie sesji i jest tym samym obecny w transkrypcie. Kopia robocza przechowywana była w Keychainie, nie w pliku, i została usunięta na koniec. Właściciel zadeklarował rotację klucza.
