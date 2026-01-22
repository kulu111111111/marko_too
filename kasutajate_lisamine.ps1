#Requires -RunAsAdministrator

# Kontroll admin õiguste jaoks
If (-NOT ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Skript peab jooksma administraatori õigustes!"
    Exit
}

$csvPath = ".\new_users_accounts.csv"

If (!(Test-Path $csvPath)) {
    Write-Error "Faili new_users_accounts.csv ei leitud!"
    Exit
}

$users = Import-Csv $csvPath -Delimiter ";"

Write-Host "Vali tegevus:"
Write-Host "1 - Lisa kõik kasutajad failist"
Write-Host "2 - Kustuta üks kasutaja"
$choice = Read-Host "Sisesta valik (1 või 2)"

# =========================
# ====== LISAMINE =========
# =========================
If ($choice -eq "1") {

    $addedUsers = @()

    foreach ($user in $users) {

        # Skip empty rows
        If ([string]::IsNullOrWhiteSpace($user.Nimi) -or [string]::IsNullOrWhiteSpace($user.Kasutajanimi)) {
            continue
        }

        $fullname = $user.Nimi.Trim()
        $username = $user.Kasutajanimi.Trim()
        $description = $user.Kirjeldus.Trim()
        $password = ConvertTo-SecureString $user.Parool.Trim() -AsPlainText -Force

        # Kasutajanime pikkuse kontroll (Windows max 20)
        If ($username.Length -gt 20) {
            Write-Warning "❌ $username – kasutajanimi liiga pikk"
            continue
        }

        # Kirjelduse pikkus (max 48)
        If ($description.Length -gt 48) {
            $description = $description.Substring(0,48)
            Write-Warning "⚠ $username – kirjeldus lühendati"
        }

        # Kas kasutaja juba olemas
        If (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Warning "❌ $username – kasutaja on juba olemas"
            continue
        }

        Try {
            New-LocalUser `
                -Name $username `
                -FullName $fullname `
                -Description $description `
                -Password $password `
                -PasswordNeverExpires:$false `
                -UserMayNotChangePassword:$false

            # Lisa Users gruppi
            Add-LocalGroupMember -Group "Users" -Member $username

            # Parooli vahetus esimesel sisselogimisel
            Set-LocalUser -Name $username -PasswordExpired $true

            Write-Host "✅ $username lisatud"
            $addedUsers += $username
        }
        Catch {
            Write-Error "❌ $username – lisamine ebaõnnestus: $_"
        }
    }

    Write-Host "`n=== LISATUD KASUTAJAD SÜSTEEMIS ==="
    Get-LocalUser |
        Where-Object {
            $_.Name -in $addedUsers
        } |
        Select-Object Name, FullName

    Exit
}

# =========================
# ===== KUSTUTAMINE =======
# =========================
ElseIf ($choice -eq "2") {

    Write-Host "`nOLEMASOLEVAD KASUTAJAD:"
    Get-LocalUser |
        Where-Object {
            $_.Enabled -eq $true -and
            $_.Name -notmatch "Administrator|DefaultAccount|Guest|WDAGUtilityAccount"
        } |
        Select-Object Name, FullName

    $delUser = Read-Host "`nSisesta kasutajanimi, mida kustutada"

    $userObj = Get-LocalUser -Name $delUser -ErrorAction SilentlyContinue
    If (!$userObj) {
        Write-Error "❌ Kasutajat ei leitud"
        Exit
    }

    # Kustuta kasutaja kodukaust
    $profilePath = "C:\Users\$delUser"
    If (Test-Path $profilePath) {
        Remove-Item $profilePath -Recurse -Force
        Write-Host "🗑 Kasutaja kaust kustutatud"
    }

    Remove-LocalUser -Name $delUser
    Write-Host "✅ Kasutaja $delUser kustutatud"

    Exit
}

Else {
    Write-Error "Vale valik!"
    Exit
}
