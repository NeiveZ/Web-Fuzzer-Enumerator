# WFEX

> Web Fuzzer & Enumerator — clean directory and file discovery for authorized web assessments.

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Category](https://img.shields.io/badge/Category-Web%20Fuzzing-ef4444?style=flat-square)
![Status](https://img.shields.io/badge/Interface-Direct%20CLI-brightgreen?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

---

## Overview

WFEX performs web content discovery using wordlists and extension fuzzing.

It is designed for controlled, authorized environments and uses a clean table output instead of noisy mixed progress lines.

WFEX can identify directories, files, and potentially sensitive file extensions such as `.bak`, `.old`, `.env`, `.sql`, `.zip`, and `.log`.

---

## Features

- Directory discovery.
- File extension fuzzing.
- Sensitive file labeling.
- Custom status code filtering.
- Threaded requests.
- Delay support without requiring `bc`.
- HTTPS to HTTP fallback when enabled.
- Clean table output.
- Raw output mode if desired.
- Output file support.

---

## Installation

```bash
git clone https://github.com/NeiveZ/WFEX.git
cd WFEX
chmod +x wfex.sh
```

Validate:

```bash
./wfex.sh --check
```

Dependencies:

```bash
sudo apt update
sudo apt install curl -y
```

---

## Usage

```bash
./wfex.sh -u <url> [options]
```

Help:

```bash
./wfex.sh --help
```

---

## Basic Examples

### Scan with a wordlist

```bash
./wfex.sh -u http://example.com -w /usr/share/wordlists/dirb/common.txt
```

### Use more threads

```bash
./wfex.sh -u http://example.com -w /usr/share/wordlists/dirb/big.txt -t 50
```

### Add delay

```bash
./wfex.sh -u http://example.com -w wordlist.txt -d 250
```

### Directories only

```bash
./wfex.sh -u http://example.com -w wordlist.txt --dirs-only
```

### Files only

```bash
./wfex.sh -u http://example.com -w wordlist.txt --files-only
```

### Custom extensions

```bash
./wfex.sh -u http://example.com -w wordlist.txt -e php,html,txt,bak,env
```

### Custom codes

```bash
./wfex.sh -u http://example.com -w wordlist.txt -c 200,204,301,302,403
```

---

## Clean Output

```text
TYPE        CODE  SIZE      RISK    URL
----------- ----- --------- ------  -----------------------------------------
DIR         200   1024      INFO    http://example.com/admin/
FILE        200   2048      LOW     http://example.com/login.php
SENSITIVE   403   300       HIGH    http://example.com/.env
```

---

## Reports

Save results:

```bash
./wfex.sh -u http://example.com -w wordlist.txt -o reports/wfex-results.txt
```

Disable progress for clean logs:

```bash
./wfex.sh -u http://example.com -w wordlist.txt --no-progress -o reports/wfex.txt
```

---

## Recommended Procedure

1. Start with a small wordlist:

```bash
./wfex.sh -u http://example.com -w /usr/share/wordlists/dirb/small.txt
```

2. Review 403 and sensitive hits.

3. Increase coverage:

```bash
./wfex.sh -u http://example.com -w /usr/share/wordlists/dirb/big.txt -t 50
```

4. Export the final result:

```bash
./wfex.sh -u http://example.com -w /usr/share/wordlists/dirb/big.txt --no-progress -o reports/example_wfex.txt
```

---

## Safety Notes

Avoid high thread counts on fragile systems. Use delay when testing production systems with permission.

---

## License

MIT License.
