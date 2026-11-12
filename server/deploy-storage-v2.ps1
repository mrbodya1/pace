param([switch]$ApplyFreshStart)
$ErrorActionPreference = 'Stop'
if (-not $ApplyFreshStart) { throw 'Requires -ApplyFreshStart and authorization to reset all prior training history.' }
$taskProject = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
if ($taskProject -ine 'D:\Applications\PACE\Project') { throw 'Unexpected project location.' }
$taskData = Join-Path $PSScriptRoot 'pb_data'
$taskPrivate = 'D:\Applications\PACE\Runtime\Garmin'
$taskPbExe = Join-Path $PSScriptRoot 'runtime\pocketbase.exe'
$taskCaddyExe = 'D:\Applications\HomeServer\Caddy\bin\caddy.exe'
$taskBackup = Join-Path 'D:\Applications\Backups' ('StorageV2-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($scope in @('Process','User','Machine')) {
    if ([Environment]::GetEnvironmentVariable('PACE_ENABLE_LEGACY_API',$scope)) { throw 'Legacy test flag must be absent in production.' }
}
$null = New-Item -ItemType Directory -Path (Join-Path $taskProject 'build') -Force
$taskValidationLog = Join-Path $taskProject 'build\storage-caddy-validation.log'
$taskValidateProcess = Start-Process -FilePath $taskCaddyExe -ArgumentList @('validate','--config',('"' + (Join-Path $PSScriptRoot 'gateway\Caddyfile') + '"'),'--adapter','caddyfile') -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $taskValidationLog -RedirectStandardError ($taskValidationLog+'.stderr')
if ($taskValidateProcess.ExitCode -ne 0) { throw 'Gateway validation failed before any restart.' }
$env:PACE_STORAGE_PROJECT = $taskProject
$env:PACE_STORAGE_BACKUP = $taskBackup
$env:PACE_STORAGE_PRIVATE = $taskPrivate
@'
import os,sqlite3
from pathlib import Path
p=Path(os.environ['PACE_STORAGE_PROJECT'])/'server/pb_data/data.db'
with sqlite3.connect(p.as_uri()+'?mode=ro',uri=True) as db:
 assert not db.execute("SELECT 1 FROM sqlite_master WHERE name='pace_v2_settings'").fetchone(),'V2 already applied: refusing another reset'
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Fresh-start precondition failed.' }
function Stop-VerifiedListener($port, $expected) {
    foreach ($connection in @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction Stop
        if ($process.Path -ine $expected) { throw "Unexpected listener on port $port." }
        Stop-Process -Id $process.Id -Force
    }
}
function Wait-Health($port) {
    for ($attempt=0; $attempt -lt 60; $attempt++) {
        try { if ((Invoke-RestMethod "http://127.0.0.1:$port/api/health" -TimeoutSec 2).code -eq 200) { return } } catch { }
        Start-Sleep -Milliseconds 500
    }
    throw "PACE health failed on port $port; inspect private runtime logs. Backup: $taskBackup"
}
$null = New-Item -ItemType Directory -Path $taskBackup
$taskSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $taskBackup /inheritance:r /grant:r "*${taskSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Cannot restrict backup permissions.' }
# Close the public ingress first so no new import request starts during cutover.
Stop-ScheduledTask -TaskName 'PACE-API-Gateway'
Start-Sleep -Milliseconds 500
Stop-VerifiedListener 8091 $taskCaddyExe
Stop-ScheduledTask -TaskName 'PACE-PocketBase'
Start-Sleep -Milliseconds 500
Stop-VerifiedListener 8090 $taskPbExe
$taskCollectorLock = $null
try {
    # A pre-existing on-demand collector may finish; never race its inbox write.
    for ($attempt=0; $attempt -lt 150; $attempt++) {
        try { $taskCollectorLock = [IO.File]::Open((Join-Path $taskPrivate 'collector.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); break } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $taskCollectorLock) { throw 'Garmin collector is still busy; reset has not run.' }
    Copy-Item -LiteralPath $taskData -Destination (Join-Path $taskBackup 'pb_data') -Recurse
    $taskFiles = @(Get-ChildItem -LiteralPath $taskData -File -Recurse)
    foreach ($file in $taskFiles) {
        $relative = $file.FullName.Substring($taskData.Length).TrimStart('\')
        $copy = Join-Path (Join-Path $taskBackup 'pb_data') $relative
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash) { throw 'Backup checksum mismatch; migration has not run.' }
    }
    $taskGarminBackup = Join-Path $taskBackup 'garmin'
    $null = New-Item -ItemType Directory -Path $taskGarminBackup
    foreach ($name in @('import-config.json','inbox.json','personal-api-key.dpapi','refresh-state.json')) {
        $file = Join-Path $taskPrivate $name
        if (Test-Path -LiteralPath $file) {
            Copy-Item -LiteralPath $file -Destination (Join-Path $taskGarminBackup $name)
            if ((Get-FileHash -LiteralPath $file).Hash -ne (Get-FileHash -LiteralPath (Join-Path $taskGarminBackup $name)).Hash) { throw 'Garmin backup checksum mismatch.' }
        }
    }
    # Verify migration against an isolated clone of this exact stopped backup first.
    $taskValidation = Join-Path $taskBackup 'migration-validation'
    Copy-Item -LiteralPath (Join-Path $taskBackup 'pb_data') -Destination $taskValidation -Recurse
    $taskMigrationLog = Join-Path $taskBackup 'migration-validation.log'
    $taskMigrateProcess = Start-Process -FilePath $taskPbExe -ArgumentList @('migrate','up',('--dir="'+$taskValidation+'"'),('--migrationsDir="'+(Join-Path $PSScriptRoot 'pb_migrations')+'"'),('--hooksDir="'+(Join-Path $PSScriptRoot 'pb_hooks')+'"')) -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput $taskMigrationLog -RedirectStandardError ($taskMigrationLog+'.stderr')
    if ($taskMigrateProcess.ExitCode -ne 0) { throw 'Migration rehearsal failed; working database is unchanged.' }
    @'
import os,sqlite3,hashlib,json
from pathlib import Path
b=Path(os.environ['PACE_STORAGE_BACKUP'])
def snapshot(path):
 with sqlite3.connect(path.as_uri()+'?mode=ro',uri=True) as db:
  assert db.execute('PRAGMA quick_check').fetchone()[0]=='ok'
  return {t:hashlib.sha256(repr(db.execute('SELECT * FROM '+t+' ORDER BY id').fetchall()).encode()).hexdigest() for t in ['pace_users','pace_clubs','pace_events','pace_community_members']}
before=snapshot(b/'pb_data/data.db');after=snapshot(b/'migration-validation/data.db')
assert before==after,'Preserved accounts/profiles/community changed'
(b/'preserved-hashes.json').write_text(json.dumps(before),encoding='utf-8')
with sqlite3.connect((b/'migration-validation/data.db').as_uri()+'?mode=ro',uri=True) as db:
 for table in ['pace_progress','pace_competition_scores','pace_v2_state','pace_v2_workouts','pace_v2_telemetry']:
  assert db.execute('SELECT count(*) FROM '+table).fetchone()[0]==0
print('STOPPED_BACKUP_QUICK_CHECK=ok; MIGRATION_REHEARSAL=ok; PRESERVED_ROWS=identical')
'@ | python -
    if ($LASTEXITCODE -ne 0) { throw 'Backup/rehearsal integrity verification failed; working database is unchanged.' }
    # Reset only the training queue and cutoff. Keep owner binding and encrypted key.
    @'
import os,json,hashlib
from datetime import datetime,timezone
from pathlib import Path
p=Path(os.environ['PACE_STORAGE_PRIVATE']);b=Path(os.environ['PACE_STORAGE_BACKUP'])
key=hashlib.sha256((p/'personal-api-key.dpapi').read_bytes()).hexdigest()
config=json.loads((p/'import-config.json').read_text(encoding='utf-8-sig'))
cutoff=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
config['sinceUtc']=cutoff
def write(name,value):
 tmp=p/(name+'.cutover.tmp');tmp.write_text(json.dumps(value,separators=(',',':')),encoding='utf-8');os.replace(tmp,p/name)
write('import-config.json',config)
write('inbox.json',{'version':1,'ownerId':config['ownerId'],'sinceUtc':cutoff,'activities':[]})
write('refresh-state.json',{'phase':'idle'})
assert key==hashlib.sha256((p/'personal-api-key.dpapi').read_bytes()).hexdigest()
(b/'cutover.json').write_text(json.dumps({'sinceUtc':cutoff,'backupVerifiedFiles':len(list((b/'pb_data').rglob('*')))}),encoding='utf-8')
print('GARMIN_NEW_CUTOFF_UTC='+cutoff+'; KEY_PRESERVED=yes; QUEUE=empty')
'@ | python -
    if ($LASTEXITCODE -ne 0) { throw 'Garmin cutover failed; restore its checked private backup before starting.' }
} finally {
    if ($taskCollectorLock) { $taskCollectorLock.Dispose() }
}
# Reaching this line means the backup, migration rehearsal and cutoff are verified.
Start-ScheduledTask -TaskName 'PACE-PocketBase'
Wait-Health 8090
@'
import os,sqlite3,hashlib,json
from pathlib import Path
b=Path(os.environ['PACE_STORAGE_BACKUP']);p=Path(os.environ['PACE_STORAGE_PROJECT'])/'server/pb_data/data.db'
before=json.loads((b/'preserved-hashes.json').read_text())
with sqlite3.connect(p.as_uri()+'?mode=ro',uri=True) as db:
 assert db.execute('PRAGMA quick_check').fetchone()[0]=='ok'
 for table,digest in before.items():
  assert hashlib.sha256(repr(db.execute('SELECT * FROM '+table+' ORDER BY id').fetchall()).encode()).hexdigest()==digest
 for table in ['pace_progress','pace_competition_scores','pace_v2_state','pace_v2_workouts','pace_v2_telemetry']:
  assert db.execute('SELECT count(*) FROM '+table).fetchone()[0]==0
 assert db.execute('SELECT epoch FROM pace_v2_settings').fetchone()[0]=='workouts-v2-20261112'
print('LIVE_STORAGE_V2=empty; PRESERVED_ACCOUNTS_PROFILES_COMMUNITY=identical; QUICK_CHECK=ok')
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Live integrity check failed; keep gateway stopped and inspect the checked backup.' }
Start-ScheduledTask -TaskName 'PACE-API-Gateway'
Wait-Health 8091
Get-ScheduledTask -TaskName 'PACE-PocketBase','PACE-API-Gateway' | Select-Object TaskName,State
Write-Output "STORAGE_V2_CUTOVER_COMPLETED; BACKUP=$taskBackup; HASH_VERIFIED_FILES=$($taskFiles.Count)"
