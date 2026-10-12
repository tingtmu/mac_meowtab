# Spec Delta

## Purpose

The mood picture that peeks over the switcher's top-left edge: which picture shows, how high it rises, where it sits, when it shows, and what it may cost.

## ADDED Requirements

### Requirement: Count the real windows the switcher lists
The count SHALL be the number of real windows the switcher lists before any search query is applied, scrolled-out tiles included. App-only placeholder tiles SHALL NOT count, and a group of tabs SHALL count once while the switcher groups tabs, as it does by default. With a count of zero the picture SHALL be hidden, and the placeholder tiles SHALL work as upstream.

#### Scenario: Scrolled grid with placeholders
- **WHEN** the switcher lists ten real windows and two app-only placeholders, and six tiles are in view
- **THEN** the count is ten

#### Scenario: Typing a search
- **WHEN** a search narrows the ten listed windows to two tiles
- **THEN** the count stays ten and the picture doesn't change

#### Scenario: Only placeholders
- **WHEN** the switcher lists app-only placeholders and no real window
- **THEN** no picture shows, and the placeholders can still be selected

### Requirement: Three moods
The picture SHALL be few's below `someFrom`, some's from `someFrom` to `manyFrom - 1`, and many's from `manyFrom` on, with defaults 3 and 8. Moving the selection SHALL NOT change the mood or the height.

#### Scenario: Default boundaries
- **WHEN** the count is 2, 3, 7 or 8
- **THEN** the mood is few, some, some or many respectively

#### Scenario: Custom thresholds
- **WHEN** `someFrom` is 2, `manyFrom` is 4, and the count is 1, 2 or 4
- **THEN** the mood is few, some or many respectively

### Requirement: Peek height follows the count
The share of the picture's art shown above the pane SHALL be `minShare + (maxShare - minShare) * clamp((n - 1) / (manyFrom + 3), 0, 1)`, with defaults 0.80 and 0.95. Art SHALL mean rows with alpha above 24, so transparent padding above the art always shows and padding below it never adds height.

#### Scenario: Default range
- **WHEN** the count is 1, 12 or 20 with default settings
- **THEN** 80 %, 95 % and 95 % of the art shows above the pane

#### Scenario: Padded picture
- **WHEN** a 512×512 picture has art only in rows 200–312 and the share is 0.80
- **THEN** the rows above the pane are 200 + 0.80 × 112 ≈ 290 picture rows, scaled to the display size

### Requirement: Where the picture sits
The picture SHALL keep its aspect ratio within a 160-point box. Its visible part SHALL sit with its bottom on the straight part of the pane's top edge, starting 24 points in from the pane's left edge, or as far in as the pane's corner radius if that is larger. On a pane too narrow for that, the picture SHALL be scaled down to end as far from the pane's right edge as it starts from the left. The rest SHALL be cut off at the pane's top edge, never drawn over the pane.

#### Scenario: Two displays with different scales
- **WHEN** the switcher opens on a Retina display and then on a non-Retina one
- **THEN** each time the picture is sharp and aligned with the pane's top-left edge

#### Scenario: Rounded corners and a narrow pane
- **WHEN** the pane's corners have a radius of 43 points, or the pane is 132 points wide with 23-point corners
- **THEN** the picture starts 43 points in, or is scaled down to 84 points wide between 24-point margins, and none of it hangs past the straight part of the pane's top edge

### Requirement: Room for the peek
The picture's top SHALL stay at least 12 points below the top of the display's usable area, which excludes the menu bar and the Dock. The pane SHALL leave room for the tallest peek of the three moods at `maxShare`, and that room SHALL NOT change while the switcher is open. The picture SHALL be scaled down only as far as needed to keep that room within 30 % of the usable height.

#### Scenario: Thirty windows on a laptop display
- **WHEN** the switcher opens with 30 windows on a display whose usable area is 875 points tall
- **THEN** the pane's grid scrolls rather than grows, and the whole visible part of the picture is inside the usable area

#### Scenario: Very short usable area
- **WHEN** the usable area is 400 points tall
- **THEN** the picture is scaled so the reserved room is at most 120 points, and its visible part is still fully on screen

#### Scenario: A window closes while the switcher is open
- **WHEN** closing a window changes the mood or the peek height
- **THEN** the reserved room is unchanged, and the new picture sits on the pane's new top edge

### Requirement: The peek follows the pane
The picture SHALL appear when the pane appears, and SHALL disappear as soon as the pane starts to hide, whether by committing a selection, by Esc, or by a click elsewhere. It SHALL never become key or main, SHALL let mouse clicks through, and SHALL NOT be an accessibility element or a tile in the switcher.

#### Scenario: Cancel and reopen quickly
- **WHEN** the user presses Esc and reopens the switcher within the fade-out
- **THEN** the new session shows its own correct picture, and no old picture remains

#### Scenario: Clicking where the picture is
- **WHEN** the user clicks on the picture while the switcher is open
- **THEN** the picture doesn't take the click: it counts as a click outside the pane, as if the picture weren't there

#### Scenario: VoiceOver
- **WHEN** VoiceOver moves through the open switcher
- **THEN** it never lands on the picture

### Requirement: Static pictures, cheap to show
The MVP SHALL show static pictures only. Pictures SHALL be decoded at launch and when a picture setting changes, and never while the switcher is open. A picture saved while it is open SHALL be used from the next session. One peek panel SHALL be created at launch and reused. No timer or recurring work SHALL exist for the peek. A selection step SHALL cost the peek no more than comparing the count and the pane frame. Each peek update SHALL log its duration for the acceptance run.

#### Scenario: Measuring on a real Mac
- **WHEN** the tester opens the switcher 20 times with about 10 windows and reads the peek log
- **THEN** the median `update` time is at most 1 ms, and the maximum is reported

#### Scenario: Damaged saved picture
- **WHEN** a saved custom picture can't be loaded at launch
- **THEN** that mood shows the shipped cat, the MeowTab settings section explains why, and switching works normally
