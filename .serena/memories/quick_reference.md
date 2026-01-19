# Quick Reference

## Project Paths
```
D:\workspace\Baby_Nas/
├── src/              # Source code
├── tests/            # Test files
├── docs/             # Documentation
├── scripts/          # Utility scripts
└── configs/          # Configuration files
```

## Common Commands

### Development
```bash
# Install dependencies
pip install -r requirements.txt  # Python
npm install                      # Node.js

# Run tests
pytest                           # Python
npm test                         # Node.js

# Linting
ruff check .                     # Python
eslint .                         # JavaScript
```

### Git
```bash
git status
git add <files>
git commit -m "message"
git push origin main
```

## Key Files
- `README.md` - Project documentation
- `requirements.txt` / `package.json` - Dependencies
- `.env.example` - Environment template (copy to .env)

## Environment Variables
Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
# Edit .env with your values
```

## URLs / Endpoints
| Service | URL |
|---------|-----|
| Local Dev | http://localhost:8000 |
| API Docs | http://localhost:8000/docs |

---
**Customize this file for your project specifics.**

