# Clean 3-commit replay script
$ErrorActionPreference = "Stop"

$sourceRepo = "C:\Users\hp\Desktop\_drowsiness_source_tmp"
$targetRepo = "C:\Users\hp\Desktop\Driver-Drowsiness-Detection-System"

$authorName  = "Abhinav Atul"
$authorEmail = "abhinav_atul@outlook.com"

# The 3 selected commits: hash, date, message
$selectedCommits = @(
    @{ Hash="a9b05251bedcc69f2d7d9d8fb26d8402353804d5"; Date="2025-09-17 23:10:23 +0530"; Message="Add files via upload" },
    @{ Hash="44bffa93d7ca6086faba1c61e0051d684ce1dec9"; Date="2025-09-28 15:33:57 +0530"; Message="Update README.md" }
)

function Copy-SourceSnapshot($hash) {
    # Checkout the source at this commit
    Push-Location $sourceRepo
    git checkout $hash --quiet 2>&1 | Out-Null
    Pop-Location

    # Remove all current files from target (except .git and this script)
    Get-ChildItem -Path $targetRepo -Exclude ".git","replay_commits.ps1" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Copy all files from source snapshot to target
    Get-ChildItem -Path $sourceRepo -Exclude ".git" | ForEach-Object {
        if ($_.PSIsContainer) {
            Copy-Item -Path $_.FullName -Destination $targetRepo -Recurse -Force
        } else {
            Copy-Item -Path $_.FullName -Destination $targetRepo -Force
        }
    }
}

function Make-Commit($message, $date) {
    git -C $targetRepo add -A

    $status = git -C $targetRepo status --porcelain
    if ($status) {
        $env:GIT_AUTHOR_NAME      = $authorName
        $env:GIT_AUTHOR_EMAIL     = $authorEmail
        $env:GIT_AUTHOR_DATE      = $date
        $env:GIT_COMMITTER_NAME   = $authorName
        $env:GIT_COMMITTER_EMAIL  = $authorEmail
        $env:GIT_COMMITTER_DATE   = $date

        git -C $targetRepo commit -m $message
        Write-Host "  -> Committed: $message [$date]"
    } else {
        Write-Host "  -> No changes for: $message, skipping."
    }
}

# Process each selected commit
foreach ($c in $selectedCommits) {
    Write-Host "`nProcessing: $($c.Message)"
    Copy-SourceSnapshot $c.Hash
    Make-Commit $c.Message $c.Date
}

# Clean up env vars
Remove-Item Env:\GIT_AUTHOR_NAME      -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_AUTHOR_EMAIL     -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_AUTHOR_DATE      -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_COMMITTER_NAME   -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_COMMITTER_EMAIL  -ErrorAction SilentlyContinue
Remove-Item Env:\GIT_COMMITTER_DATE   -ErrorAction SilentlyContinue

Write-Host "`n=== Done! Final git log ==="
git -C $targetRepo log --format="%h | %ai | %s | %an <%ae>"
