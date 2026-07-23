# Cocotrack — rekomendacje UX

**Data:** 2026-07-23 · **Gałąź:** `feature/audit-fixes`

Fakty i dowody są w `AUDIT_REPORT.md`. Ten dokument zawiera **oceny i propozycje** — czyli rzeczy, które z definicji są opinią, nie pomiarem. Tam gdzie coś jest zweryfikowane, jest to powiedziane wprost.

Scoring: **Impact / Effort / Confidence / Risk** w skali 1–5. `Priority score = Impact × Confidence / Effort`. To narzędzie pomocnicze do sortowania, nie automatyczna decyzja — kilka pozycji z niskim wynikiem jest mimo to warta zrobienia, i odwrotnie.

---

## 1. Ocena UX — stan obecny

Cocotrack robi jedną rzecz i robi ją spokojnie. Interfejs jest gęsty bez bycia ciasnym, hierarchia informacji działa — wielki licznik jest bezdyskusyjnie najważniejszym elementem ekranu, a historia schodzi na drugi plan. Ciepła paleta i brak ozdobników są zgodne z obietnicą „native, calm, zero bloat" z materiałów marketingowych. To rzadkie i warte ochrony.

Największe tarcie nie leży w wyglądzie, tylko w **zakresie**: aplikacja pozwala zacząć i zatrzymać czas, ale nie pozwala go w pełni administrować. Nie da się usunąć wpisu ani dodać wpisu wstecz — obie operacje wymagają przejścia do Clockify w przeglądarce. Dla narzędzia, którego cała wartość polega na tym, żeby *nie* otwierać przeglądarki, to podważa główną tezę produktu.

Druga rzecz: dwie powierzchnie UI (okno i popover) mają **niezależne stany szkicu timera**. Tekst wpisany w oknie nie pojawia się w popoverze i odwrotnie. To potwierdzone w kodzie (`AUDIT_REPORT.md`, P3-2), nie hipoteza, i łamie założenie, że to ta sama aplikacja widziana z dwóch stron.

Trzecia: dla aplikacji żyjącej w pasku menu **nie ma ani jednego skrótu klawiszowego** — `grep` po `keyboardShortcut` w całym drzewie źródeł zwraca zero trafień. Archetypowa funkcja menu-bar timera to „stop bez zdejmowania rąk z klawiatury", a tu jej nie ma.

Przeszedłem główne ścieżki jako różne persony. Poniżej to, co wyszło.

### Nowy użytkownik

Pierwszy ekran to ikona koła zębatego, nagłówek „Skonfiguruj połączenie z Clockify" i przycisk Ustawienia. Kliknięcie otwiera arkusz z trzema polami: API key, Base URL, Workspace ID. **Nigdzie nie ma informacji, skąd wziąć klucz API** — instrukcja jest wyłącznie w README na GitHubie, którego użytkownik App Store nigdy nie zobaczy. To najostrzejsza bariera „czasu do pierwszej wartości" w całym produkcie.

Dodatkowo pole „Base URL" jest wyeksponowane na równi z kluczem API, mimo że dotyczy skrajnie rzadkiego przypadku, a wpisanie tam czegokolwiek uruchamia ostrzeżenie o wysyłaniu klucza do obcego hosta. Pokazywanie tego pola każdemu przy pierwszym kontakcie to zaproszenie do problemu, którego prawie nikt nie ma.

### Regularny użytkownik

Ścieżka „kliknij Start przy pozycji z historii" jest bardzo dobra — to najlepszy element tego UI. Lista łączy jednak ulubione i ostatnie w jeden zbiór **przycięty do 10 pozycji łącznie** (`AppState.recomputeDerived`). Przypięcie dziesięciu ulubionych całkowicie wypycha historię. Użytkownik nie dostaje o tym żadnego sygnału.

Nie ma też widocznej sumy „dziś" — dzienne sumy są w nagłówkach grup na liście historii, ale liczba, która dla osoby śledzącej czas jest najważniejsza w ciągu dnia, nie jest nigdzie wyeksponowana ani w pasku menu, ani przy liczniku.

### Powracający po przerwie

Aplikacja pokazuje ostatnie 50 wpisów bez filtrowania i bez wyszukiwania. Po dwóch tygodniach nieobecności odnalezienie konkretnego wpisu do poprawienia oznacza scrollowanie. Przy 50 pozycjach jest to znośne; to sufit, nie problem otwarty.

### Klawiatura i czytnik ekranu

Przed audytem: edycja wpisu była **fizycznie nieosiągalna bez myszy**, pola tekstowe nie miały widocznego wskaźnika fokusu, a wszystkie kontrolki ikonowe były bezimienne. To zostało naprawione (`AUDIT_REPORT.md`, P1-3), ale **nie zostało zweryfikowane z włączonym VoiceOver** — to pozycja z checklisty QA, nie fakt.

### Wolne łącze i błędy

Obsługa błędów sieci jest przemyślana — `sanitizedNetworkErrorMessage` rozróżnia offline, timeout, nieosiągalny host i błąd TLS, każdy z osobnym komunikatem. To lepiej niż w większości aplikacji tej wielkości. Brakuje jednak **akcji ponowienia** — komunikat jest, ale użytkownik musi sam znaleźć przycisk odświeżania w pasku narzędzi.

### Osoba popełniająca błąd

Tu jest najgorzej i to jest sedno. Nie da się **usunąć wpisu**. Uruchomienie timera przez pomyłkę, literówka w opisie utrwalona na pół dnia, dubel po podwójnym kliknięciu — każdy z tych przypadków wymaga otwarcia clockify.me. Nie ma też cofnięcia po zatrzymaniu timera ani potwierdzenia przy zatrzymaniu długiego wpisu.

---

## 2. Grupa A — quick wins

Małe, tanie, niskiego ryzyka, mieszczą się w jednym patchu.

### A-1 · Link „skąd wziąć klucz API" w Ustawieniach

**Problem użytkownika:** przy pierwszym uruchomieniu nie ma żadnej wskazówki, gdzie wygenerować klucz. Instrukcja istnieje wyłącznie w README na GitHubie.
**Rozwiązanie:** pod polem API key jeden `Link` do `clockify.me/user/settings` z krótkim opisem.
**Oczekiwany wpływ:** skraca czas do pierwszej wartości dla każdego nowego użytkownika; usuwa jedyny moment, w którym trzeba opuścić aplikację, żeby ją w ogóle uruchomić.
**Zakres prac:** ~10 linii w `SettingsSheet` + 1 klucz lokalizacyjny × 2 języki.
**Ryzyko:** brak. Nie zmienia zachowania, tylko dodaje odnośnik.
**Wpływ na prostotę:** neutralny — jedna linia tekstu w arkuszu, który i tak już ma podtytuł.
**Walidacja:** poproś dwie osoby, które nie znają Clockify, o skonfigurowanie aplikacji bez podpowiedzi.
**Metryka:** liczba osób, które kończą konfigurację bez pytania (test korytarzowy, n≈5).

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 4 | 1 | 5 | 1 | **20.0** |

---

### A-2 · Usuwanie wpisu czasu

**Problem użytkownika:** nie da się skasować pomyłkowego wpisu bez otwierania Clockify w przeglądarce. Podważa to główną obietnicę produktu.
**Rozwiązanie:** `DELETE /workspaces/{ws}/time-entries/{id}` — endpoint jest już zweryfikowany w audycie (`HTTP 204`). Pozycja w menu kontekstowym wiersza + przycisk w arkuszu edycji, oba z potwierdzeniem.
**Oczekiwany wpływ:** domyka podstawowy CRUD; usuwa najczęstszy powód wyjścia z aplikacji.
**Zakres prac:** jedna metoda klienta, jedna metoda `AppState`, dwa wejścia w UI, dialog potwierdzenia, testy.
**Ryzyko:** **operacja nieodwracalna** — potwierdzenie jest obowiązkowe, nie opcjonalne. Clockify nie ma kosza.
**Wpływ na prostotę:** lekko zwiększa złożoność, ale to brakujący element istniejącego modelu, nie nowa koncepcja.
**Walidacja:** przetestuj na wpisie jednorazowym; sprawdź, że lista odświeża się po usunięciu.
**Metryka:** jakościowa — czy nadal otwierasz clockify.me po pomyłce.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 5 | 2 | 5 | 3 | **12.5** |

---

### A-3 · Wspólny stan szkicu timera dla okna i popovera

**Problem użytkownika:** tekst wpisany w oknie głównym nie pojawia się w popoverze i odwrotnie. Potwierdzone w kodzie.
**Rozwiązanie:** `ContentView` przechodzi na `appState.timerDraftDescription` / `timerDraftProjectId`, tak jak `MenuBarView`. Usuwa lokalne `@State`.
**Oczekiwany wpływ:** obie powierzchnie zachowują się jak jedna aplikacja; likwiduje klasę „gdzie zniknął mój tekst".
**Zakres prac:** usunięcie dwóch `@State` i podmiana referencji, ~15 linii.
**Ryzyko:** niskie. Uwaga: `startTimer(using:)` nadpisuje draft, więc szybki start z historii wyczyści to, co użytkownik wpisał ręcznie — trzeba to rozstrzygnąć przy okazji.
**Wpływ na prostotę:** **poprawia** — usuwa drugie źródło prawdy.
**Walidacja:** wpisz tekst w oknie, otwórz popover, sprawdź czy jest.
**Metryka:** brak — to poprawka spójności, nie funkcja.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 1 | 5 | 2 | **15.0** |

---

### A-4 · Suma „dziś" przy liczniku i w pasku menu

**Problem użytkownika:** najważniejsza liczba dnia jest schowana w nagłówku grupy na liście historii.
**Rozwiązanie:** `recentEntryGroups` już liczy sumy dzienne. Wystarczy pokazać sumę dzisiejszą pod licznikiem i opcjonalnie w popoverze.
**Oczekiwany wpływ:** odpowiada na pytanie „ile mam dziś" bez scrollowania.
**Zakres prac:** jedno computed property + jeden `Text`. Dane już są.
**Ryzyko:** brak.
**Wpływ na prostotę:** neutralny — jedna liczba więcej w miejscu, gdzie użytkownik już patrzy.
**Uwaga:** suma pomija wpis trwający (`durationSeconds` zwraca `nil` dla otwartego). Trzeba świadomie zdecydować, czy dodawać czas na żywo.
**Metryka:** jakościowa.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 4 | 1 | 4 | 1 | **16.0** |

---

### A-5 · Przycisk „Ponów" w pasku statusu przy błędzie

**Problem użytkownika:** po błędzie sieci jest komunikat, ale akcja naprawcza jest gdzie indziej — w ikonie w pasku narzędzi.
**Rozwiązanie:** gdy `statusMessage` niesie błąd, pokaż obok inline'owy przycisk „Ponów" wołający `refreshEntries()`.
**Zakres prac:** wymaga rozróżnienia komunikatów błędu od informacyjnych — obecnie `statusMessage` to jeden `String` bez typu. Warto przy okazji wprowadzić enum stanu statusu.
**Ryzyko:** niskie.
**Wpływ na prostotę:** neutralny; refaktor `statusMessage` na typ jest ulepszeniem sam w sobie.
**Metryka:** jakościowa.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 2 | 4 | 1 | **6.0** |

---

### A-6 · Zwinięcie pola Base URL do sekcji zaawansowanej

**Problem użytkownika:** pole dotyczące skrajnie rzadkiego przypadku jest wyeksponowane na równi z kluczem API przy pierwszym kontakcie.
**Rozwiązanie:** ukryj Base URL i Workspace ID pod rozwijanym „Zaawansowane", domyślnie zamkniętym. Rozwiń automatycznie, gdy któreś ma wartość niedomyślną.
**Oczekiwany wpływ:** arkusz konfiguracji redukuje się do jednego pola, którym faktycznie jest.
**Ryzyko:** niskie — użytkownicy używający tych pól i tak wiedzą, czego szukają, a auto-rozwijanie ich chroni.
**Wpływ na prostotę:** **poprawia** — mniej rzeczy na pierwszym ekranie.
**Metryka:** jakościowa.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 1 | 4 | 1 | **12.0** |

---

## 3. Grupa B — średni zakres

Nowe stany lub komponenty, zmiany w kilku miejscach.

### B-1 · Domknięcie kontrastu koloru marki

**Problem:** biały tekst na terakocie `#D27B4D` daje 3.14:1 w trybie jasnym, przy progu WCAG AA 4.5:1 dla tekstu tej wielkości. Dotyczy głównego przycisku Start.
**Rozwiązanie:** przyciemnić terakotę do ok. `#B65E30` (4.53:1), albo zostawić kolor i zmienić rolę — obramowany przycisk z terakotowym tekstem zamiast wypełnienia.
**Dlaczego nie zrobione w audycie:** `#D27B4D` jest udokumentowany w `CLAUDE.md` jako kolor marki. To decyzja produktowa, nie techniczna, i nie moja do podjęcia.
**Ryzyko:** zmienia rozpoznawalny charakter wizualny aplikacji.
**Wpływ na prostotę:** neutralny.
**Walidacja:** postaw oba warianty obok siebie w obu trybach; sprawdź w Digital Color Meter.
**Metryka:** kontrast ≥ 4.5:1 zmierzony.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 2 | 5 | 3 | **7.5** |

---

### B-2 · Globalny skrót klawiszowy start/stop

**Problem:** aplikacja żyje w pasku menu, ale nie ma ani jednego skrótu klawiszowego. Zweryfikowane — zero trafień na `keyboardShortcut` w całym kodzie.
**Rozwiązanie:** dwuetapowo. Najpierw skróty lokalne (`⌘↵` start, `⌘.` stop, `⌘R` odśwież, `⌘,` ustawienia) — tanie i bez zależności. Dopiero potem, jeśli okaże się potrzebne, skrót globalny.
**Uwaga o skrócie globalnym:** wymaga uprawnień poza sandboxem albo `KeyboardShortcuts` w wariancie zgodnym z MAS. Zderza się z zasadą „zero zależności" opisaną w README i z ograniczeniami sandboxu App Store. **Zrób najpierw wersję lokalną i sprawdź, czy globalna jest w ogóle potrzebna.**
**Ryzyko:** niskie dla lokalnych, wysokie dla globalnych (sandbox, uprawnienia, review).
**Wpływ na prostotę:** lokalne — poprawiają. Globalne — zauważalnie komplikują.
**Metryka:** jakościowa — czy zatrzymujesz timer bez sięgania po mysz.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 4 | 2 | 4 | 2 | **8.0** |

---

### B-3 · Ręczne dodanie wpisu wstecz

**Problem:** można wyłącznie startować timer „od teraz". Zalogowanie wczorajszego spotkania wymaga wystartowania timera, zatrzymania go i edycji obu dat — albo otwarcia Clockify.
**Rozwiązanie:** arkusz „Dodaj wpis" z datą początku, końca, opisem i projektem. `POST /time-entries` przyjmuje `start` i `end` naraz — zweryfikowane w audycie przy tworzeniu wpisów testowych.
**Oczekiwany wpływ:** domyka drugą połowę CRUD-u; usuwa kolejny powód otwierania przeglądarki.
**Zakres prac:** jeden arkusz, jedna metoda `AppState`, walidacja (koniec po początku — logika już istnieje w `EntryEditSheet`).
**Ryzyko:** średnie — więcej powierzchni na błędne dane czasowe.
**Wpływ na prostotę:** dodaje ekran. Uzasadnione, bo bez tego produkt nie zastępuje Clockify, tylko go uzupełnia.
**Walidacja:** dodaj wpis wstecz, porównaj z tym co widać w Clockify.
**Metryka:** jakościowa.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 4 | 3 | 4 | 2 | **5.3** |

---

### B-4 · Rozdzielenie ulubionych od historii

**Problem:** obie listy dzielą jeden limit 10 pozycji. Dziesięć ulubionych całkowicie ukrywa historię, bez żadnego sygnału.
**Rozwiązanie:** dwie sekcje z niezależnymi limitami, albo jedna z nagłówkami grup. Przy zerze ulubionych sekcja nie pojawia się wcale.
**Oczekiwany wpływ:** przypinanie przestaje mieć niewidoczny koszt.
**Ryzyko:** niskie.
**Wpływ na prostotę:** lekko zwiększa złożoność wizualną, ale usuwa ukrytą zasadę, której użytkownik nie może wywnioskować z interfejsu.
**Walidacja:** przypnij 10 ulubionych i sprawdź, czy historia nadal jest dostępna.
**Metryka:** jakościowa.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 2 | 4 | 1 | **6.0** |

---

### B-5 · Przeniesienie `customFields` przy edycji wpisu

**Problem:** audyt naprawił niszczenie `tagIds` i `taskId` przy edycji, ale `customFields` nadal nie są dekodowane ani odsyłane. Na planach Clockify, które je udostępniają, edycja opisu je wyzeruje.
**Rozwiązanie:** zdekodować `customFields` jako nieprzezroczystą strukturę i odesłać bez zmian w payloadzie `PUT`.
**Dlaczego nie zrobione w audycie:** nie miałem workspace'u z włączonymi polami niestandardowymi, więc nie dało się tego zreprodukować ani zweryfikować. Naprawianie na ślepo czegoś, czego nie widziałem, byłoby zgadywaniem.
**Ryzyko:** niskie, jeśli traktowane jako przezroczysty przelot.
**Wpływ na prostotę:** neutralny.
**Walidacja:** wymaga workspace'u z polami niestandardowymi; ten sam schemat testu co przy tagach w `AUDIT_REPORT.md` P1-1.
**Metryka:** pola niestandardowe przeżywają edycję opisu.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 2 | 3 | 1 | **4.5** |

---

## 4. Grupa C — eksperymenty

Wartość niepewna. Zaprototypuj i sprawdź, zanim zbudujesz na poważnie.

### C-1 · Wykrywanie bezczynności

Gdy Mac był bezczynny przez N minut przy działającym timerze, zapytaj po powrocie, czy odjąć ten czas. Klasyczna funkcja time-trackerów, ale zderza się z tożsamością produktu — „spokojna aplikacja, która się nie wtrąca" to obietnica z materiałów marketingowych, a to funkcja, która z definicji się wtrąca.
**Jak sprawdzić:** zbieraj **lokalnie i tylko dla siebie** przez dwa tygodnie, jak często zdarza ci się zapomniany timer. Jeśli rzadziej niż raz w tygodniu, odpuść.
**Ryzyko:** średnie — łatwo o fałszywe alarmy (długie spotkanie bez dotykania klawiatury to praca, nie bezczynność).

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 3 | 2 | 3 | **2.0** |

### C-2 · Podpowiadanie projektu na podstawie opisu

Ta sama treść opisu zwykle należy do tego samego projektu. `recomputeDerived` już utrzymuje mapę `opis → ostatni projekt` — dane są, brakuje tylko podpowiedzi w UI.
**Jak sprawdzić:** policz na własnej historii, w ilu procentach przypadków najczęstszy projekt dla danego opisu jest tym właściwym. Poniżej ~80 % podpowiedź będzie irytować bardziej niż pomagać.
**Ryzyko:** niskie, jeśli to sugestia; wysokie, jeśli automatyczne wypełnienie.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 3 | 2 | 2 | 2 | **3.0** |

### C-3 · Wyszukiwarka w historii

Przy obecnych 50 wpisach scrollowanie wystarcza. Sensowne dopiero, gdy limit wzrośnie.
**Jak sprawdzić:** podnieś limit do 200 i zobacz, czy zaczyna przeszkadzać.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 2 | 2 | 2 | 1 | **2.0** |

### C-4 · Ikona w pasku menu bez tekstu

Obecnie tytuł to opis (do 20 znaków) plus licznik — przy długich opisach zajmuje sporo paska menu. Opcja „tylko ikona i czas" albo „tylko ikona".
**Jak sprawdzić:** kwestia gustu i zagęszczenia twojego paska menu. Zrób oba warianty i pożyj tydzień z każdym.

| Impact | Effort | Confidence | Risk | Score |
|---|---|---|---|---|
| 2 | 1 | 3 | 1 | **6.0** |

---

## 5. Grupa D — odrzucone

Rzeczy, których świadomie **nie** rekomenduję, z uzasadnieniem.

| Propozycja | Dlaczego odrzucona |
|---|---|
| **Analityka / telemetria / crash-reporting** | Aplikacja dziś nie zbiera niczego i to jest jej mocna strona, nie brak. Dodanie SDK oznacza politykę prywatności, deklarację App Privacy w App Store, obowiązki RODO i zaufanie do trzeciej strony, która zobaczy opisy wpisów czasu — czyli nazwy klientów i projektów. Dla narzędzia jednoosobowego wartość jest bliska zeru. **Nie proponuj zbierania danych „na przyszłość".** |
| **Konta / synchronizacja / własny backend** | Clockify już jest backendem. Własna warstwa dodałaby powierzchnię ataku, koszt utrzymania i problem synchronizacji, nie rozwiązując żadnego realnego problemu. |
| **Wykresy, raporty, dashboardy** | Clockify ma rozbudowaną warstwę raportową. Powielanie jej w kliencie menu-bar to feature creep i wprost sprzeczne z „zero bloat". |
| **Onboarding wieloekranowy** | Aplikacja ma jedno pole konfiguracji. Kreator na trzy ekrany dla jednego pola to ceremonia. A-1 (link do klucza) rozwiązuje realny problem za ułamek kosztu. |
| **Powiadomienia „nie zapomnij o timerze"** | Niezamawiane powiadomienia to naruszenie obietnicy „spokojnej" aplikacji. Jeśli kiedykolwiek, to wyłącznie jako opt-in domyślnie wyłączony. |
| **Migracja na Combine / TCA / inną architekturę** | Obecna architektura — jeden `ObservableObject` z `async/await` — jest właściwie dopasowana do 2 700 linii kodu. Przepisanie to czysty koszt bez korzyści. |
| **Dodanie zależności zewnętrznych** | „Zero dependencies" jest deklarowane w README i w materiałach App Store. Trzyma powierzchnię ataku, rozmiar binarki i koszt utrzymania na minimum. Nie łam tego dla wygody. |
| **Zmiana `#FBF9F5` / `#2A2620` (kolory tła)** | Udokumentowane w `CLAUDE.md`, kontrast z tekstem podstawowym wynosi 14.3:1 i 13.4:1. Nie ma czego naprawiać. |
| **Wsparcie dla wielu workspace'ów naraz** | Jest już nadpisanie workspace'u w Ustawieniach. Przełącznik w UI to złożoność dla przypadku brzegowego, dopóki realnie nie pracujesz w dwóch naraz. |

---

## 6. Metryki

Aplikacja nie zbiera i **nie powinna zacząć zbierać** danych o użyciu (patrz grupa D). Wszystkie metryki poniżej są mierzalne lokalnie albo z publicznych źródeł — żadna nie wymaga telemetrii ani dostępu do treści wpisów użytkownika.

| Metryka | Jak zmierzyć | Do czego |
|---|---|---|
| Czas do pierwszej wartości | Stoper w teście korytarzowym: od uruchomienia do pierwszego działającego timera, n≈5 osób | A-1, A-6 |
| Ukończenie konfiguracji bez pomocy | Ile osób z tych 5 skonfigurowało bez pytania | A-1 |
| Wyjścia do clockify.me | Policz przez tydzień na sobie, ile razy musiałeś otworzyć przeglądarkę i po co | A-2, B-3 |
| Liczba kroków w głównej ścieżce | Policz kliknięcia dla start/stop/edycja przed i po zmianie | A-3, B-2 |
| Zgodność kontrastu | Digital Color Meter lub przeliczenie WCAG na palecie | B-1 |
| Przejścia checklisty a11y | Sekcja QA w `CHANGELOG_AGENT.md`, przechodzone ręcznie przed wydaniem | P1-3 |
| Wynik testów regresyjnych | `swift test` — obecnie 52 testy | wszystko |
| Zdrowie wydania | Oceny i recenzje w App Store, zgłoszenia w GitHub Issues | ogólne |
| Sygnały crashy | Wbudowany raport awarii macOS (opt-in użytkownika, dane u Apple) — **nie** własne SDK | ogólne |

**Świadomie nieproponowane:** wskaźniki retencji, lejki konwersji, śledzenie zdarzeń, mapy ciepła. Wymagają telemetrii, której ten produkt nie ma i której dodanie kosztowałoby więcej niż dałoby — zwłaszcza że opisy wpisów czasu to dane klientów.

---

## 7. Roadmapa

### Najbliższy patch (2.3.2) — naprawy z audytu

Wszystko już zrobione na `feature/audit-fixes`. Wymaga QA manualnego przed wydaniem.

- P0-1 trwałość klucza API — **kluczowe, to naprawia twoje ciągłe wylogowywanie**
- P1-1 zachowanie tagów i tasków przy edycji — cicha utrata danych w Clockify
- P1-3 warstwa dostępności
- P1-4 informacja o nieudanym zapisie w arkuszach
- P2-1 kontrasty · P2-2 polskie znaki · P2-3 format 24-godzinny · P2-4 skrypty buildu

### Kolejne wydanie (2.4.0) — domknięcie podstaw

- A-1 link do klucza API
- A-2 usuwanie wpisu
- A-3 wspólny stan szkicu
- A-4 suma „dziś"
- A-6 zwinięcie pól zaawansowanych
- **P1-2 podpisywanie Developer ID** — warunek konieczny publicznej dystrybucji, patrz niżej

### Większe wydanie (2.5.0)

- B-3 ręczne dodanie wpisu wstecz
- B-2 skróty klawiszowe (najpierw lokalne)
- B-4 rozdzielenie ulubionych od historii
- B-1 decyzja o kontraście koloru marki
- B-5 `customFields`, jeśli masz workspace do przetestowania

### Do walidacji przed budowaniem

- C-1 wykrywanie bezczynności — zmierz na sobie, czy problem w ogóle istnieje
- C-2 podpowiadanie projektu — policz trafność na własnej historii
- C-3 wyszukiwarka — dopiero po podniesieniu limitu wpisów
- C-4 wariant paska menu — pożyj tydzień z każdym

---

## 8. Jedna rzecz przed wszystkimi innymi

**Przestań publikować buildy podpisane ad-hoc.**

To nie jest rekomendacja UX, ale wpływa na doświadczenie użytkownika mocniej niż cokolwiek z tej listy. Ad-hoc jest bezpośrednią, zweryfikowaną przyczyną tego, że aplikacja gubiła twój klucz API — bez entitlementu z podpisu keychain data-protection odrzucał **każdy** zapis kodem -34018. Poprawka z audytu obchodzi to przez klasyczny keychain, ale to obejście, nie rozwiązanie: klasyczny keychain wiąże dostęp z konkretnym podpisem binarki, więc przy ad-hoc każda przebudowa może wywołać monit systemowy o dostęp do pęku kluczy.

Do tego Gatekeeper blokuje pierwsze uruchomienie u każdego, kto pobierze DMG — czyli u każdego użytkownika poza tobą.

Podpisanie certyfikatem Developer ID plus notaryzacja rozwiązuje wszystkie trzy problemy naraz. Skrypt jest gotowy, wymaga tylko `SIGN_IDENTITY` i `NOTARIZE_PROFILE`.
