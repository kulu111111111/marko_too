# ================== SEADISTUS ==================

# Sisendfailid (zipist lahti pakitud)
$FirstNameFile = "eesnimed.txt"
$LastNameFile  = "perenimed.txt"
$DescFile      = "kirjeldused.txt"

# Väljundfail
$OutputCsv = "new_users_accounts.csv"

# Kasutajate arv
$UserCount = 5

# Paroolisätted - täidetakse Set-PasswordMode funktsiooniga
$UseStaticPassword = $false
$StaticPassword = ""

# Määra UTF-8 kodeeringu konsooli väljundile
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# ================== FUNKTSIOONID ==================

function Set-PasswordMode {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Paroolisätteid" -ForegroundColor Green
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

    $map = @{
        'ä' = 'a'
        'ö' = 'o'
        'ü' = 'u'
        'õ' = 'o'
        'š' = 's'
        'ž' = 'z' 
    }

    foreach ($key in $map.Keys) {
        $Text = [regex]::Replace($Text, $key, $map[$key], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $Text
}

function New-RandomPassword {
    $length = Get-Random -Minimum 5 -Maximum 9
    -join ((48..57 + 97..122) | Get-Random -Count $length | ForEach-Object {[char]$_})
}

# ================== ANDMETE LUGEMINE ==================

Set-PasswordMode

$FirstNames = Get-Content $FirstNameFile
$LastNames  = Get-Content $LastNameFile
$Descs      = Get-Content $DescFile

# ================== CSV PÄIS ==================

"Nimi;Kasutajanimi;Parool;Kirjeldus" | Set-Content $OutputCsv -Encoding UTF8 -Force

# ================== KASUTAJATE LOOMINE ==================

for ($i = 1; $i -le $UserCount; $i++) {

    $FirstName = Get-Random -InputObject $FirstNames
    $LastName  = Get-Random -InputObject $LastNames
    $Desc      = Get-Random -InputObject $Descs

    $Username = "$FirstName.$LastName"
    $Username = $Username -replace "[\s-]", ""
    $Username = Remove-Diacritics $Username
    $Username = $Username.ToLower()

    if ($UseStaticPassword) {
        $Password = $StaticPassword
    } else {
        $Password = New-RandomPassword
    }

    "$FirstName $LastName;$Username;$Password;$Desc" |
        Add-Content $OutputCsv -Encoding UTF8

    # Konsooli info
    $ShortDesc = $Desc.Substring(0, [Math]::Min(10, $Desc.Length))
    Write-Host "Kasutaja loodud: $FirstName $LastName | $Username | $Password | $ShortDesc..."
}
# ================== LÕPP ==================
