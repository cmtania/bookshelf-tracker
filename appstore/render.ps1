# Renders the App Store promo screenshots (1320 x 2868, 6.9" iPhone) into appstore/final/.
# Uses headless Microsoft Edge and template.html. Edit the list below and run:
#   powershell -ExecutionPolicy Bypass -File appstore\render.ps1
# (Also needs the bookshelf-tracker-docs repo next to this one, for the font.)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$final = Join-Path $here 'final'
New-Item -ItemType Directory -Force $final | Out-Null

$edge = @("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", "C:\Program Files\Microsoft\Edge\Application\msedge.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge not found.' }

# Order = order in the App Store. The first 3 are what most people see in search results.
$slides = @(
  @{ out = '01-pull-a-book';  theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.59.48.png'
     title = 'Pull a book off your 3D shelf';             sub = 'Tap a spine and it turns to face you. Log reading right there.' },
  @{ out = '02-room-colors';  theme = 'cream';  shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.58.59.png'
     title = 'Make the room yours';                       sub = 'Bookcase designs and colors for the case, walls and floor.' },
  @{ out = '03-share';        theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 20.00.02.png'
     title = 'Share your shelf';                          sub = 'Turn your bookcase into a clean picture for anywhere.' },
  @{ out = '04-shelves';      theme = 'cream';  shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.57.07.png'
     title = 'One compartment per category';              sub = 'Name your shelves, then fill them book by book.' },
  @{ out = '05-welcome';      theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.56.53.png'
     title = 'Set up in under a minute';                  sub = 'No account, no sign-in. Your library stays on your device.' },
  @{ out = '06-pro';          theme = 'dark';   shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.57.28.png'
     title = 'Free to start. Pay once for Pro.';          sub = 'Unlimited books and every shelf, yours forever.' }
)

$template = (Join-Path $here 'template.html') -replace '\\', '/'
# Edge writes harmless warnings to stderr; don't let them stop the script.
$ErrorActionPreference = 'Continue'
foreach ($s in $slides) {
  $query = 'shot=' + [uri]::EscapeDataString($s.shot) + '&title=' + [uri]::EscapeDataString($s.title) +
           '&sub=' + [uri]::EscapeDataString($s.sub) + '&theme=' + $s.theme
  $url = "file:///$template`?$query"
  $png = Join-Path $final "$($s.out).png"
  & $edge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files `
    --window-size=1320,2868 --virtual-time-budget=4000 --screenshot="$png" $url 2>$null | Out-Null
  Start-Sleep -Milliseconds 800
  Write-Host "rendered $($s.out).png"
}
