# TrueNAS RAG System Sync (Baby_Nas)

This Baby_Nas VM can stage and snapshot workspace data before pushing the RAG system to the main NAS.

## Target
- **Host**: `10.0.0.89`
- **Remote path**: `/mnt/tank/rag-system`
- **User**: `baby-nas` (dedicated sync user)

## Recommended TrueNAS Setup (one-time)
1) Create a dedicated user:
   - Username: `baby-nas`
   - Home: `/mnt/tank/rag-system/home/baby-nas`
   - Shell: `/bin/bash`
   - SSH public key: use the key generated on this VM (see next section)
2) Grant full access to `/mnt/tank/rag-system` for the `baby-nas` user.

## Local SSH Key (Baby_Nas VM)
1) Generate a key pair (run once):
   ```powershell
   ssh-keygen -t ed25519 -f D:\workspace\Baby_Nas\keys\baby-nas_rag-system -C "baby-nas@rag-system"
   ```
2) Copy the public key to TrueNAS:
   - Paste the contents of `D:\workspace\Baby_Nas\keys\baby-nas_rag-system.pub` into the TrueNAS user’s SSH keys.

## Environment Variables (store in .env.local)
```
TRUENAS_RAG_HOST=10.0.0.89
TRUENAS_RAG_USER=baby-nas
TRUENAS_RAG_SSH_KEY=D:\workspace\Baby_Nas\keys\baby-nas_rag-system
TRUENAS_RAG_REMOTE_PATH=/mnt/tank/rag-system
```

## Verification
```powershell
ssh -i D:\workspace\Baby_Nas\keys\baby-nas_rag-system baby-nas@10.0.0.89 "ls -la /mnt/tank/rag-system"
```

## Notes
- Do not store secrets in git. Keep keys and `.env.local` out of version control.
