# Warble na Windows: instrukcja dla agenta AI

Ten plik jest napisany dla asystenta AI (Claude, ChatGPT, Codex, Copilot itp.), który pomaga zainstalować Warble na komputerze z Windows. Wklej asystentowi link do tego pliku albo całą jego treść i poproś: „Zainstaluj i skonfiguruj mi Warble według tej instrukcji”.

## Co to jest

Warble to dyktowanie głosem. Trzymasz skrót klawiszowy, mówisz, puszczasz, a tekst pojawia się tam, gdzie jest kursor (Word, Outlook, przeglądarka, komunikator, dowolne pole tekstowe). Rozpoznawanie mowy działa lokalnie modelem NVIDIA Parakeet TDT 0.6B v3 (25 języków europejskich, w tym polski i angielski, język wykrywany automatycznie). Po jednorazowym pobraniu modelu (około 670 MB) działa bez internetu, nic nie wysyła na serwery, jest darmowe.

Wersja na Windows jest w katalogu `windows/` tego repozytorium (Rust + Tauri). Wersja na macOS to reszta repozytorium i nie dotyczy tej instalacji.

## Zasady dla agenta

- Pracuj w PowerShell. Nie potrzebujesz uprawnień administratora; nie uruchamiaj niczego „jako administrator”.
- `warble.exe` to program okienkowy. Gdy wywołujesz jego komendy z PowerShell, zawsze dopisuj `| Out-Host` (albo `| Out-String`, gdy zapisujesz wynik do zmiennej). Bez tego PowerShell nie czeka na wynik i nic się nie wypisze.
- Nie zmieniaj ustawień prywatności Windows bez pytania użytkownika; jeśli trzeba, poprowadź go krok po kroku.
- Na koniec przeprowadź z użytkownikiem test z sekcji „Sprawdzenie” i zgłoś wynik.

## Wymagania

- Windows 10 (wersja 1809 lub nowsza) albo Windows 11, 64-bit (x64).
- Mikrofon.
- Około 1 GB wolnego miejsca.
- WebView2 (jest w Windows 11 i w aktualnym Windows 10; instalator doinstaluje go w razie potrzeby).

## Instalacja (zalecana): gotowy instalator

1. Otwórz stronę wydań: https://github.com/pieralukasz/warble/releases i wybierz najnowsze wydanie z nazwą zaczynającą się od `windows-v`.
2. Pobierz plik `Warble_<wersja>_x64-setup.exe` (instalator) i uruchom go. Instaluje się tylko dla bieżącego użytkownika, bez uprawnień administratora.
   - Pobranie z PowerShell (przykład dla wersji 0.1.0):
     ```powershell
     $url = "https://github.com/pieralukasz/warble/releases/download/windows-v0.1.0/Warble_0.1.0_x64-setup.exe"
     $out = "$env:USERPROFILE\Downloads\Warble-setup.exe"
     Invoke-WebRequest $url -OutFile $out
     Start-Process $out -Wait
     ```
3. Program nie jest podpisany certyfikatem, więc Windows SmartScreen może pokazać „System Windows ochronił komputer”. Kliknij „Więcej informacji”, potem „Uruchom mimo to”. To oczekiwane dla darmowego programu open source.
4. Po instalacji Warble startuje sam i otwiera okno. Ikona papugi pojawia się w zasobniku obok zegara (może być schowana pod strzałką „^”).

Alternatywa bez instalatora: z tej samej strony wydań można pobrać sam `warble.exe` i uruchomić go z dowolnego folderu (np. `%LOCALAPPDATA%\Programs\Warble`). Wtedy autostart włącza się w Ustawieniach Warble.

## Pierwsze uruchomienie

1. W oknie Warble, w sekcji „Speech model”, kliknij „Download the model”. Pobieranie około 670 MB z Hugging Face; pliki są sprawdzane sumą SHA-256. Można też z PowerShell:
   ```powershell
   & "$env:LOCALAPPDATA\Warble\warble.exe" download-model | Out-Host
   ```
   (ścieżka instalatora to zwykle `%LOCALAPPDATA%\Warble\warble.exe`; jeśli jej nie ma, znajdź plik: `Get-ChildItem $env:LOCALAPPDATA -Recurse -Filter warble.exe -ErrorAction SilentlyContinue`).
2. Gdy pojawi się „Ready. Dictation works offline.”, można dyktować.
3. Zalecane w zakładce „Settings”: włączyć „Start with Windows”, żeby Warble działał po każdym uruchomieniu komputera.

## Jak używać

- Domyślny skrót: **Ctrl + Shift + Spacja**. Trzymaj, mów, puść. Tekst wpisze się w miejscu kursora.
- Tryb „Toggle” (w Settings): naciśnij raz, żeby zacząć, drugi raz, żeby skończyć. Wygodniejszy przy dłuższych wypowiedziach.
- Skrót można zmienić w Settings (kliknij przycisk ze skrótem i naciśnij nową kombinację). Musi zawierać Ctrl, Alt lub Shift, albo być klawiszem F1 do F24.
- Na dole ekranu pojawia się mała „pigułka”: „Listening” ze wskaźnikiem głośności, kropki podczas rozpoznawania i „✓ Typed” po wpisaniu.
- Zakładka „Dictionary”: „Words” poprawia pisownię (np. nazwiska, nazwy firm), „Replacements” zamienia frazę na tekst (np. „mój mail” na adres e-mail).
- Zakładka „History”: wszystkie podyktowane teksty, z wyszukiwaniem i kopiowaniem.
- Zamknięcie okna nie wyłącza Warble; działa dalej w zasobniku. Wyłączenie: prawy klik na ikonie w zasobniku i „Quit Warble”.

## Sprawdzenie (agent wykonuje razem z użytkownikiem)

1. Diagnostyka:
   ```powershell
   & "$env:LOCALAPPDATA\Warble\warble.exe" doctor | Out-Host
   ```
   Oczekiwane: `model: installed` i co najmniej jeden mikrofon w `microphones:`. Kod wyjścia 0.
2. Test rozpoznawania bez mikrofonu (opcjonalnie): pobierz próbkę z repozytorium i ją przepisz:
   ```powershell
   $wav = "$env:TEMP\polish-sample.wav"
   Invoke-WebRequest "https://raw.githubusercontent.com/pieralukasz/warble/main/windows/tests/fixtures/polish-sample.wav" -OutFile $wav
   & "$env:LOCALAPPDATA\Warble\warble.exe" transcribe $wav | Out-Host
   ```
   Oczekiwane: zdanie bliskie „Dzień dobry, to jest test dyktowania w aplikacji Warble na komputerze z systemem Windows.” Próbka to syntezator mowy, więc drobne różnice (np. „detektowania”, mała litera w „warble”) są w porządku.
3. Test na żywo: poproś użytkownika, żeby otworzył Notatnik, kliknął w tekst, przytrzymał Ctrl + Shift + Spację, powiedział zdanie po polsku i puścił. Tekst powinien się pojawić w ciągu 1 do 3 sekund.

## Rozwiązywanie problemów

| Objaw | Co zrobić |
|---|---|
| „The microphone heard nothing” | Ustawienia Windows > Prywatność i zabezpieczenia > Mikrofon: włącz „Dostęp do mikrofonu” oraz „Zezwalaj aplikacjom klasycznym na dostęp do mikrofonu”. W Warble > Settings > Microphone wybierz właściwy mikrofon. |
| „…is taken by another program or Windows” po zmianie skrótu | Inny program używa tej kombinacji. Wybierz inną, np. Ctrl + Alt + Spacja albo F9. |
| Skrót nic nie robi | Sprawdź, czy ikona Warble jest w zasobniku. Jeśli nie, uruchom Warble z menu Start. Zajrzyj do logu (niżej). |
| Tekst nie wpisuje się w jednym konkretnym programie | Ten program działa jako administrator, a Windows nie pozwala zwykłym programom w nim pisać. Tekst i tak jest w schowku po włączeniu „Keep the text on the clipboard”, wtedy wystarczy Ctrl + V. |
| Pobieranie modelu przerwane | Kliknij „Try again”; pobrane w całości pliki są pomijane. |
| Rozpoznaje źle | Mów wyraźnie, blisko mikrofonu, zacznij mówić chwilę po wciśnięciu skrótu. Nazwy własne dodaj w „Dictionary”. |
| SmartScreen blokuje | „Więcej informacji” > „Uruchom mimo to”. |

Log działania: `%APPDATA%\Warble\warble.log`. Przy zgłaszaniu problemu dołącz jego końcówkę:
```powershell
Get-Content "$env:APPDATA\Warble\warble.log" -Tail 50
```

## Gdzie są pliki

- Ustawienia, słownik, historia, log: `%APPDATA%\Warble\` (`config.json`, `dictionary.json`, `history.json`, `warble.log`). Format `dictionary.json` jest ten sam co w Warble na macOS, więc słownik z Maca można skopiować.
- Model mowy: `%LOCALAPPDATA%\io.github.pieralukasz.warble\models\parakeet-tdt-0.6b-v3-int8\`.
- Program (instalator): `%LOCALAPPDATA%\Warble\`.

## Odinstalowanie

Ustawienia Windows > Aplikacje > Zainstalowane aplikacje > Warble > Odinstaluj. Potem, jeśli użytkownik chce usunąć też dane i model:
```powershell
Remove-Item "$env:APPDATA\Warble" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\io.github.pieralukasz.warble" -Recurse -Force
```

## Budowanie ze źródeł (tylko gdy instalator nie działa)

Wymaga Rust (https://rustup.rs, toolchain `stable-x86_64-pc-windows-msvc`), Visual Studio Build Tools z „Desktop development with C++” oraz Bun (https://bun.sh) albo Node.js.

```powershell
git clone https://github.com/pieralukasz/warble
cd warble\windows
cargo test
bunx @tauri-apps/cli@2 build
# wynik: target\release\warble.exe oraz instalator w target\release\bundle\nsis\
```

Ograniczenia tej wersji: brak dźwięków startu i końca nagrania, brak ponownego odsłuchu nagrań, wybór języka jest automatyczny (Parakeet v3 sam rozpoznaje język). Skrót musi zawierać klawisz zwykły (sam Ctrl albo sam Alt nie działa).
