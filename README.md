# SortLab

A macOS sorting visualizer with sound. Watch sorting algorithms work on a field of lines, hear each step as a short sine tone (taller line = higher pitch), or sort the lines yourself by dragging them. Algorithms are written in JavaScript and can be added or edited inside the app.

## Features

- **17 built-in algorithms:** Bubble, Cocktail Shaker, Odd-Even, Comb, Gnome, Selection, Insertion, Binary Insertion, Shell, Merge, Quick, Heap, Radix (LSD), Cycle, Pancake, Stooge and Bogo.
- **Sound:** every compare, swap or write plays a short sine blip. Pitch follows the line's height (about 150 Hz to 2400 Hz). Volume slider and mute button.
- **Choose how many lines:** 4 to 1000.
- **Scramble:** animated shuffle, so you can sort again and again.
- **Speed:** 5 to 10,000 steps per second.
- **Visual styles:** Bars, Dots, Line and Pie (each slice is a line, coloured by value). A Rainbow toggle switches colour on and off.
- **Manual sort:** click a line, drag it somewhere else and drop it. A live preview shows the result while you drag, and you get a green sweep when you finish in order.
- **Tabs and a menu:** one tab per algorithm, plus a dropdown menu to select or create one.
- **Built-in code editor:** write your own algorithms in JavaScript without rebuilding the app.
- **Stats:** live comparison and write counters (moves in manual mode).

## Requirements

- macOS 13 or later to **run**
- Xcode / Swift toolchain (Swift 5.9+) **to build** not **run**

## Build and run

```bash
cd SortLab
./build.sh run
```
## Install
```bash 
cd ~/Downloads
git clone https://github.com/Iankim22233/Visual-Sorter-Macos/
cd Visual-Sorter-Macos/SortLab
./build.sh
rm -rf /Applications/SortLab.app
mv SortLab.app /Applications/
open /Applications/SortLab.app
```
A permission denied is normal if you don't want to build the app using xCode.
The app should show up in applications. If you can't find it, use spotlight and search Sortlab.

`build.sh` runs `swift build -c release`, assembles `SortLab.app` next to the script, and ad-hoc signs it. Leave out `run` to only build, then open `SortLab.app` yourself.

## Using the app

| Control | What it does |
| --- | --- |
| Tab strip / algorithm menu | Choose the algorithm. **+** or *New Algorithm…* creates one. |
| Style | Bars, Dots, Line or Pie. |
| Scramble | Shuffle the lines. |
| Sort / Stop | Run the chosen algorithm. Esc also stops. |
| Manual sort | Toggle drag-and-drop sorting by hand. |
| Reset | Put the lines back in order. |
| Edit Code… | Open the algorithm editor. |
| Lines / Speed / volume | Number of lines, steps per second and sound level. |

## Writing your own algorithm

1. Click the **+** on the tab strip (or *New Algorithm…* in the menu). The editor opens on a template with the name selected, so type to rename it.
2. Replace the code with your own.
3. Press **⌘S** (Save & Apply). It then shows up in the picker. A red bar shows any error.
4. Pick it, **Scramble**, then **Sort**.

Example (selection sort):

```js
register("My Selection", s => {
  for (let i = 0; i < s.n - 1; i++) {
    let min = i;
    for (let j = i + 1; j < s.n; j++) {
      if (s.less(j, min)) min = j;
    }
    s.swap(i, min);
  }
});
```

### The `s` object

| Call | Meaning | Counted as |
| --- | --- | --- |
| `s.n` | number of lines | |
| `s.get(i)` | read the value in slot `i` (1..n) | |
| `s.set(i, v)` | write value `v` into slot `i` | 1 write |
| `s.swap(i, j)` | swap two slots | 2 writes |
| `s.less(i, j)` | `slot i < slot j` | 1 comparison |
| `s.greater(i, j)` | `slot i > slot j` | 1 comparison |
| `s.lessV(i, v)` | `slot i < v` | 1 comparison |
| `s.greaterV(i, v)` | `slot i > v` | 1 comparison |
| `s.copy()` | plain array of the current values (free, not animated) | |

Everything that goes through `s` is highlighted, played as a tone and animated, in order. Use plain JavaScript for anything else (temporary arrays, recursion and so on).

### How it runs

The JavaScript runs first (on a background thread, using JavaScriptCore) and records every step. The app then plays those steps back at the speed you chose. That means:

- Runs are capped at **3,000,000 steps**. Algorithms that never finish, like Bogo, are cut off and a message says so.
- A big sort can take a moment (for example about 0.6 s for Bubble at 1000 lines) before the animation starts.
- Errors in your script and out-of-range indexes show a message instead of crashing the app.
- Your algorithm must really leave the lines sorted. The final green sweep plays either way, so if the bars aren't in order when it plays, the algorithm has a bug.

## Where things are stored

Each algorithm is one file in:

```
~/Library/Application Support/SortLab/algorithms/
```

Files are named like `003 Comb Sort.js` and are listed in filename order. The algorithm's display name comes from its `register("…")` call, not the file name. Use **More → Show Files in Finder** in the editor to open the folder, and **More → Restore Missing Built-in Algorithms** to bring back any built-in you deleted. The built-in sources ship inside the app from `algorithms.js`.

## Project layout

```
SortLab/
 >Package.swift
 build.sh                     build + bundle + sign
 algorithms.js                built-in algorithms (copied into the app)
 Sources/SortLab/
     >SortLabApp.swift         app entry, main window + editor window
     ContentView.swift        canvas drawing, drag gesture, controls, tab strip
     EditorView.swift         tabbed code editor
     SortModel.swift          state, playback pacing, manual sort
     ScriptEngine.swift       JavaScriptCore bridge, step recording
     AlgorithmStore.swift     one-file-per-algorithm storage
     Synth.swift              sine audio engine
```

## Notes

- The app is only ad-hoc signed, so on another Mac you may need to right-click → Open the first time.
- Changing the number of lines stops any run and resets the lines.
