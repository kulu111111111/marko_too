# ================== SEADISTUS ==================

# Sunni PowerShell kasutama UTF-8 kodeeringut väljundis
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Sisendfailid
$FirstNameFile = "eesnimed.txt"
$LastNameFile  = "perenimed.txt"
$DescFile      = "kirjeldused.txt"

# Väljundfail
$OutputCsv = "new_users_accounts.csv"

# Kasutajate arv
$UserCount = 5

# Paroolisätted
$UseStaticPassword = $false
$StaticPassword = ""

# ================== FUNKTSIOONID ==================

function Set-PasswordMode {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Paroolisätted" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    $passwordInput = Read-Host "Sisesta parool (või vajuta Enter juhusliku parooli jaoks)"
    
    if ([string]::IsNullOrWhiteSpace($passwordInput)) {
        $script:UseStaticPassword = $false
        Write-Host "OK, genereerin igale kasutajale juhusliku parooli" -ForegroundColor Cyan
    } else {
        $script:UseStaticPassword = $true
        $script:StaticPassword = $passwordInput
        Write-Host "OK, kasutan KÕIGILE kasutajatele parooli: $($script:StaticPassword)" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Remove-Diacritics {
    param ([string]$Text)
    # 1. Asenda täpitähed (õ,ä,ö,ü,š,ž)
    $Text = $Text -replace 'õ', 'o' -replace 'ä', 'a' -replace 'ö', 'o' -replace 'ü', 'u'
    $Text = $Text -replace 'š', 's' -replace 'ž', 'z'
    $Text = $Text -replace 'Õ', 'O' -replace 'Ä', 'A' -replace 'Ö', 'O' -replace 'Ü', 'U'
    $Text = $Text -replace 'Š', 'S' -replace 'Ž', 'Z'
    
    # 2. Eemalda tühikud ja sidekriipsud
    $Text = $Text -replace '[\s-]', ''
    return $Text
}

function New-RandomPassword {
    $length = Get-Random -Minimum 5 -Maximum 9
    return -join ((48..57 + 97..122) | Get-Random -Count $length | ForEach-Object {[char]$_})
}

# ================== ANDMETE LUGEMINE ==================

# Kontrolli kas failid on olemas
foreach ($file in @($FirstNameFile, $LastNameFile, $DescFile)) {
    if (!(Test-Path $file)) { 
        Write-Error "Faili $file ei leitud!"
        exit 
    }
}

Set-PasswordMode

# Loeme failid sisse UTF8 kodeeringuga
$FirstNames = Get-Content $FirstNameFile -Encoding UTF8
$LastNames  = Get-Content $LastNameFile -Encoding UTF8
$Descs      = Get-Content $DescFile -Encoding UTF8

# ================== CSV PÄIS ==================
# Kasutame 'utf8' (mis PS5.1 puhul on tegelikult UTF-8 koos BOM-iga)
"Nimi;Kasutajanimi;Parool;Kirjeldus" | Set-Content $OutputCsv -Encoding utf8 -Force

# ================== KASUTAJATE LOOMINE ==================

for ($i = 1; $i -le $UserCount; $i++) {

    $FirstName = Get-Random -InputObject $FirstNames
    $LastName  = Get-Random -InputObject $LastNames
    $Desc      = Get-Random -InputObject $Descs

    # Genereeri puhas kasutajanimi
    $RawUsername = "$FirstName.$LastName"
    $Username = Remove-Diacritics $RawUsername
    $Username = $Username.ToLower()

    if ($UseStaticPassword) {
        $Password = $StaticPassword
    } else {
        $Password = New-RandomPassword
    }

    # Lisa rida CSV-sse
    "$FirstName $LastName;$Username;$Password;$Desc" | Add-Content $OutputCsv -Encoding utf8

    # Konsooli info kuvamine
    $ShortDesc = if ($Desc.Length -gt 15) { $Desc.Substring(0, 15) + "..." } else { $Desc }
    Write-Host "Kasutaja loodud: $FirstName $LastName | $Username | $Password | $ShortDesc"
}

Write-Host "`nValmis! Fail salvestatud: $OutputCsv" -ForegroundColor Green