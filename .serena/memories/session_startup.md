# Session Startup

## Quick Status
- **Project**: Baby_Nas
- **Status**: Active development
- **Last Up2026-01-18d**: 2026-01-18

> **For paths/commands**: Load `quick_reference` memory
> **For tool guidance**: Load `tool_usage_patterns` memory

---

## Mode Selection

| Task Type | Mode | Command |
|-----------|------|---------|
| Complex multi-step | Planning | `switch_modes(["planning", "interactive"])` |
| Batch operations | One-shot | `switch_modes(["one-shot", "editing"])` |
| Research/exploration | Default | (no change) |

---

## Task Areas

### 1. Feature Development
**Load**: `quick_reference`, `tool_usage_patterns`
- New feature implementation
- Code modifications
- Refactoring

### 2. Bug Fixing
**Load**: `troubleshooting`, `tool_usage_patterns`
- Debug issues
- Fix errors
- Write regression tests

### 3. Testing
**Load**: `quick_reference`
- Write unit tests
- Run test suite
- Coverage analysis

### 4. Documentation
**Load**: `quick_reference`
- Up2026-01-18 README
- API documentation
- Code comments

### 5. DevOps / Deployment
**Load**: `quick_reference`, `troubleshooting`
- CI/CD configuration
- Environment setup
- Deployment scripts

---

## Memory Index

| Category | Memories |
|----------|----------|
| Core | `quick_reference`, `tool_usage_patterns`, `session_startup` |
| Operations | `troubleshooting` |

---

## Parallel Agent Policy

For multi-file operations, spawn parallel agents:
- File edits → agent per file
- Searches → parallel patterns
- **Minimum: 2-3 agents** when splittable

---

**Ready to work! What's the task?**

