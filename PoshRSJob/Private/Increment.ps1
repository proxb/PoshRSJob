Function Increment {
    Set-Variable -Name JobId -Value ($JobId + 1) -Force -Scope Global
    Write-Output $JobId
}