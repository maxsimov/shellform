# Shellform

Shellform is a tiny Bash DSL for declarative blocks:

```bash
configure <service>
  <option> arg1 arg2 ...
  ...
end
```

It wires your **provider** (a Bash file that defines functions) into this DSL and runs your logic with strict error handling, logs, and a summary.

---

# How it works (engine)

- Shellform is initialized from `shellform.sh` (strict mode: `set -euo pipefail`, `errtrace`).
- `configure <service>` starts a block for that service.
- Shellform **requires** `<service>_spec` and **calls it once** to learn which options exist.
- For each named option, Shellform:
  - Creates a **temporary function** named exactly like the option (e.g. `install`, `venv`).
  - Captures every call’s arguments in an internal array.
  - If your provider defines `<service>_<option>_item`, it is called **immediately** for that line.
- On `end`, for each option used in the block:
  - If your provider defines `<service>_<option>_group`, Shellform calls it **once**, passing **all** collected args.
  - Temporary option functions and arrays are removed.
- All commands invoked via the engine’s `shellform_run` are logged to `./logs/…` with success/failure markers.
- Any **unhandled** non-zero exit will stop the run (fatal).

---

# What a provider must implement

At minimum, **every provider** must export:

## 1) `<service>_spec`
Returns the list of option names (space-separated) that your service supports.

```bash
# Example
uv_spec() {
  echo "venv install"
}
```

Notes:
- Option names must be **simple Bash identifiers** (no spaces, no dashes).
- The names you print here become callable DSL functions inside `configure … end`.

## 2) (Optional) `<service>_init`
Runs **once per process** the first time the service is used. Good for dependency checks.

```bash
uv_init() {
  if ! command -v uv >/dev/null 2>&1; then
    shellform_fatal "uv is not installed. Install it first."
  fi
}
```

## 3) (Optional) `<service>_<option>_item`
Runs **immediately** when a line is parsed. Use this to record intent, validate input, or compute state.

```bash
uv_venv_item() {
  # Typically: stash desired path/version in private vars
  _uv_path="${1:-.venv}"
  _uv_py="${2:-}"  # validate if you accept only X.Y
}
```

## 4) (Optional) `<service>_<option>_group`
Runs **once at `end`**, with **all** arguments that appeared for that option.

```bash
uv_install_group() {
  # "$@" contains all args passed across all `install ...` lines in the block
  [[ $# -gt 0 ]] || return 0
  shellform_run uv pip install "$@"
}
```

---

# Provider guidelines (important)

## Naming & scope
- Prefix **all private variables/functions** to avoid collisions (e.g. `_uv_*`).
- Do **not** leave global state behind. The engine removes only the temporary option functions; your provider should keep its own state private.

## Error handling
- Use `shellform_fatal "message"` to abort with a clear error. The engine prints a call trace.
- Otherwise, let real command failures **bubble up** (strict mode will stop the run).
- Validate user input early (e.g., reject a Python version like `3.12.5` if you only accept `X.Y`).

## Running commands
- Use `shellform_run <cmd> <args…>` for any side-effecting command so it’s logged and counted.
- It is fine to use `command -v …` for quiet presence checks.
- Keep output clean and actionable.

## Option design
- Prefer **item** functions for validation/state capture.
- Prefer **group** functions for doing the work once (batching is faster and easier to reason about).
- If both exist, remember: `*_item` runs during parsing, `*_group` runs at the end.

## Logs & summary
- All `shellform_run` calls are logged under `./logs/…`.
- A summary prints automatically on exit (time, command count, error count, log file path).

---

# Provider skeleton (template)

```bash
# myservice_provider.sh

# Advertise supported options
myservice_spec() {
  echo "setup install cleanup"
}

# Optional: one-time checks
myservice_init() {
  command -v mytool >/dev/null 2>&1 || shellform_fatal "mytool is missing"
}

# Item hooks (optional)
myservice_setup_item()   { _ms_setup_args+=("$@"); }
myservice_install_item() { _ms_install_args+=("$@"); }

# Group hooks (optional; called at `end`)
myservice_setup_group() {
  [[ ${#_ms_setup_args[@]:-0} -eq 0 ]] || shellform_run mytool setup "${_ms_setup_args[@]}"
}

myservice_install_group() {
  [[ $# -gt 0 ]] || return 0
  shellform_run mytool install "$@"
}

myservice_cleanup_group() {
  shellform_run mytool cleanup
}
```

---

# Example: using a provider

```bash
# uv_provider.sh exposes: venv, install
configure uv
  venv .venv 3.12
  install black ruff pytest
end
```

What happens:
- `uv_spec` returns `venv install`
- `uv_init` runs once (checks `uv` is present)
- `venv` line triggers `uv_venv_item` (records desired venv)
- `install` line captures packages (and can validate each)
- On `end`:
  - `uv_venv_group` ensures/creates the venv
  - `uv_install_group` installs all packages in one shot

---

# Writing tests for a provider (recommended)

- Use [bats-core] with [bats-assert] to verify:
  - `*_spec` returns the expected option names
  - `*_init` fails clearly when a dependency is missing
  - `*_item` validates/records input
  - `*_group` runs the right commands (assert via a stubbed `shellform_run` log)
- Run tests in a **sandboxed PATH** (e.g., `$TMPDIR/bin:/usr/bin:/bin`) to avoid system bleed-through.

---

# FAQs

**Q: Can a provider define options not returned by `*_spec`?**  
No. Only names printed by `*_spec` are bound into the DSL.

**Q: What if an option is never used in a block?**  
Its `*_group` is never called.

**Q: Can options appear multiple times?**  
Yes. All args are aggregated and passed to the `*_group` function.

---

# License

MIT. Credit is appreciated.

---

> Engine reference: `shellform.sh` controls the lifecycle and enforces strict mode, logging, counters, and the `configure…end` contract.
