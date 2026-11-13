$ErrorActionPreference = "Stop"
git fetch --tags
$latest = (git tag --sort=-v:refname | Select-Object -First 1)
if (-not $latest) { $latest = "v0.0" }
$ver = $latest.TrimStart('v')
$parts = $ver.Split('.')
$minor = [int]$parts[1] + 1
$newTag = "v$($parts[0]).$minor"
Write-Host "Latest: $latest  ->  New: $newTag"
git tag $newTag
git push origin $newTag
Write-Host "Done. Tag $newTag pushed."