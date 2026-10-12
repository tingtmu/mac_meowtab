# peek-settings Specification

## Purpose
The MeowTab section of Settings: choosing each mood's PNG, the mood thresholds and peek height, what imports are accepted, and where it is all stored.

## Requirements

### Requirement: A MeowTab section in Settings
Settings SHALL list a MeowTab section first in its sidebar. The section SHALL hold:
- three picture cards (few, some and many), each titled with its window range;
- "Some from" and "Many from" steppers;
- "With 1 window" and "With many windows" peek-height sliders in whole percent;
- a Restore defaults button;
- a message line.

Every change SHALL apply at once and be used by the next switcher session.

#### Scenario: First use
- **WHEN** the user opens the MeowTab section before changing anything
- **THEN** it shows the three shipped cats titled "Few · 1–2 windows", "Some · 3–7 windows" and "Many · 8+ windows", thresholds 3 and 8, and heights 80 % and 95 %

### Requirement: Only valid values
The controls SHALL keep `2 ≤ someFrom < manyFrom ≤ 30` and `30 % ≤ minShare < maxShare ≤ 100 %`. Moving one value past the other SHALL push the other along. Invalid stored values SHALL fall back to the defaults for that pair, and the message line SHALL say so.

#### Scenario: Pushing a threshold past the other
- **WHEN** "Many from" is 4 and the user raises "Some from" to 4
- **THEN** "Many from" becomes 5

#### Scenario: Hand-edited invalid values
- **WHEN** the stored thresholds are 9 and 5
- **THEN** the switcher uses 3 and 8, and the section says some saved settings were invalid and their defaults are used

### Requirement: Choose or drop a PNG for each mood
Each card SHALL accept a PNG chosen with "Choose…" or dropped on it, and SHALL show it at once. Only that mood SHALL change. "Use default" SHALL put that mood's shipped cat back, and SHALL be offered whenever the mood has a saved picture setting, even one MeowTab can't use.

#### Scenario: A custom "many" picture
- **WHEN** the user drops a transparent PNG on the many card
- **THEN** the card shows it, the next switcher with 8+ windows shows it with its transparency, and few and some are unchanged

#### Scenario: Back to the shipped cat
- **WHEN** the user clicks "Use default" on the many card
- **THEN** many shows the shipped cat again, and MeowTab's copy of the custom picture is deleted

### Requirement: Import limits
An import SHALL be accepted only if its content is a still PNG of at most 10 MB, at most 8192 pixels a side and at most 32 megapixels, with some visible pixel. Anything else SHALL be refused with a reason on the message line, and the card SHALL keep its picture. An accepted picture larger than 1024 pixels on its longest side SHALL be scaled down to 1024, keeping its proportions and transparency.

#### Scenario: Renamed JPEG
- **WHEN** the user drops a JPEG named `cat.png`
- **THEN** the message asks for a PNG, and the card is unchanged

#### Scenario: GIF or animated PNG
- **WHEN** the user chooses a GIF or an animated PNG
- **THEN** the message says GIFs and animated PNGs aren't supported yet, and the card is unchanged

#### Scenario: Too large
- **WHEN** the user drops a 12 MB PNG, or one 9000 pixels wide
- **THEN** the message gives the limit that was exceeded, and the card is unchanged

#### Scenario: Large but valid
- **WHEN** the user chooses a transparent 2000×1000 PNG
- **THEN** MeowTab stores a 1024×512 copy with the same transparency

### Requirement: MeowTab keeps its own copy
An accepted picture SHALL be saved as a new file in `~/Library/Application Support/MeowTab/images/` before the setting points at it. The previous file SHALL be deleted only after that. If saving fails, the previous picture SHALL stay in use, and the message line SHALL explain the failure.

#### Scenario: Original moved
- **WHEN** the user moves or deletes the original file after choosing it
- **THEN** the picture still shows, including after relaunching MeowTab

#### Scenario: Saving fails
- **WHEN** the pictures folder can't be written
- **THEN** the card and the peek keep the previous picture, and the message says the picture couldn't be saved

### Requirement: Where MeowTab keeps its data
Settings SHALL be stored as `meowtab.*` keys in MeowTab's own preferences domain (`io.github.tingtmu.meowtab.macos`), and pictures in `~/Library/Application Support/MeowTab/images/`. Both SHALL survive replacing the app. MeowTab SHALL never write to the app bundle, AltTab's data or Windows MeowTab's files. Restore defaults SHALL reset the `meowtab.*` settings and delete only MeowTab's own picture files.

#### Scenario: Replacing the app
- **WHEN** the user replaces `MeowTab.app` with a newer build
- **THEN** their pictures and MeowTab settings are still in use

#### Scenario: Restore defaults
- **WHEN** the user clicks Restore defaults
- **THEN** the shipped cats, thresholds 3 and 8 and heights 80 % and 95 % are back, and no file outside MeowTab's own `<mood>-<id>.png` pictures is touched

### Requirement: Tests leave real data alone
Automated tests SHALL use a temporary preferences suite and a temporary folder, and SHALL NOT read or change the user's MeowTab settings or pictures.

#### Scenario: Running the tests on a configured machine
- **WHEN** the unit tests run where MeowTab has custom pictures and settings
- **THEN** those settings and files are unchanged afterwards
