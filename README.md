# Shellform

**Shellform** is a lightweight Bash DSL framework for defining declarative configuration blocks. It allows service-specific `configure ... end` blocks where commands can be collected and executed in both item-wise and grouped fashion.

---

## 🔧 Key Features

- Simple DSL:
  ```bash
  configure <service>
    <option> arg1 arg2 ...
    ...
  end
  ```
- Automatically calls:
  - `<service>_<option>_item` (if defined) on each line
  - `<service>_<option>_group` (if defined) at the end with all collected args
- Temporary functions/variables are created and cleaned up per block
- Built-in:
  - Logging (`./logs/`)
  - Command run tracking
  - Error counting
  - Execution timing

---

## 🛠 Usage Example

```bash
# Required: service spec
uv_spec() {
  echo install venv
}

# Optional handlers
uv_install_item() {
  echo "Installing $*"
}

uv_venv_group() {
  echo "Setting up venv with: $*"
}

# Now use shellform
configure uv
  install black flake8
  venv ~/.venvs/dev
end
```

---

## 📁 Output

```
▶️  echo Installing black flake8
Installing black flake8
▶️  echo Setting up venv with: ~/.venvs/dev
Setting up venv with: ~/.venvs/dev

Summary:
  Time Elapsed: 2s
  Commands Run: 2
  Errors:       0
  Log File:     ./logs/shellform_YYYYMMDD_HHMMSS.log
```

---

## 📘 Defining Services

Each service must define a `*_spec()` function returning available option names:

```bash
myservice_spec() {
  echo setup install cleanup
}
```

Optional functions:
- `myservice_setup_item()`
- `myservice_install_group()`
- `myservice_cleanup_item()` etc.

---

## 🚫 What’s Not Included

- No OS targeting logic

---

## ✅ Summary

Shellform gives you:
- A minimal, declarative Bash configuration interface
- Hookable item/group logic
- Clean teardown per block
- Runtime stats and logs for every run

---

## 📄 License

MIT License. Do whatever you want, but credit is appreciated.
