[Environment]::SetEnvironmentVariable( "Path", $env:Path, [System.EnvironmentVariableTarget]::Machine )
[Environment]::SetEnvironmentVariable( "INCLUDE", $env:INCLUDE, [System.EnvironmentVariableTarget]::User )
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$PSScriptRoot", [EnvironmentVariableTarget]::Machine)

if ((Get-Command "cfssl.exe" -ErrorAction SilentlyContinue) -eq $null) 
{ 
   $url = "https://pkg.cfssl.org/R1.2/cfssl_windows-amd64.exe"
   $output = "$PSScriptRoot\cfssl.exe"
   $start_time = Get-Date
   Invoke-WebRequest -Uri $url -OutFile $output
   Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}

if ((Get-Command "cfssljson.exe" -ErrorAction SilentlyContinue) -eq $null) 
{ 
   $url = "https://pkg.cfssl.org/R1.2/cfssljson_windows-amd64.exe"
   $output = "$PSScriptRoot\cfssljson.exe"
   $start_time = Get-Date
   Invoke-WebRequest -Uri $url -OutFile $output
   Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
}





