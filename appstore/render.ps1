# Renders the App Store promo screenshots into appstore/final/: 6.9" iPhone (1320 x 2868) and, when iPad captures are in raw/, 13" iPad (2064 x 2752).
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
  @{ out = '01-pull-a-book'; theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 21.27.12.png'
     title = 'Pull a book off your 3D shelf'; sub = 'Tap a spine and it turns to face you. Log reading right there.' },
  @{ out = '02-room-colors'; theme = 'cream'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.58.59.png'
     title = 'Make the room yours'; sub = 'Bookcase designs and colors for the case, walls and floor.' },
  @{ out = '03-streaks'; theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 21.27.27.png'
     title = 'A streak for every book'; sub = 'Log pages in seconds and see your week at a glance.' },
  @{ out = '04-share'; theme = 'cream'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 21.27.45.png'
     title = 'Share your shelf'; sub = 'Turn your bookcase into a clean picture for anywhere.' },
  @{ out = '05-shelves'; theme = 'orange'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.57.07.png'
     title = 'One compartment per category'; sub = 'Name your shelves, then fill them book by book.' },
  @{ out = '06-welcome'; theme = 'cream'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.56.53.png'
     title = 'Set up in under a minute'; sub = 'No account, no sign-in. Your library stays on your device.' },
  @{ out = '07-pro'; theme = 'dark'; shot = 'Simulator Screenshot - iPhone 17 Pro Max - 2026-09-28 at 19.57.28.png'
     title = 'Free to start. Pay once for Pro.'; sub = 'Unlimited books and every shelf, yours forever.' }
)

# Edge writes harmless warnings to stderr; don't let them stop the script.
$ErrorActionPreference = 'Continue'

function Render($templateName, $size, $shot, $slide, $png) {
  $template = (Join-Path $here $templateName) -replace '\\', '/'
  $query = 'shot=' + [uri]::EscapeDataString($shot) + '&title=' + [uri]::EscapeDataString($slide.title) +
           '&sub=' + [uri]::EscapeDataString($slide.sub) + '&theme=' + $slide.theme
  $url = "file:///$template`?$query"
  & $edge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --allow-file-access-from-files `
    --window-size=$size --virtual-time-budget=4000 --screenshot="$png" $url 2>$null | Out-Null
  Start-Sleep -Milliseconds 800
  Write-Host "rendered $(Split-Path -Leaf $png)"
}

# 6.9" iPhone, 1320 x 2868.
foreach ($s in $slides) {
  Render 'template.html' '1320,2868' $s.shot $s (Join-Path $final "$($s.out).png")
}

# 13" iPad, 2064 x 2752 (required because the app supports iPad). Captures from the 13-inch
# iPad Pro simulator (portrait, Cmd+S) in raw/, listed explicitly like the iPhone set.
$ipad = 'Simulator Screenshot - iPad Pro 13-inch (M5) - 2026-09-28 at '
$ipadSlides = @(
  @{ out = 'ipad-01-pull-a-book'; theme = 'orange'; shot = "${ipad}21.31.11.png"
     title = 'Pull a book off your 3D shelf'; sub = 'Tap a spine and it turns to face you. Log reading right there.' },
  @{ out = 'ipad-02-room-colors'; theme = 'cream'; shot = "${ipad}21.23.05.png"
     title = 'Make the room yours'; sub = 'Colors for the bookcase, walls and floor, including herringbone and marble.' },
  @{ out = 'ipad-03-designs'; theme = 'orange'; shot = "${ipad}21.23.34.png"
     title = 'Pick a bookcase design'; sub = 'From a classic cabinet to a tree, your shelves come along.' },
  @{ out = 'ipad-04-streaks'; theme = 'cream'; shot = "${ipad}21.31.27.png"
     title = 'A streak for every book'; sub = 'Log pages in seconds and see your week at a glance.' },
  @{ out = 'ipad-05-shelves'; theme = 'orange'; shot = "${ipad}20.45.10.png"
     title = 'One compartment per category'; sub = 'Name your shelves, then fill them book by book.' },
  @{ out = 'ipad-06-welcome'; theme = 'cream'; shot = "${ipad}20.44.58.png"
     title = 'Set up in under a minute'; sub = 'No account, no sign-in. Your library stays on your device.' },
  @{ out = 'ipad-07-pro'; theme = 'dark'; shot = "${ipad}21.24.49.png"
     title = 'Free to start. Pay once for Pro.'; sub = 'Unlimited books and every shelf, yours forever.' }
)
foreach ($s in $ipadSlides) {
  if (-not (Test-Path -LiteralPath (Join-Path $here "raw\$($s.shot)"))) { Write-Host "missing raw/$($s.shot), skipped $($s.out)"; continue }
  Render 'template-ipad.html' '2064,2752' $s.shot $s (Join-Path $final "$($s.out).png")
}
