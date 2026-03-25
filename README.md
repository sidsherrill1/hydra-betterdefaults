# hydra-betterdefaults

Small helper to run **THC-Hydra** with SecLists **`*betterdefaultpasslist*`** combo files (under `Passwords/Default-Credentials`) against a host list.

## Requirements

- Kali (or similar) with `hydra` and SecLists at `/usr/share/seclists/...`

## Install

Put the script somewhere on your `PATH` (for example `/usr/local/bin`):

```bash
git clone https://github.com/sidsherrill1/hydra-betterdefaults.git && cd hydra-betterdefaults
chmod +x hydra-betterdefaults.sh
sudo mv hydra-betterdefaults.sh /usr/local/bin/hydra-betterdefaults
```

Alternatively use `~/bin` or another directory that is already listed in `PATH`.

## Usage

```bash
hydra-betterdefaults.sh [options] targets.txt
```

From a clone without installing, run `./hydra-betterdefaults.sh` instead.

`targets.txt`: one IP or hostname per line (optional `host:port`). See `hydra-betterdefaults.sh --help` for `-d` (dry-run), `-o` (output dir), `-e` (extra hydra args), and env vars.

Use only on systems you are authorized to test.
