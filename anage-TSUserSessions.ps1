# Läs servernamn från filen
$servers = Get-Content "C:\path\to\your\file.txt"

# Skapa en tom tabell för att lagra resultaten
$results = @()

# Loopa igenom varje server
foreach ($server in $servers) {
    # Kör 'quser' kommandot på servern och samla resultaten
    $users = Invoke-Command -ComputerName $server -ScriptBlock { quser } 2>$null | ForEach-Object {
        # Omvandla varje rad till en PSObject
        $userProps = $_.Trim() -split "\s+"
        if ($userProps[0] -eq ">") {
            $userProps = $userProps[1..$userProps.Length]
        }
        New-Object PSObject -Property @{
            SERVER = $server
            USERNAME = $userProps[0]
            ID = $userProps[2]
        }
    }

    # Lägg till resultaten till tabellen
    $results += $users
}

# Skapa en ny tom tabell för slutresultaten
$finalResults = @()

# Loopa igenom varje unikt användarnamn
foreach ($username in ($results.USERNAME | Sort-Object -Unique)) {
    # Skapa en rad för användaren
    $userRow = New-Object PSObject -Property @{ USERNAME = $username }

    # Loopa igenom varje server
    foreach ($server in $servers) {
        # Kolla om användaren är inloggad på servern
        if (($userResult = $results | Where-Object { $_.SERVER -eq $server -and $_.USERNAME -eq $username }) -ne $null) {
            # Om de är inloggade, visa 'X'
            $userRow | Add-Member -MemberType NoteProperty -Name $server -Value "X"
            # Lägg till användarens ID till raden
            $userRow | Add-Member -MemberType NoteProperty -Name ($server + "_ID") -Value $userResult.ID
        } else {
            # Annars, visa '-'
            $userRow | Add-Member -MemberType NoteProperty -Name $server -Value "-"
            $userRow | Add-Member -MemberType NoteProperty -Name ($server + "_ID") -Value $null
        }
    }

    # Lägg till raden till slutresultaten
    $finalResults += $userRow
}

# Visa slutresultaten i en GridView
$finalResults | Out-GridView -Title "Logged in Users"

# Fråga användaren vilken användare och server de vill logga ut
$selectedUser = $finalResults | Out-GridView -Title "Select User to Logoff" -OutputMode Single
if ($selectedUser) {
    $selectedServer = $servers | Out-GridView -Title "Select Server to Logoff from" -OutputMode Single
    if ($selectedServer) {
        # Logga ut den valda användaren från den valda servern
        $selectedUserId = $selectedUser.($selectedServer + "_ID")
        if ($selectedUserId) {
            Invoke-Command -ComputerName $selectedServer -ScriptBlock { param($id) logoff $id } -ArgumentList $selectedUserId
        }
    }
}
