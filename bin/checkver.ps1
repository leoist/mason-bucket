param(
  [string]$App,
  [switch]$Update
)

$manifests = if ($App) { Get-ChildItem "bucket/$App.json" } else { Get-ChildItem bucket/*.json }

foreach ($m in $manifests) {
  $json = Get-Content $m.FullName -Raw | ConvertFrom-Json
  if ($json.checkver -ne "github") { continue }
  $repo = ($json.homepage -replace 'https://github.com/', '')
  try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
    $latest = $rel.tag_name -replace '^v'
    Write-Host "$($m.BaseName): current=$($json.version) latest=$latest"
    if ($Update -and $latest -and $latest -ne $json.version) {
      $dlUrl = $json.autoupdate.architecture.'64bit'.url -replace '\$version', $latest
      $zip = Invoke-WebRequest $dlUrl -UseBasicParsing
      $hash = (Get-FileHash -InputStream $zip.Content -Algorithm SHA256).Hash.ToLower()
      $newJson = $json.PSObject.Copy()
      $newJson.version = $latest
      $newJson.architecture.'64bit'.url = $dlUrl
      $newJson.architecture.'64bit'.hash = $hash
      $newJson | ConvertTo-Json -Depth 10 | Set-Content $m.FullName
      Write-Host "  -> updated to $latest"
    }
  } catch {
    Write-Warning "$($m.BaseName): $_"
  }
}
