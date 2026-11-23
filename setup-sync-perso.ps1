<#
  setup-sync-perso.ps1
  Deplace les fichiers personnels de career-ops vers un dossier Google Drive
  et les remplace par des liens, pour synchroniser plusieurs PC.

  Utilisation (PowerShell, depuis le dossier du depot) :
    .\setup-sync-perso.ps1 -DriveDir "G:\Mon Drive\career-ops-perso"          # simulation
    .\setup-sync-perso.ps1 -DriveDir "G:\Mon Drive\career-ops-perso" -Apply   # execution

  Prerequis :
    - Google Drive pour ordinateur en mode "Mettre en miroir les fichiers"
      (pas "Diffuser"), sinon les liens peuvent echouer hors ligne.
    - Liens de fichiers : mode developpeur Windows active, ou PowerShell
      lance en administrateur. Les liens de dossiers n'en ont pas besoin.

  Comportement :
    - PC 1 (le dossier Drive n'a pas l'element) : l'element est DEPLACE vers Drive,
      puis un lien est cree a sa place.
    - PC suivants (Drive a deja l'element, le depot a une copie locale) : la copie
      locale est RENOMMEE en *.local-AAAAMMJJ-HHMMSS (jamais supprimee), puis le lien est cree.
    - Element deja lie : ignore. Element absent partout : ignore.
    - .env n'est PAS traite (secret). Ajoute-le toi-meme si tu le souhaites.
#>
param(
  [Parameter(Mandatory = $true)][string]$DriveDir,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot

$Files = @(
  'cv.md',
  'portals.yml',
  'config\profile.yml',
  'modes\_profile.md',
  'modes\_brief.md',
  'modes\_custom.md',
  'data\applications.md',
  'data\status-log.tsv',
  'data\pdf-index.tsv'
)
$Dirs = @(
  'data\templates\eunice',
  'data\templates\eunice-ats',
  'reports',
  'jds',
  'output',
  'interview-prep',
  'batch\tracker-additions\merged'
)

if (-not (Test-Path -LiteralPath $DriveDir)) {
  if ($Apply) {
    New-Item -ItemType Directory -Force -Path $DriveDir | Out-Null
  } else {
    Write-Host "[simulation] Le dossier $DriveDir sera cree."
  }
}

function Sync-Item([string]$Rel, [bool]$IsDir) {
  $src = Join-Path $Repo $Rel
  $dst = Join-Path $DriveDir $Rel

  $srcItem = Get-Item -LiteralPath $src -Force -ErrorAction SilentlyContinue
  if ($srcItem -and $srcItem.LinkType) { Write-Host "= $Rel : deja lie"; return }

  $srcExists = [bool]$srcItem
  $dstExists = Test-Path -LiteralPath $dst

  if (-not $srcExists -and -not $dstExists) { Write-Host "- $Rel : absent partout, ignore"; return }

  if ($srcExists -and -not $dstExists)      { $action = "deplace vers Drive puis lie" }
  elseif ($srcExists -and $dstExists)       { $action = "Drive a deja l'element : copie locale renommee, puis lie" }
  else                                      { $action = "lie vers l'element Drive" }

  if (-not $Apply) { Write-Host "[simulation] $Rel : $action"; return }

  if ($srcExists -and -not $dstExists) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Move-Item -LiteralPath $src -Destination $dst
  } elseif ($srcExists -and $dstExists) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Rename-Item -LiteralPath $src -NewName ((Split-Path -Leaf $src) + ".local-$stamp")
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $src) | Out-Null
  if ($IsDir) {
    New-Item -ItemType Junction -Path $src -Target $dst | Out-Null
  } else {
    New-Item -ItemType SymbolicLink -Path $src -Target $dst | Out-Null
  }
  Write-Host "+ $Rel : $action"
}

foreach ($f in $Files) { Sync-Item $f $false }
foreach ($d in $Dirs)  { Sync-Item $d $true }

if (-not $Apply) { Write-Host "`nSimulation terminee. Relance avec -Apply pour executer." }
else { Write-Host "`nTermine. Verifie avec : Get-ChildItem -Force | Where-Object LinkType" }
