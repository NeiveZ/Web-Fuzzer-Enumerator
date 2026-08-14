# WFEX — Web Fuzzer & Enumerator eXtended

> Bash-first web content discovery for authorized security testing, labs and portfolio demonstrations.

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![CLI](https://img.shields.io/badge/CLI-Clean%20Professional-ef4444?style=flat-square)
![Focus](https://img.shields.io/badge/Focus-Web%20Content%20Discovery-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

## Identity

**WFEX** means **Web Fuzzer & Enumerator eXtended**.

WFEX is intentionally written in **Bash** and follows the same principle that guides the rest of the project's interface work:

> **Less decorative information, more identity, and a terminal that looks like a professional security utility.**

The normal command is deliberately short and target-first:

```bash
./wfex.sh https://example.com
```

User-Agent rotation is automatic. Threads, timeout and retry controls remain available for advanced tuning, but they are not required for normal execution.

---

# Version 3.2.9

WFEX 3.2.5 is a **clean, precision-oriented CLI release**. The main visual change is that the normal terminal output is now presented as a set of compact bordered sections instead of a stream of diagnostics.

The default screen intentionally avoids two types of noise:

- the live percentage/progress bar;
- the end-of-scan summary with repeated counters.

The scan instead reads as a compact sequence:

```text
WFEX identity
    ↓
Scan configuration
    ↓
Directories Found
    ↓
Files Found
    ↓
End
```

The progress bar and summary are still available as optional advanced display modes with `--progress` and `--summary`.

---

# Visual Design

The normal screen uses fixed-width terminal sections with red separators and side borders. On terminals that support ANSI blink, the red separators use a subtle blink effect.

Example layout:

```text
|---------------------------------------------------------------------|
|                         WFEX                                      |
|           Web Fuzzer & Enumerator eXtended                        |
|---------------------------------------------------------------------|
|                         Scan configuration                         |
| Target            | https://example.com                            |
| WebServer         | Apache/2.4.7                                  |
| Technology        | PHP/5.5.9                                      |
| Wordlist          | built-in (160 candidates)                      |
| Extensions        | php                                             |
| Mode              | directories + files                            |
|---------------------------------------------------------------------|
|                       Directories Found                            |
| Directory Found   | https://example.com/admin/                      |
| Directory Found   | https://example.com/uploads/                    |
| Directory Found   | https://example.com/css/                        |
|---------------------------------------------------------------------|
|                          Files Found                               |
| File Found        | https://example.com/login.php                   |
| File Found        | https://example.com/home.php                    |
|---------------------------------------------------------------------|
```

The intention is to make the output understandable at a glance without forcing the user to parse internal execution counters.

---

# Quick Usage

### Directories only

```bash
./wfex.sh https://example.com
```

### Directories + one extension

```bash
./wfex.sh https://example.com php
```

### Directories + multiple extensions

```bash
./wfex.sh https://example.com php,txt,js
```

### Custom wordlist

```bash
./wfex.sh https://example.com /usr/share/wordlists/dirb/common.txt
```

### Custom wordlist + extension

```bash
./wfex.sh https://example.com /usr/share/wordlists/dirb/common.txt php
```

This short positional syntax is the preferred interface.

---

# Directory and File Organization

When an extension is supplied, WFEX always scans in two distinct phases:

```text
Directories Found
    ↓
Files Found
```

A directory hit is reported as:

```text
Directory Found   | https://example.com/admin/
```

A file hit is reported as:

```text
File Found        | https://example.com/login.php
```

Sensitive file types are still classified internally and can be highlighted when a matching file is returned.

This separation avoids the mixed output common to simple Bash fuzzers and makes the result easier to read during a live demonstration.

---

# HTTP Status Behavior

The default visible status is deliberately conservative:

```text
200  → shown
403  → hidden
404  → hidden
```

Redirects can be enabled with one short option:

```bash
./wfex.sh https://example.com --redirects
```

This adds 301 and 302 results to the visible findings.

Exact matching is still available:

```bash
./wfex.sh https://example.com --match 200,301,302
```

---

# User-Agent Behavior

User-Agent rotation is automatic. The normal command does not require a User-Agent option:

```bash
./wfex.sh https://example.com
```

WFEX selects from a small internal browser-oriented pool on requests. An external list or fixed value remains available for compatibility, but it is intentionally not part of the primary workflow.

This behavior is intended for authorized testing where request headers are part of the test conditions. It is not intended to bypass access controls or authorization.

---

# Performance and Precision

The original project default is preserved:

```text
Threads   20
Timeout   8s
Retries   0
Delay     0ms
```

The default is intentionally moderate rather than maximizing request throughput. In addition to reducing unnecessary load, this keeps the normal behavior predictable.

Advanced profiles remain available:

```bash
./wfex.sh https://example.com --profile standard
./wfex.sh https://example.com --profile fast
./wfex.sh https://example.com --profile balanced
./wfex.sh https://example.com --profile accurate
```

| Profile | Threads | Timeout | Retries | Delay |
|---|---:|---:|---:|---:|
| standard | 20 | 8s | 0 | 0ms |
| fast | 32 | 5s | 0 | 0ms |
| balanced | 20 | 8s | 0 | 0ms |
| accurate | 12 | 10s | 1 | 25ms |

Manual overrides are still available when a controlled test requires them:

```bash
./wfex.sh https://example.com --threads 12 --timeout 8 --retries 1
```

The important part is that ordinary use does not require knowing any of these tuning controls.

---

# Progress and Summary Modes

The normal interface intentionally hides scan counters so that the screen remains clean.

Progress can be requested when you need it:

```bash
./wfex.sh https://example.com --progress
```

The traditional end-of-scan counters can also be requested:

```bash
./wfex.sh https://example.com --summary
```

Both can be enabled together:

```bash
./wfex.sh https://example.com --progress --summary
```

The optional final results table remains available with:

```bash
./wfex.sh https://example.com --table
```

or:

```bash
./wfex.sh https://example.com --no-live
```

This keeps the primary interactive output free from duplicate result presentation.

---

# File Discovery

A path-only scan remains fast because WFEX does not multiply every word by an extension list unless you ask for file discovery.

For example:

```bash
./wfex.sh https://example.com
```

is a path scan.

Whereas:

```bash
./wfex.sh https://example.com php
```

adds PHP file candidates after the directory phase.

Multiple extensions are supported:

```bash
./wfex.sh https://example.com php,js,json,bak,env
```

---

# Wordlists

Any readable wordlist can be supplied directly:

```bash
./wfex.sh https://example.com ~/wordlists/custom.txt
```

WFEX removes blank lines, comments and duplicate entries before generating requests.

Installed wordlists can also be managed with:

```bash
./wfex.sh wordlists list
./wfex.sh wordlists install ./my-list.txt
```

---

# Environment Check

Verify the environment with:

```bash
./wfex.sh check
```

The check validates the Bash script syntax and required command-line dependencies, with curl version information where available.

---

# Reports

A complete raw report can be written without changing the normal terminal presentation:

```bash
./wfex.sh https://example.com -o reports/example.tsv
```

The report contains the URL, HTTP code, response size, redirect destination and classification for each visible finding.

---

# Project Structure

```text
Web-Fuzzer-Enumerator/
├── wfex.sh
├── README.md
├── CHANGELOG.md
├── SECURITY.md
├── ETHICS.md
├── LICENSE
└── tests/
    └── test_wfex.sh
```

The implementation remains Bash-only.

---

# Portfolio Positioning

WFEX is designed to demonstrate more than a working HTTP loop. The project emphasizes:

- Bash scripting and robust CLI handling;
- controlled parallel HTTP requests with curl;
- wordlist normalization and request generation;
- clean terminal UX;
- directory/file result separation;
- HTTP status filtering;
- automatic User-Agent rotation;
- optional reports and advanced execution tuning;
- defensive error handling and repeatable tests.

The interface is intentionally different from the author's ORFX project so each tool keeps its own identity.

---

# Ethical Use

Use WFEX only against systems you own or systems for which you have explicit authorization to test.

For the project's intended scope and restrictions, see:

- `ETHICS.md`
- `SECURITY.md`

---

# License

MIT License. Copyright (c) NeiveZ.

## Output layout

Directory and file findings are rendered in separate framed sections. Progress and summary remain opt-in.

## Clean Output Layout

The default interactive output intentionally keeps the discovery stream minimal. Directory and file findings use one fixed separator format throughout the interface:

```text
|-----------------------------------------------------------------------|
 Directory Found: http://target.example/admin/
 Directory Found: http://target.example/uploads/
|-----------------------------------------------------------------------|
 File Found:      http://target.example/login.php
 File Found:      http://target.example/index.php
|-----------------------------------------------------------------------|
```

The standard run does not print the progress bar, request counters, elapsed time, or a duplicated final results table. Those details remain available through the optional `--progress`, `--summary`, and `--table` flags.
