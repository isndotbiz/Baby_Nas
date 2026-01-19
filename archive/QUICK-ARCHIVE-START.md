# Quick Archive Start - 3 Steps

**Ready to archive your 307GB of old data? Do this now:**

---

## Step 1: Dry Run (See What Will Happen)
**Time: 5 minutes**

Open PowerShell as Administrator:
```powershell
cd D:\workspace\Baby_Nas
.\archive-old-data.ps1
```

**Look for:**
- ✅ "Analyzing Folders to Archive" - shows 307GB
- ✅ "Baby NAS is reachable" - connectivity OK
- ✅ "SMB share mounted" - can write to NAS
- ✅ Summary showing all 4 folders

**If errors:**
- Ping: `ping 172.21.203.18`
- Start VM: `Start-VM -Name TrueNAS-BabyNAS`

---

## Step 2: Actually Archive
**Time: 45 minutes - 2 hours (network dependent)**

```powershell
.\archive-old-data.ps1 -Execute
```

**Watch for:**
- Each folder shows copy progress
- "Verifying..." section shows file/size match
- Final summary with manifest location

**If interrupted:**
- Run same command again - robocopy resumes

---

## Step 3: Cleanup Source (Optional)
**Time: 5 minutes**

### Option A: Manual (Safest)
Verify archive first:
```powershell
dir \\172.21.203.18\backups\archive\2025-12\
# Should show 4 folders
```

Then delete source:
```powershell
Remove-Item D:\Optimum -Recurse -Force
Remove-Item D:\~ -Recurse -Force
Remove-Item D:\Projects -Recurse -Force
Remove-Item D:\ai-workspace -Recurse -Force
```

Reclaim space: ~307GB ✅

### Option B: Auto-Cleanup (Asks per-folder)
```powershell
.\archive-old-data.ps1 -Execute -AutoCleanup
```

Script will ask "Delete source folder?" for each one.

---

## Step 4: Setup Snapshots (Recommended)
**Time: 2 minutes**

```powershell
.\setup-snapshots.ps1
```

Creates:
- ✅ Hourly snapshots (24-hour window)
- ✅ Daily snapshots (7 days)
- ✅ Weekly snapshots (4 weeks)

No extra storage cost - ZFS snapshots are efficient.

---

## Done! What's Next?

### Check Archive Status
```powershell
# View what's archived
dir \\172.21.203.18\backups\archive\2025-12\

# View metadata
type \\172.21.203.18\backups\archive\2025-12\manifest.json
```

### View Snapshots
```powershell
.\setup-snapshots.ps1 -Schedule View
```

### See Logs
```powershell
Get-Content C:\Logs\archive-old-data-*.log -Tail 50
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Cannot reach Baby NAS" | `Start-VM -Name TrueNAS-BabyNAS` |
| "SMB share mount failed" | Check credentials in script |
| "Archive is slow" | Normal - 307GB takes 1-2 hours |
| "Verification failed" | Don't delete source, investigate |
| "Out of space error" | Check NAS has 300+ GB free |

---

## Key Commands Reference

```powershell
# Dry run (no changes)
.\archive-old-data.ps1

# Execute
.\archive-old-data.ps1 -Execute

# Execute + ask about cleanup
.\archive-old-data.ps1 -Execute -AutoCleanup

# Setup snapshots
.\setup-snapshots.ps1

# View snapshots
.\setup-snapshots.ps1 -Schedule View

# View logs
Get-Content C:\Logs\archive-old-data-*.log

# Check NAS space
ssh admin@172.21.203.18 "zpool list tank"
```

---

**That's it!** 🎉

Your 307GB of old data is now:
- ✅ Safely copied to Baby NAS
- ✅ Integrity verified
- ✅ Protected by snapshots
- ✅ Reclaimed from D: drive

See `ARCHIVE-GUIDE.md` for detailed docs.
