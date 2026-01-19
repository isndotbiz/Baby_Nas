# Serena Tool Usage Patterns

## Decision Tree: Which Tool to Use?

### Reading Code
```
Need to understand a file?
├── Unknown file structure → get_symbols_overview (first!)
├── Know the symbol name → find_symbol (with include_body=False initially)
├── Need full implementation → find_symbol with include_body=True
├── Need relationships → find_referencing_symbols
└── Need arbitrary pattern → search_for_pattern
```

### Editing Code
```
What kind of edit?
├── Replace entire function/class → replace_symbol_body
├── Add new function/class → insert_after_symbol or insert_before_symbol
├── Small change within function → replace_content (regex mode)
├── Multi-line precise edit → replace_content (regex with .*? wildcards)
└── Create new file → create_text_file
```

## Symbol-Level Tools (Preferred)

### When to Use
- Replacing entire method/function bodies
- Adding new methods to classes
- Refactoring symbol names across codebase
- Understanding class hierarchies

### Examples
```python
# Get class overview first
get_symbols_overview("src/module.py")

# Find specific method
find_symbol("ClassName/method", include_body=True)

# Replace entire method
replace_symbol_body("ClassName/method", "new code...", "src/module.py")

# Add new method after existing one
insert_after_symbol("ClassName/existing", "\n    def new_method(self):\n        pass", "src/module.py")
```

## File-Level Tools (When Needed)

### When to Use
- Changing a few lines within a large function
- Editing non-code files (YAML, JSON, Markdown)
- Pattern-based replacements
- Comments or docstrings only

### Regex Patterns
```python
# Replace specific pattern
replace_content(
    relative_path="config.yaml",
    needle="key: old_value",
    repl="key: new_value",
    mode="literal"
)

# Regex replacement (use .*? non-greedy!)
replace_content(
    needle="def old_func.*?return result",
    repl="def new_func(...):\n    return result",
    mode="regex"
)
```

## Search Tools

| Use Case | Tool |
|----------|------|
| Know symbol name | `find_symbol` |
| Fuzzy name match | `find_symbol` with `substring_matching=True` |
| Code pattern | `search_for_pattern` |
| Non-code files | `search_for_pattern` |

### Scope Searches
```python
# Always use relative_path when possible
find_symbol("search", relative_path="src/")
search_for_pattern("TODO", relative_path="src/", paths_include_glob="*.py")
```

## Mode Selection

| Task Type | Mode |
|-----------|------|
| Exploration | `interactive` (default) |
| Complex changes | `planning` then `editing` |
| Batch operations | `one-shot` |

```python
# Switch to planning mode
switch_modes(["planning", "interactive"])

# Switch to editing mode
switch_modes(["editing", "interactive"])
```

## Performance Tips

1. **Start with overviews** - `get_symbols_overview` before diving deep
2. **Use relative_path** - Always scope searches
3. **Avoid full file reads** - Use `include_body=False` first
4. **Use regex wildcards** - `.*?` to avoid specifying exact content

