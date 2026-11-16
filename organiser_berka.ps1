# Organisation prudente du projet SQL Berka (Windows PowerShell 5.1+)
# Par defaut : simulation uniquement. Ajouter -Apply pour deplacer les fichiers.
# N'efface aucun fichier et ne remplace jamais un fichier deja present.
param(
    [string]$Root = 'D:\project\projet_sql_bank_berka',
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Dossier introuvable : $Root"
}

$folders = @(
    'sql', 'sql\experimental', 'data\raw', 'models',
    'docs', 'docs\diagrams', 'docs\screenshots', 'results'
)

$routes = @(
    @{ File = '01_create_schema.sql'; Destination = 'sql' },
    @{ File = '02_load_clean.sql'; Destination = 'sql' },
    @{ File = '03_quality_checks.sql'; Destination = 'sql' },
    @{ File = '04_analysis.sql'; Destination = 'sql' },
    @{ File = '05_views.sql'; Destination = 'sql' },
    @{ File = '06_complements_cahier_des_charges.sql'; Destination = 'sql\experimental' },
    @{ File = 'account.csv'; Destination = 'data\raw' },
    @{ File = 'card.csv'; Destination = 'data\raw' },
    @{ File = 'client.csv'; Destination = 'data\raw' },
    @{ File = 'disp.csv'; Destination = 'data\raw' },
    @{ File = 'district.csv'; Destination = 'data\raw' },
    @{ File = 'loan.csv'; Destination = 'data\raw' },
    @{ File = 'order.csv'; Destination = 'data\raw' },
    @{ File = 'trans.csv'; Destination = 'data\raw' },
    @{ File = 'Berka_Banking_EER.mwb'; Destination = 'models' },
    @{ File = 'Berka_Banking_EER.png'; Destination = 'docs\diagrams' },
    @{ File = 'Berka_Banking_EER.svg'; Destination = 'docs\diagrams' },
    @{ File = 'Berka_Banking_EER.html'; Destination = 'docs\diagrams' },
    @{ File = 'Berka_Banking_EER.htm'; Destination = 'docs\diagrams' },
    @{ File = 'RESULTATS.md'; Destination = 'docs' },
    @{ File = 'DICTIONNAIRE_DONNEES.md'; Destination = 'docs' },
    @{ File = 'REPRODUCTION.md'; Destination = 'docs' },
    @{ File = 'LIMITES.md'; Destination = 'docs' }
)

$mode = if ($Apply) { 'APPLICATION' } else { 'SIMULATION (aucune modification)' }
Write-Host "Mode : $mode"
Write-Host "Projet : $Root"

if ($Apply) {
    foreach ($folder in $folders) {
        $path = Join-Path $Root $folder
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
        }
    }
}

$moveCount = 0
foreach ($route in $routes) {
    $source = Join-Path $Root $route.File
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }

    $targetFolder = Join-Path $Root $route.Destination
    $target = Join-Path $targetFolder $route.File

    if (Test-Path -LiteralPath $target) {
        Write-Warning "Ignore (destination deja presente) : $($route.File)"
        continue
    }

    Write-Host "  $($route.File)  ->  $($route.Destination)\"
    if ($Apply) {
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder | Out-Null
        }
        Move-Item -LiteralPath $source -Destination $target
    }
    $moveCount++
}

$ignorePath = Join-Path $Root '.gitignore'
if (-not (Test-Path -LiteralPath $ignorePath)) {
    Write-Host '  .gitignore : a creer (CSV bruts exclus de Git)'
    if ($Apply) {
        @'
# Donnees brutes volumineuses : les conserver localement, ne pas publier.
/data/raw/
/data/processed/

# Identifiants et secrets
.env
.env.*
!.env.example
*.pem

# Fichiers temporaires
*.log
*.tmp
*.bak
Thumbs.db
.DS_Store
'@ | Set-Content -LiteralPath $ignorePath -Encoding UTF8
    }
} else {
    Write-Host '  .gitignore existant conserve (verifier qu il exclut /data/raw/)'
}

$verb = if ($Apply) { 'deplaces' } else { 'a deplacer' }
Write-Host "Fichiers $verb : $moveCount"
if (-not $Apply) {
    Write-Host 'Aucune modification effectuee. Relancer avec -Apply apres verification.'
} else {
    Write-Host 'Termine. Les fichiers non repertories ont ete laisses a leur emplacement.'
    Write-Host 'Verifier README.md et les liens relatifs apres le deplacement.'
}
