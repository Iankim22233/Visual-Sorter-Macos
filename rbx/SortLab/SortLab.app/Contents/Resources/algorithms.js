// SortLab algorithms. Edit this file, then switch back to the SortLab window:
// it reloads automatically and new algorithms show up in the picker.
//
// Each algorithm is registered with a name and a function that receives `s`:
//
//   s.n               number of lines
//   s.get(i)          read line i's value (1..n)                      [highlighted + sounds]
//   s.set(i, v)       write value v into slot i                       [counts as a write]
//   s.swap(i, j)      swap two slots                                  [counts as 2 writes]
//   s.less(i, j)      s[i] < s[j]                                     [counts as a comparison]
//   s.greater(i, j)   s[i] > s[j]                                     [counts as a comparison]
//   s.lessV(i, v)     s[i] < v        (compare a slot with a value)   [counts as a comparison]
//   s.greaterV(i, v)  s[i] > v                                        [counts as a comparison]
//   s.copy()          plain array copy of current values (free: no sound, not animated)
//
// Everything that goes through `s` is animated and played as a tone, in order.
// Use plain JS for anything else (temp arrays, recursion, etc).
// Runs are capped at 3,000,000 steps, so infinite sorts (like bogo) just get cut off.

register("Bubble Sort", s => {
  for (let i = 0; i < s.n - 1; i++) {
    let swapped = false;
    for (let j = 0; j < s.n - 1 - i; j++) {
      if (s.less(j + 1, j)) { s.swap(j, j + 1); swapped = true; }
    }
    if (!swapped) break;
  }
});

register("Cocktail Shaker Sort", s => {
  let lo = 0, hi = s.n - 1;
  while (lo < hi) {
    for (let i = lo; i < hi; i++) if (s.less(i + 1, i)) s.swap(i, i + 1);
    hi--;
    for (let i = hi - 1; i >= lo; i--) if (s.less(i + 1, i)) s.swap(i, i + 1);
    lo++;
  }
});

register("Odd-Even Sort", s => {
  let sorted = false;
  while (!sorted) {
    sorted = true;
    for (let phase = 0; phase < 2; phase++) {
      for (let i = phase; i < s.n - 1; i += 2) {
        if (s.less(i + 1, i)) { s.swap(i, i + 1); sorted = false; }
      }
    }
  }
});

register("Comb Sort", s => {
  let gap = s.n, swapped = true;
  while (gap > 1 || swapped) {
    gap = Math.max(1, Math.floor(gap / 1.3));
    swapped = false;
    for (let i = 0; i + gap < s.n; i++) {
      if (s.less(i + gap, i)) { s.swap(i, i + gap); swapped = true; }
    }
  }
});

register("Gnome Sort", s => {
  let i = 0;
  while (i < s.n) {
    if (i === 0) { i++; continue; }
    if (s.less(i, i - 1)) { s.swap(i, i - 1); i--; } else i++;
  }
});

register("Selection Sort", s => {
  for (let i = 0; i < s.n - 1; i++) {
    let m = i;
    for (let j = i + 1; j < s.n; j++) if (s.less(j, m)) m = j;
    s.swap(i, m);
  }
});

register("Insertion Sort", s => {
  for (let i = 1; i < s.n; i++) {
    const key = s.get(i);
    let j = i - 1;
    while (j >= 0 && s.greaterV(j, key)) {
      s.set(j + 1, s.get(j));
      j--;
    }
    s.set(j + 1, key);
  }
});

register("Binary Insertion Sort", s => {
  for (let i = 1; i < s.n; i++) {
    const key = s.get(i);
    let lo = 0, hi = i;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (s.lessV(mid, key)) lo = mid + 1; else hi = mid;
    }
    for (let j = i; j > lo; j--) s.set(j, s.get(j - 1));
    s.set(lo, key);
  }
});

register("Shell Sort", s => {
  for (let gap = s.n >> 1; gap > 0; gap >>= 1) {
    for (let i = gap; i < s.n; i++) {
      const key = s.get(i);
      let j = i;
      while (j >= gap && s.greaterV(j - gap, key)) {
        s.set(j, s.get(j - gap));
        j -= gap;
      }
      s.set(j, key);
    }
  }
});

register("Merge Sort", s => {
  function sort(lo, hi) {
    if (hi <= lo) return;
    const mid = (lo + hi) >> 1;
    sort(lo, mid);
    sort(mid + 1, hi);
    const a = s.copy();
    const left = a.slice(lo, mid + 1), right = a.slice(mid + 1, hi + 1);
    let i = 0, j = 0, k = lo;
    while (i < left.length || j < right.length) {
      if (j >= right.length || (i < left.length && left[i] <= right[j])) s.set(k++, left[i++]);
      else s.set(k++, right[j++]);
    }
  }
  sort(0, s.n - 1);
});

register("Quick Sort", s => {
  function sort(lo, hi) {
    if (lo >= hi) return;
    s.swap((lo + hi) >> 1, hi);
    const pivot = s.get(hi);
    let p = lo;
    for (let j = lo; j < hi; j++) {
      if (s.lessV(j, pivot)) s.swap(p++, j);
    }
    s.swap(p, hi);
    sort(lo, p - 1);
    sort(p + 1, hi);
  }
  sort(0, s.n - 1);
});

register("Heap Sort", s => {
  function sift(start, end) {
    let root = start;
    while (2 * root + 1 <= end) {
      let child = 2 * root + 1;
      if (child + 1 <= end && s.less(child, child + 1)) child++;
      if (!s.less(root, child)) return;
      s.swap(root, child);
      root = child;
    }
  }
  for (let start = (s.n - 2) >> 1; start >= 0; start--) sift(start, s.n - 1);
  for (let end = s.n - 1; end > 0; end--) {
    s.swap(0, end);
    sift(0, end - 1);
  }
});

register("Radix Sort (LSD)", s => {
  for (let exp = 1; Math.floor(s.n / exp) > 0; exp *= 10) {
    const buckets = Array.from({ length: 10 }, () => []);
    for (const v of s.copy()) buckets[Math.floor(v / exp) % 10].push(v);
    let k = 0;
    for (const b of buckets) for (const v of b) s.set(k++, v);
  }
});

register("Cycle Sort", s => {
  const position = (item, start) => {
    let pos = start;
    for (let i = start + 1; i < s.n; i++) if (s.lessV(i, item)) pos++;
    return pos;
  };
  for (let start = 0; start < s.n - 1; start++) {
    let item = s.get(start);
    let pos = position(item, start);
    if (pos === start) continue;
    let t = s.get(pos); s.set(pos, item); item = t;
    while (pos !== start) {
      pos = position(item, start);
      t = s.get(pos); s.set(pos, item); item = t;
    }
  }
});

register("Pancake Sort", s => {
  const flip = k => { for (let i = 0, j = k; i < j; i++, j--) s.swap(i, j); };
  for (let size = s.n; size > 1; size--) {
    let m = 0;
    for (let i = 1; i < size; i++) if (s.less(m, i)) m = i;
    if (m === size - 1) continue;
    if (m !== 0) flip(m);
    flip(size - 1);
  }
});

register("Stooge Sort", s => {
  function sort(lo, hi) {
    if (s.less(hi, lo)) s.swap(lo, hi);
    if (hi - lo + 1 > 2) {
      const t = Math.floor((hi - lo + 1) / 3);
      sort(lo, hi - t);
      sort(lo + t, hi);
      sort(lo, hi - t);
    }
  }
  sort(0, s.n - 1);
});

register("Bogo Sort (good luck)", s => {
  const sorted = () => { const a = s.copy(); for (let i = 1; i < a.length; i++) if (a[i - 1] > a[i]) return false; return true; };
  while (!sorted()) {
    for (let i = s.n - 1; i > 0; i--) s.swap(i, Math.floor(Math.random() * (i + 1)));
  }
});

// ---- Your own: copy this template ----
// register("My Sort", s => {
//   for (let i = 0; i < s.n; i++) { ... }
// });
