#Requires -RunAsAdministrator

# Kontroll admin õiguste jaoks
If (-NOT ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Skript peab jooksma administraatori õigustes!"
    Exit 1
}

# Kasuta skripti asukohta CSV õige leidmiseks
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "new_users_accounts.csv"

If (!(Test-Path $csvPath)) {
    Write-Error "Faili new_users_accounts.csv ei leitud ($csvPath)!"
    Exit 1
}

# PowerShell 7 (Core) ei ekspordi Windows-only LocalAccounts cmdlet'e vaikimisi.
# Kui jooksad PS7, lae LocalAccounts läbi Windows PowerShell compatibility konteineri.
If ($PSVersionTable.PSEdition -eq 'Core') {
    Try {
        Import-Module Microsoft.PowerShell.LocalAccounts -UseWindowsPowerShell -ErrorAction Stop
    }
    Catch {
        Write-Error "LocalAccounts moodulit ei saa PS7 all laadida. Käivita skript Windows PowerShell'is (PS5) või oleta, et -UseWindowsPowerShell on saadaval. $_"
        Exit 1
    }
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

        $fullname = ($user.Nimi -ne $null) ? $user.Nimi.Trim() : ''
        $username = ($user.Kasutajanimi -ne $null) ? $user.Kasutajanimi.Trim() : ''
        $description = ($user.Kirjeldus -ne $null) ? $user.Kirjeldus.Trim() : ''
        $plainPass = ($user.Parool -ne $null) ? $user.Parool.Trim() : ''

        If ([string]::IsNullOrWhiteSpace($username)) { continue }

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
            # Kui parool puudub, lase administraatoril sisestada
            If ([string]::IsNullOrWhiteSpace($plainPass)) {
                $securePassword = Read-Host -AsSecureString "Sisesta parool kasutajale $username"
            }
            else {
                $securePassword = ConvertTo-SecureString $plainPass -AsPlainText -Force
            }

            New-LocalUser `
                -Name $username `
                -FullName $fullname `
                -Description $description `
                -Password $securePassword `
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

    If ($addedUsers.Count -gt 0) {
        Write-Host "`n=== LISATUD KASUTAJAD SÜSTEEMIS ==="
        Get-LocalUser |
            Where-Object { $_.Name -in $addedUsers } |
            Select-Object Name, FullName
    }

    Exit 0
}

# =========================
# ===== KUSTUTAMINE =======
# =========================
ElseIf ($choice -eq "2") {

    $removableUsers = Get-LocalUser |
        Where-Object {
            $_.Enabled -eq $true -and
            $_.Name -notmatch "Administrator|DefaultAccount|Guest|WDAGUtilityAccount"
        } | Sort-Object Name

    If ($removableUsers.Count -eq 0) {
        Write-Host "Pole kustutatavaid kasutajaid."
        Exit 0
    }

    Write-Host "`nOLEMASOLEVAD KASUTAJAD:"
    for ($i = 0; $i -lt $removableUsers.Count; $i++) {
        $u = $removableUsers[$i]
        Write-Host ("{0,3}: {1} {2}" -f ($i+1), $u.Name, if ($u.FullName) {"($($u.FullName))"} else {""})
    }

    $sel = Read-Host "\nSisesta numbri(d) kustutamiseks (komaga eraldatud) või 'q' tühistamiseks"
    If ($sel -eq 'q' -or $sel -eq 'Q') { Write-Host 'Tühistatud.'; Exit 0 }

    $indices = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    If ($indices.Count -eq 0) { Write-Error 'Puudub kehtiv valik.'; Exit 1 }

    $toDelete = @()
    foreach ($n in $indices) {
        if ($n -ge 1 -and $n -le $removableUsers.Count) {
            $toDelete += $removableUsers[$n-1]
        }
    }

    If ($toDelete.Count -eq 0) { Write-Error 'Ükski valik ei olnud sobiv.'; Exit 1 }

    Write-Host "Valitud kustutatavad kasutajad:"
    $toDelete | ForEach-Object { Write-Host "- $($_.Name) $([string]::IsNullOrEmpty($_.FullName) ? '' : ' (' + $_.FullName + ')')" }

    $confirm = Read-Host "Kinnita kustutamine (Y/N)"
    If ($confirm -notin @('Y','y')) { Write-Host 'Tühistatud.'; Exit 0 }

    foreach ($u in $toDelete) {
        Try {
            $delUser = $u.Name
            $profilePath = "C:\Users\$delUser"
            If (Test-Path $profilePath) {
                Remove-Item $profilePath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "🗑 $delUser kaust eemaldatud (kui olemas)"
            }

            Remove-LocalUser -Name $delUser -ErrorAction Stop
            Write-Host "✅ Kasutaja $delUser kustutatud"
        }
        Catch {
            Write-Error "❌ $($u.Name) kustutamine ebaõnnestus: $_"
        }
    }

    Exit 0
}

Else {
    Write-Error "Vale valik!"
    Exit
}
