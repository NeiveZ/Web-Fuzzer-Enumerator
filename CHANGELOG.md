# Changelog

## 3.2.9
- Separated live Directory and File findings into distinct framed sections.
- Added section borders before and after each discovery phase.
- Kept default progress and summary hidden.

## 3.2.5 — Clean Table Refinement

- Removed duplicate phase headers from the default discovery output.
- Kept the terminal focused on individual findings and the final phase transition.
- Improved banner alignment so the WFEX identity starts consistently inside the bordered frame.
- Changed `Directory Found` and `File Found` labels to dark blue.
- Highlighted discovered paths in yellow.
- Kept progress and summary disabled by default to preserve a clean CLI.


## 3.2.4 — Clean Table CLI

- Reworked the normal terminal presentation into bordered, table-like sections.
- Replaced the previous Unicode separator style with explicit `|-----|` separators and side borders.
- Added a subtle red blink effect to section separators when ANSI blink is supported.
- Kept the WFEX identity as the primary visual element of the startup screen.
- Removed the progress bar from normal output; `--progress` is now opt-in.
- Removed the end-of-scan summary from normal output; `--summary` is now opt-in.
- Kept the final results table opt-in to avoid duplicate presentation.
- Preserved the original project default of 20 threads, 8s timeout and 0 retries.
- Kept directory and file discovery as independent visual phases.
- Kept 403 and 404 hidden by default and 301/302 optional.
- Kept User-Agent rotation automatic so the primary command remains short.
- Updated the README to document the cleaner presentation and optional progress/summary modes.
- Updated the test suite for the new default output contract.

## 3.2.3 — Precision & Phased CLI

- Restored the conservative default concurrency from the original project: 20 threads and 8s timeout.
- Added a standard profile matching the default execution model.
- Directory discovery and file discovery now run as separate phases.
- Results are displayed under distinct `Directories Found` and `Files Found` sections.
- Added red phase dividers with a subtle terminal blink effect where supported.
- Kept the progress bar active throughout each phase.
- Kept the final table opt-in so live findings are not duplicated.
- Expanded the built-in wordlist with additional common web-content names.
- Kept User-Agent rotation internal and automatic.
- Kept the short target-first syntax as the primary interface.
