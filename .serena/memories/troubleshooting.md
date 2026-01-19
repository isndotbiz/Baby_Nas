# Troubleshooting Guide

## Serena / Language Server Issues

### Symbols Not Resolving
```python
# Restart the language server
restart_language_server()

# If that fails, check .serena/project.yml languages config
```

### LSP Not Starting
1. Check language is in project.yml `languages` list
2. Verify language server installed (pyright, typescript, etc.)
3. Delete `.serena/cache/` and restart
4. Check file encoding matches project.yml

### Memory Not Found
```python
# List all memories
list_memories()

# Memories are case-sensitive
read_memory("exact_name")
```

### Serena Tool Errors

| Error | Solution |
|-------|----------|
| "Path is ignored" | File in ignored_paths - use direct Edit tool |
| "Symbol not found" | Use `get_symbols_overview` first |
| "Multiple matches" | Add `relative_path` to narrow scope |

---

## Common Development Issues

### Dependencies Not Installing
```bash
# Python - try upgrading pip
pip install --upgrade pip
pip install -r requirements.txt

# Node.js - clear cache
rm -rf node_modules package-lock.json
npm install
```

### Tests Failing
```bash
# Run with verbose output
pytest -v --tb=long

# Run single test
pytest tests/test_module.py::test_function -v
```

### Port Already in Use
```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process
kill -9 <PID>
```

---

## Git Issues

### Merge Conflicts
```bash
# See conflicted files
git status

# After resolving
git add <resolved-files>
git commit -m "Resolve merge conflicts"
```

### Undo Last Commit (keep changes)
```bash
git reset --soft HEAD~1
```

### Discard Local Changes
```bash
git checkout -- <file>  # Single file
git reset --hard HEAD   # All changes (CAUTION)
```

---

## Quick Diagnostics

```bash
# Check Python version
python --version

# Check Node version
node --version

# Check git status
git status

# Check environment variables
env | grep PROJECT  # Linux/macOS
set | findstr PROJECT  # Windows
```

---

**Customize this file with project-specific troubleshooting.**

