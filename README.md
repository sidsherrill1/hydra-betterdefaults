# default-credentials-scanner

Small helper to run **THC-Hydra** with SecLists **`*betterdefaultpasslist*`** combo files (under `Passwords/Default-Credentials`) against a host list.

## Requirements

- Kali (or similar) with `hydra` and SecLists at `/usr/share/seclists/...`

## Install

Put the script somewhere on your `PATH` (for example `/usr/local/bin`):

```bash
chmod +x hydra-betterdefaults.sh
sudo mv hydra-betterdefaults.sh /usr/local/bin/
```

Alternatively use `~/bin` or another directory that is already listed in `PATH`.

## Usage

```bash
hydra-betterdefaults.sh [options] targets.txt
```

From a clone without installing, run `./hydra-betterdefaults.sh` instead.

### `targets.txt`

Hydra’s `-M` format: one target per line—IP or hostname, optional `:port` when the service is not on its default.

```
192.168.1.50
scanner.lab.local
203.0.113.7
10.0.0.12:2222
```

Avoid blank lines and extra text on each line. See `hydra-betterdefaults.sh --help` for `-d` (dry-run), `-o` (output dir), `-e` (extra hydra args), and env vars.

### `[ERROR] children crashed! (N)` from Hydra

That message is printed when a **Hydra worker process hits SIGSEGV** (segmentation fault). The number in parentheses is the **parallel worker index** (slot), not “how many” children died. It usually comes from **Hydra bugs or overload** when many connections run at once (large `-t`, many targets, finicky modules), not from a single bad line in `targets.txt`.

**Mitigations:** use fewer parallel tasks (`HYDRA_TASKS=2` or `-e "-t 2"`; this script defaults to `HYDRA_TASKS=4`), upgrade Hydra from your distro, or split targets into smaller runs. The script logs a short warning and continues when a hydra run exits non-zero; check the final summary line for how many runs failed.

Use only on systems you are authorized to test.
