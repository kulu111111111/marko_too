#Requires -RunAsAdministrator

# Sunni konsool UTF-8 režiimi, et täpitähed oleksid loetavad
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Kontroll admin õiguste jaoks
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Skript peab jooksma administraatori õigustes!"
    Exit 1
}

$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "new_users_accounts.csv"

If (!(Test-Path $csvPath)) {
    Write-Error "Faili new_users_accounts.csv ei leitud ($csvPath)!"
    Exit 1
}

# Lae CSV õige kodeeringuga (PS5.1 jaoks -Encoding UTF8 on tavaliselt BOM-iga)
$users = Import-Csv $csvPath -Delimiter ";" -Encoding UTF8

Write-Host "`n--- KASUTAJATE HALDUS ---" -ForegroundColor Yellow
Write-Host "1 - Lisa kõik kasutajad failist"
Write-Host "2 - Kustuta kasutajaid valiku põhjal"
Write-Host "q - Välju"
$choice = Read-Host "Vali tegevus"

if ($choice -eq "1") {
    # ... (Lisamise loogika jääb samaks, aga kontrolli et New-LocalUser saaks puhta nime)
    foreach ($user in $users) {
        if ([string]::IsNullOrWhiteSpace($user.Kasutajanimi)) { continue }
        
        if (Get-LocalUser -Name $user.Kasutajanimi -ErrorAction SilentlyContinue) {
            Write-Warning "Kasutaja $($user.Kasutajanimi) on juba olemas."
            continue
        }

        $password = ConvertTo-SecureString $user.Parool -AsPlainText -Force
        New-LocalUser -Name $user.Kasutajanimi -FullName $user.Nimi -Description $user.Kirjeldus -Password $password -PasswordNeverExpires:$false
        Add-LocalGroupMember -Group "Users" -Member $user.Kasutajanimi
        Set-LocalUser -Name $user.Kasutajanimi -PasswordExpired $true
        Write-Host "✅ Lisatud: $($user.Kasutajanimi)" -ForegroundColor Green
    }
}

elseif ($choice -eq "2") {
    # KUSTUTAMISE OSA, MIDA ÕPETAJA SOOVIS LIHTSUSTADA
    $allUsers = Get-LocalUser | Where-Object { $_.Name -notmatch "Administrator|Guest|DefaultAccount|WDAGUtilityAccount" } | Sort-Object Name
    
    if ($allUsers.Count -eq 0) {
        Write-Host "Süsteemis pole ühtegi tavakasutajat."
        exit
    }

    Write-Host "`nVALI KASUTAJA(D) KUSTUTAMISEKS:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $allUsers.Count; $i++) {
        Write-Host (" {0,2} ] {1,-20} ({2})" -f ($i + 1), $allUsers[$i].Name, $allUsers[$i].FullName)
    }

    Write-Host "`n(Näide: 1 või 1,3,5)" -ForegroundColor Gray
    $input = Read-Host "Sisesta numbri(d) või 'q' tühistamiseks"
    
    if ($input -eq 'q') { exit }

    # Töötle sisestatud numbrid
    $indices = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    
    foreach ($idx in $indices) {
        $num = [int]$idx - 1
        if ($num -ge 0 -and $num -lt $allUsers.Count) {
            $target = $allUsers[$num].Name
            
            # Kustutame kasutaja
            Try {
                Remove-LocalUser -Name $target -Confirm:$false -ErrorAction Stop
                Write-Host "🗑️ Kasutaja $target on eemaldatud." -ForegroundColor Red
                
                # Valikuline: Kustuta ka profiili kaust
                $profilePath = "C:\Users\$target"
                if (Test-Path $profilePath) {
                    Remove-Item $profilePath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "   - Profiili kaust eemaldatud." -ForegroundColor Gray
                }
            } Catch {
                Write-Warning "Viga $target kustutamisel: $($_.Exception.Message)"
            }
        }
    }
}