# --- Configuration et Initialisation ---
$JsonPath = "$PSScriptRoot\donnees.json"
$wshell = New-Object -ComObject WScript.Shell

# --- NOUVEAU MOTEUR DE CLAVIER (Niveau Materiel Absolu) ---
$CsharpCode = @"
using System;
using System.Runtime.InteropServices;
public class ClavierVirtuel {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    
    [DllImport("user32.dll")]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    public static void Appuyer(byte keyCode) {
        uint scanCode = MapVirtualKey(keyCode, 0);
        uint FLAG_KEYUP = 0x0002;
        uint FLAG_SCANCODE = 0x0008; 
        
        // Enfoncer la touche
        keybd_event(0, (byte)scanCode, FLAG_SCANCODE, UIntPtr.Zero);
        // Maintenir 30ms 
        System.Threading.Thread.Sleep(30); 
        // Relacher la touche
        keybd_event(0, (byte)scanCode, FLAG_SCANCODE | FLAG_KEYUP, UIntPtr.Zero);
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'ClavierVirtuel').Type) {
    Add-Type -TypeDefinition $CsharpCode
}
# ---------------------------------------------------

# Chargement des donnees (Lecture seule)
if (-not (Test-Path $JsonPath)) {
    Write-Host "Fichier 'donnees.json' introuvable." -ForegroundColor Red
    Exit
}
$data = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

# --- Fonctions Utilitaires ---
function Press-Key ($Key) {
    switch ($Key.ToLower()) {
        "a" { [ClavierVirtuel]::Appuyer(0x41) }
        "f" { [ClavierVirtuel]::Appuyer(0x46) }
        "g" { [ClavierVirtuel]::Appuyer(0x47) }
        "s" { [ClavierVirtuel]::Appuyer(0x53) }
        "z" { [ClavierVirtuel]::Appuyer(0x5A) }
    }
    Start-Sleep -Milliseconds 50 # Petite pause pour laisser le jeu reagir
}

function Wait-ForP {
    Write-Host "`nPositionnez le curseur dans le jeu, puis appuyez sur 'p' pour lancer." -ForegroundColor Cyan
    while ($true) {
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true)
            if ($key.KeyChar -eq 'p') {
                Write-Host "`nLancement dans..." -ForegroundColor Yellow
                for ($i = 3; $i -gt 0; $i--) {
                    Write-Host "$i..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                $wshell.AppActivate("Monster Hunter Wilds") | Out-Null
                Start-Sleep -Milliseconds 500
                Write-Host "C'est parti !" -ForegroundColor Green
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
}

# --- Menu Principal ---
Clear-Host
Write-Host "=== Menu Reroll Automatique V3 (Auto + Emblemes) ===" -ForegroundColor Cyan
Write-Host "Zenny actuels : $($data.Zenny)"
Write-Host "1) Voulez-vous reroll des talents ? (1500 pts / 9000z)"
Write-Host "2) Voulez-vous reroll des Bonus ? (6000 pts / 5000z)"
$mainChoice = Read-Host "Votre choix (1 ou 2)"

if ($mainChoice -eq '1') {
    # On considere qu'un appareil vaut 500 points
    $ValeurAppareil = 500
    $TotalPointsTalents = ($data.Talents."Appareil goudronne Attaque" * $ValeurAppareil) + 
                          ($data.Talents."Appareil goudronne Affinite" * $ValeurAppareil) + 
                          ($data.Talents."Appareil goudronne Element" * $ValeurAppareil)

    $BouclesRessources = [math]::Floor($TotalPointsTalents / 1500)
    $BouclesZenny = [math]::Floor($data.Zenny / 9000)
    $TotalBoucles = [math]::Min($BouclesRessources, $BouclesZenny)

    Write-Host "`nPoints Talents estimes : $TotalPointsTalents"
    
    if ($TotalBoucles -le 0) {
        Write-Host "Ressources ou Zenny insuffisants pour faire au moins une boucle." -ForegroundColor Red
        Exit
    }

    Write-Host "Le script va effectuer $TotalBoucles boucles." -ForegroundColor Green
    Wait-ForP

    for ($i = 1; $i -le $TotalBoucles; $i++) {
        Press-Key "g" 
        Start-Sleep -Milliseconds 100 
        Press-Key "f" 
        Start-Sleep -Milliseconds 100 
    }
    
    Write-Host "`nTermine ! $TotalBoucles boucles de talents effectuees." -ForegroundColor Green

}
elseif ($mainChoice -eq '2') {
    # --- PHASE 1 : Ressources Normales ---
    $TotalPointsNormaux = ($data.Bonus."Gemme-Dragon ravagee" * 3000) +
                          ($data.Bonus."Oricalcite" * 300) +
                          ($data.Bonus."rempart Gogmazios" * 200) +
                          ($data.Bonus."Fortin Gogmazios" * 200) +
                          ($data.Bonus."Argecite" * 200) +
                          ($data.Bonus."huile de dragon epaisse" * 150) +
                          ($data.Bonus."Grainite" * 100)

    $BouclesAutoRessources = [math]::Floor($TotalPointsNormaux / 6000)
    $BouclesAutoZenny = [math]::Floor($data.Zenny / 5000)
    $BouclesAuto = [math]::Min($BouclesAutoRessources, $BouclesAutoZenny)

    # Deduction des Zenny utilises pour la Phase 1
    $ZennyRestants = $data.Zenny - ($BouclesAuto * 5000)

    # --- PHASE 2 : Emblemes ---
    # Il faut 2 emblemes pour faire 6000 points
    $BouclesEmblemesPossibles = [math]::Floor($data.Bonus."Embleme Forge dans le combat" / 2)
    $BouclesEmblemesZenny = [math]::Floor($ZennyRestants / 5000)
    $BouclesEmblemes = [math]::Min($BouclesEmblemesPossibles, $BouclesEmblemesZenny)

    if (($BouclesAuto + $BouclesEmblemes) -le 0) {
        Write-Host "Ressources ou Zenny insuffisants pour faire au moins une boucle." -ForegroundColor Red
        Exit
    }

    Write-Host "`nPoints Bonus (Hors Emblemes) : $TotalPointsNormaux"
    Write-Host "Emblemes disponibles : $($data.Bonus."Embleme Forge dans le combat")"
    Write-Host "-> Phase 1 (Auto) : $BouclesAuto boucles prevues." -ForegroundColor Cyan
    Write-Host "-> Phase 2 (Emblemes) : $BouclesEmblemes boucles prevues." -ForegroundColor Magenta
    
    Wait-ForP

    # Execution Phase 1 (Auto-fill)
    if ($BouclesAuto -gt 0) {
        for ($i = 1; $i -le $BouclesAuto; $i++) {
            Press-Key "g"
            Start-Sleep -Milliseconds 100
            Press-Key "f"
            Start-Sleep -Milliseconds 100
        }
    }

    # Execution Phase 2 (Emblemes manuels)
    if ($BouclesEmblemes -gt 0) {
        for ($i = 1; $i -le $BouclesEmblemes; $i++) {
            Press-Key "z" # Haut
            Press-Key "z" # Haut
            Press-Key "a" # Ajout
            Press-Key "s" # Bas
            Press-Key "f" # Validation
            Start-Sleep -Milliseconds 100
        }
    }

    Write-Host "`nTermine ! Total de $($BouclesAuto + $BouclesEmblemes) boucles de bonus effectuees." -ForegroundColor Green
}
else {
    Write-Host "Choix invalide." -ForegroundColor Red
    Exit
}

Write-Host "Le fichier donnees.json n'a pas ete modifie." -ForegroundColor Gray