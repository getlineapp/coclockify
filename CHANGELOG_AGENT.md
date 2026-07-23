# Changelog — audyt 2026-07-23

**Gałąź:** `feature/audit-fixes` (odgałęziona od `main` @ `5886e1a`)
**Wersja:** 2.3.1 → **2.3.2** (build 10 → 11)
**Commity:** 4

Repozytorium nie ma gałęzi `develop`, więc gałąź została utworzona z `main` zgodnie z zapisem procedury. Nieśledzone katalogi `Plans/` i `audit/` pozostały nietknięte.

---

## Zmienione pliki

### Kod źródłowy

| Plik | Charakter zmiany |
|---|---|
| `Sources/cocotrack/APIKeyStore.swift` | Przepisany — fallback keychaina, wydzielona logika migracji, parametryzowana nazwa usługi |
| `Sources/cocotrack/AppState.swift` | Migracja klucza, sygnalizacja błędu zapisu, wyszukiwanie wpisu przed `PUT`, formatter dat |
| `Sources/cocotrack/ClockifyModels.swift` | `tagIds` na wpisie, inicjalizator `preserving:` na payloadzie aktualizacji |
| `Sources/cocotrack/ClockifyAPIClient.swift` | Nowy przypadek błędu `keychainUnavailable` |
| `Sources/cocotrack/ContentView.swift` | Dostępność, komunikaty błędów w arkuszach, ostrzeżenie o Keychainie, feedback przy braku wpisu |
| `Sources/cocotrack/RecentTimeLogView.swift` | Wiersz zamieniony z gestu na przycisk |
| `Sources/cocotrack/MenuBarView.swift` | Etykieta dostępności na przycisku odświeżania |
| `Sources/cocotrack/DesignSystem.swift` | Paleta kontrastu, `onAccent`, Reduce Motion, pierścień fokusu, dostępność |
| `Sources/cocotrack/Formatters.swift` | Przypięta lokalizacja formatera godzin |
| `Sources/cocotrack/L10n.swift` | 11 nowych stałych |
| `Sources/cocotrack/Resources/pl.lproj/Localizable.strings` | Przepisany — polskie znaki, 4 brakujące tłumaczenia, 9 nowych kluczy |
| `Sources/cocotrack/Resources/en.lproj/Localizable.strings` | 9 nowych kluczy |

### Testy

| Plik | Charakter |
|---|---|
| `Tests/cocotrackTests/APIKeyPersistenceTests.swift` | **Nowy** — 12 testów trwałości i migracji poświadczeń |
| `Tests/cocotrackTests/FormattingAndPayloadTests.swift` | **Nowy** — 23 testy formatowania, dekodowania i kształtu payloadu |
| `Tests/cocotrackTests/ForceProjectsTests.swift` | Bez zmian — 17 testów |

### Skrypty i dokumentacja

| Plik | Charakter |
|---|---|
| `scripts/build_direct_distribution.sh` | Wykrywanie architektury, podpisywanie, klucze plist, bump wersji |
| `scripts/build_mas.sh` | Wykrywanie architektury, `ITSAppUsesNonExemptEncryption`, bump wersji |
| `AUDIT_REPORT.md` | **Nowy** |
| `UX_RECOMMENDATIONS.md` | **Nowy** |
| `CHANGELOG_AGENT.md` | **Nowy** |

---

## Wykonane poprawki

### P0-1 · Utrata klucza API (commit `89ebe01`)

`APIKeyStore` żądał keychaina data-protection bezwarunkowo. Ten backend wymaga entitlementu pochodzącego z podpisu kodu, więc każdy build ad-hoc — czyli to, co produkuje skrypt dystrybucji bezpośredniej — otrzymywał `errSecMissingEntitlement` (-34018) przy **każdym** zapisie. Błąd był odrzucany, a plaintextowa kopia zapasowa w `UserDefaults` kasowana mimo to.

- fallback do klasycznego keychaina logowania, gdy data-protection jest nieosiągalny
- stara kopia plaintext usuwana dopiero po **potwierdzonym** zapisie
- nieudany zapis zgłaszany jako `ClockifyAPIError.keychainUnavailable` i pokazywany w Ustawieniach, zamiast raportowania udanego połączenia
- decyzja migracyjna wydzielona do czystego, testowalnego typu `APIKeyMigration`

### P1-1 · Edycja wpisu kasowała tagi i taska (commit `912aa13`)

`PUT /time-entries/{id}` w Clockify zastępuje cały rekord. Aplikacja wysyłała tylko `start`, `description`, `end` i `projectId`, więc każda zmiana opisu lub projektu niszczyła `tagIds` i `taskId` na serwerze.

- `tagIds` dekodowane na `ClockifyTimeEntry`
- inicjalizator `preserving:` przenosi `taskId`, `billable` i `tagIds` z modyfikowanego wpisu
- oba miejsca wywołania lokalizują wpis przed aktualizacją i **rzucają błąd**, jeśli go nie ma, zamiast wysyłać ślepy `PUT`

### P1-3 · Dostępność (commit `b4621a6`)

Przed audytem: zero modyfikatorów `accessibility*` w całym kodzie.

- edycja wpisu z listy i edycja trwającego wpisu: `.onTapGesture` → `Button` ze stylem `.plain` (identyczny wygląd, osiągalne z klawiatury i dla VoiceOver)
- etykiety `accessibilityLabel` + `.help` na wszystkich kontrolkach ikonowych: odświeżanie, ustawienia, nowy projekt, gwiazdka ulubionych, próbki kolorów
- `StatusDot` eksponuje stan tekstem zamiast samym kolorem
- `ElapsedText` czytany jako jeden element zamiast pięciu fragmentów
- `LiveDot` respektuje `accessibilityReduceMotion` i jest ukryty przed czytnikiem
- `@FocusState` w `DSTextFieldStyle` był zadeklarowany, ale nigdy niepodpięty — teraz steruje widocznym pierścieniem fokusu

### P1-4 · Cichy brak reakcji przy nieudanym zapisie (commit `b4621a6`)

`EntryEditSheet` i `CreateProjectSheet` przy nieudanym zapisie nie zamykały się i nie pokazywały niczego — powód trafiał do paska statusu okna, zasłoniętego przez arkusz. Oba mają teraz inline'owy komunikat błędu.

### P2-1 · Kontrast (commit `b4621a6`)

Sześć wartości palety przesuniętych do progów WCAG AA; odcienie zachowane, zmieniona wyłącznie jasność. Dodany `Palette.onAccent` — biel w trybie jasnym, ciemny atrament w ciemnym, bo biel na terakocie w trybie ciemnym dawała 2.41:1.

**Świadomie niezmienione:** biel na `accent` w trybie jasnym (3.14:1). `#D27B4D` to udokumentowany kolor marki — zmiana jest decyzją produktową, opisaną jako rekomendacja B-1.

### P2-2 · Polska lokalizacja (commit `b4621a6`)

1 linia na 81 zawierała jakikolwiek znak diakrytyczny. Cały plik przepisany poprawną polszczyzną; 4 klucze pozostawione po angielsku przetłumaczone.

### P2-3 · Format 24-godzinny (commit `b4621a6`)

`DateFormatter` ze sztywnym `"HH:mm"` bez ustawionej lokalizacji przepisuje wzorzec na 12-godzinny, gdy użytkownik wyłączy „24-godzinny format czasu" — i nie dodaje AM/PM, bo nie ma go we wzorcu. Przypięte do `en_US_POSIX`. Formatter etykiet dni przeszedł na `setLocalizedDateFormatFromTemplate`.

### P2-4 · Skrypty buildu (commit `13a22f2`)

- ścieżka do binarki z `swift build --show-bin-path` zamiast zaszytego `arm64-apple-macosx`; oba skrypty raportują architektury i ostrzegają przy braku x86_64
- usunięte `|| true` przy podpisywaniu DMG
- `codesign --deep` nie jest już używane **do podpisywania**
- `NSHumanReadableCopyright` i `LSApplicationCategoryType` dodane do buildu bezpośredniego
- `ITSAppUsesNonExemptEncryption` dodane do buildu MAS

### P2-5 · „Edytuj ostatni wpis" bez reakcji (commit `b4621a6`)

Gdy ulubiony nie ma odpowiadającego wpisu w ostatnich 50, pozycja menu nie robiła nic bez komunikatu. Teraz ustawia komunikat w pasku statusu.

---

## Dodane testy

**17 → 52 testy.** Wszystkie przechodzą.

| Zestaw | Liczba | Zakres |
|---|---|---|
| `APIKeyMigrationTests` | 6 | Migracja poświadczeń, w tym **kluczowy przypadek: nieudany zapis nie może usunąć kopii zapasowej** |
| `APIKeyStoreTests` | 6 | Realny cykl życia w Keychainie na jednorazowej nazwie usługi — zapis, nadpisanie, odczyt, usunięcie, Unicode, długie wartości |
| `DateDecodingTests` | 5 | Znaczniki czasu z ułamkami sekund i bez, wpis trwający, niepoprawna data, odwrócony przedział |
| `TimeFormattingTests` | 4 | Format 24-godzinny niezależny od ustawień, wpis otwarty, czasy trwania, ponad 99 godzin |
| `ColorParsingTests` | 3 | Poprawny hex, zła długość, śmieci |
| `TimeEntryPayloadTests` | 11 | Kształt payloadu, **zachowanie tagów i taska**, czyszczenie projektu, wpis trwający, Unicode, ISO 8601 |
| `ForceProjectsTests` | 17 | Bez zmian |

### Testy sprawdzone kontrolnie

`APIKeyStoreTests` uruchomione przeciwko przywróconemu staremu zachowaniu (usunięty fallback) — **4 testy failują** z `XCTAssertTrue failed` i `("nil") is not equal to ("Optional("secret-value"))`. Po przywróceniu poprawki: 6/6 przechodzi. Test faktycznie wykrywa regresję, nie jest tautologiczny.

---

## Zmiany zachowania widoczne dla użytkownika

| Zmiana | Skutek |
|---|---|
| Klucz API zapisuje się na buildach ad-hoc i bez entitlementów | **Koniec z wylogowywaniem przy każdym starcie** |
| Nieudany zapis do Keychaina pokazuje ostrzeżenie w Ustawieniach | Zamiast raportowania udanego połączenia |
| Edycja wpisu zachowuje tagi i taska | Cicha utrata danych w Clockify zatrzymana |
| Wiersze historii i licznik są przyciskami | Osiągalne Tabem i przez VoiceOver; wygląd bez zmian |
| Pola tekstowe mają terakotowy pierścień fokusu | Wcześniej brak wskaźnika fokusu klawiatury |
| Ciemniejsze kolory ostrzeżeń, statusów i tekstu drugorzędnego | Czytelne; „Projekt wymagany" było praktycznie nieczytelne |
| Biały tekst na terakocie w trybie ciemnym → ciemny | Kontrast 2.41 → 6.24 |
| Pulsująca kropka nie animuje przy włączonym Reduce Motion | Respektuje ustawienie systemowe |
| Polski interfejs z polskimi znakami | „Połączono" zamiast „Polaczono" |
| Zakresy godzin zawsze 24-godzinne | Bez dwuznaczności przy wyłączonym formacie 24 h |
| Arkusze pokazują błąd zapisu | Zamiast pozostawania otwartym bez wyjaśnienia |
| Etykieta odświeżania: „Odświeżanie: co 30 s" | Wcześniej nieprzetłumaczone „Auto refresh: 30s" |

---

## Potencjalne regresje — do sprawdzenia manualnie

| Ryzyko | Dlaczego | Jak sprawdzić |
|---|---|---|
| **Monit Keychaina po aktualizacji** | Klasyczny keychain wiąże ACL z podpisem binarki. Przy ad-hoc każda przebudowa zmienia cdhash | Uruchom nową wersję; przy monicie kliknij **„Zawsze zezwalaj"**. Znika po przejściu na stabilny podpis Developer ID |
| Wiersze historii jako przyciski | `Button` z `.buttonStyle(.plain)` może inaczej reagować na hover lub menu kontekstowe | Najedź na wiersz, kliknij, kliknij prawym — sprawdź podświetlenie i menu |
| Zmiany palety | Sześć kolorów przesuniętych; sprawdzony tylko tryb jasny na zrzucie ekranu | Obejrzyj w trybie **ciemnym** — szczególnie przyciski Start/Stop i kropkę statusu |
| Podpisywanie bez `--deep` | Zmiana wywołania `codesign` w skrypcie dystrybucji bezpośredniej | Skrypt uruchomiony — `codesign --verify --deep --strict` przechodzi |
| Kolejność pól w etykietach dni | `setLocalizedDateFormatFromTemplate` zamiast sztywnego wzorca | Sprawdź nagłówki grup starszych niż wczoraj |
| Rzucanie błędu przy nieznanym wpisie | `knownEntryOrThrow` blokuje `PUT`, gdy wpisu nie ma w cache'u | Edytuj wpis zaraz po odświeżeniu — nie powinno być błędu „nie znaleziono" |

---

## Manual QA — przed publikacją

### Krytyczne — trwałość poświadczeń

1. Uruchom aplikację, wejdź w Ustawienia, wklej klucz API, „Zapisz i połącz". Przy monicie o dostęp do pęku kluczy wybierz **„Zawsze zezwalaj"**.
2. Zamknij aplikację całkowicie (Wyjdź z paska menu, nie samo zamknięcie okna).
3. Uruchom ponownie. **Musi połączyć się sama, bez pytania o klucz.** To jest ten błąd.
4. Powtórz cykl trzy razy.
5. Sprawdź, że klucz jest w Keychainie: `security find-generic-password -s com.cocolab.cocotrack`.

### Krytyczne — integralność danych

6. W Clockify (przeglądarka) dodaj tag do dowolnego wpisu.
7. W Cocotrack zmień opis tego wpisu i zapisz.
8. Odśwież w Clockify — **tag musi nadal tam być.**
9. Zmień projekt tego wpisu z Cocotrack; tag i task nadal muszą być.
10. Wyczyść projekt („Brak projektu") — projekt znika, tagi zostają.

### Główne ścieżki

11. Start timera z okna, popovera i z pozycji historii.
12. Stop timera z obu powierzchni.
13. Edycja opisu, czasu startu, czasu końca; przełącznik „Wpis ma czas zakończenia".
14. Utworzenie projektu z wyborem koloru.
15. Przypięcie i odpięcie ulubionego; sprawdź, czy przeżywa restart.
16. Zmiana projektu trwającego wpisu.

### Dostępność — nieweryfikowane automatycznie

17. **Tab przez cały interfejs** — każda kontrolka musi być osiągalna, z widocznym fokusem.
18. Edytuj wpis **bez użycia myszy** (Tab do wiersza, Spacja/Enter).
19. Włącz VoiceOver (⌘F5) — przejdź pasek narzędzi, licznik, wiersze historii. Wszystko musi mieć nazwę.
20. Ustawienia systemowe → Dostępność → **Ogranicz ruch** — pulsująca kropka musi przestać animować.
21. Ustawienia systemowe → Dostępność → **Zwiększ kontrast** — sprawdź, czy nic nie znika.

### Wygląd

22. **Tryb ciemny** — cała aplikacja, ze szczególną uwagą na przyciski Start/Stop i kropkę statusu.
23. Zmień rozmiar okna do minimum (480×400) i do pełnego ekranu.
24. Ustaw język systemu na polski — sprawdź polskie znaki w interfejsie.
25. Ustawienia systemowe → Ogólne → Data i czas → **wyłącz „Format 24-godzinny"**; zakresy godzin muszą pozostać 24-godzinne.

### Przypadki brzegowe

26. Wyłącz Wi-Fi w trakcie działania timera — sprawdź komunikat błędu i zachowanie po powrocie sieci.
27. Zapisz wpis z bardzo długim opisem (500+ znaków) i z emoji.
28. Kliknij Start dwa razy szybko — nie powinny powstać dwa wpisy.
29. Wpisz nieprawidłowy klucz API — komunikat błędu musi być zrozumiały.
30. Menu kontekstowe „Edytuj ostatni wpis" na ulubionym bez historii — musi pokazać komunikat, nie milczeć.

---

## Świadomie niezrobione

| Element | Powód |
|---|---|
| `customFields` przenoszone przy edycji | Brak workspace'u z włączonymi polami niestandardowymi — nie dało się zreprodukować ani zweryfikować. Naprawianie na ślepo byłoby zgadywaniem. Rekomendacja B-5 |
| Podpis Developer ID | **Brak certyfikatu Developer ID Application na tej maszynie.** Dostępne są tylko Apple Development i certyfikaty Mac App Store. Patrz niżej |
| Ujednolicenie stanu szkicu timera | Wymaga decyzji, które źródło jest kanoniczne i co ma się dziać przy szybkim starcie. Rekomendacja A-3 |
| Zmiana koloru marki dla kontrastu | Decyzja produktowa, nie techniczna. Rekomendacja B-1 |
| Usunięcie martwego `bulkEditTimeEntries` | Nieszkodliwe; może być planowane pod przyszłą funkcję |
| Aktualizacja bloku „Architecture" w README | Kosmetyka dokumentacji, poza zakresem napraw technicznych |
| `VERSION` w skrypcie bezpośrednim nadal na sztywno | Zmiana wpłynęłaby na sposób wywoływania skryptu |
| Analityka jakiegokolwiek rodzaju | Świadomie odrzucone — patrz `UX_RECOMMENDATIONS.md`, grupa D |

---

## Warunek konieczny publicznej dystrybucji

Na maszynie **nie ma certyfikatu Developer ID Application**:

```
$ security find-identity -v -p codesigning
  1) Apple Development: Pawel Orzech (PU22HCG49W)
  2) 3rd Party Mac Developer Application: COCOLAB.PL Sp. z o.o. (9Q6V98RCP9)
  3) iPhone Distribution: COCOLAB.PL Sp. z o.o. (9Q6V98RCP9)
```

Apple Development służy wyłącznie do developmentu. Certyfikaty „3rd Party Mac Developer" działają tylko dla Mac App Store — Gatekeeper nie zaakceptuje nimi podpisanej aplikacji poza App Store. Nie ma więc czym podpisać DMG do dystrybucji bezpośredniej.

**Skutki, wszystkie zweryfikowane w audycie:**

1. Gatekeeper blokuje pierwsze uruchomienie u każdego, kto pobierze DMG.
2. Ad-hoc jest bezpośrednią przyczyną P0-1 — keychain data-protection odrzuca każdy zapis kodem -34018.
3. Podpis ad-hoc zmienia się przy każdej przebudowie, więc klasyczny keychain będzie prosił o dostęp po każdej aktualizacji.

**Rozwiązanie:** utworzyć certyfikat **Developer ID Application** w portalu Apple Developer, zapisać profil notaryzacji przez `xcrun notarytool store-credentials`, a następnie budować z `SIGN_IDENTITY` i `NOTARIZE_PROFILE`. Skrypt jest gotowy — wymaga wyłącznie tych dwóch zmiennych.
