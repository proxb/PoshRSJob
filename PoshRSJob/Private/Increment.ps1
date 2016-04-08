Function Increment {
    Write-Verbose "Incrementing job ID"
    Set-Variable -Name PoshRS_JobId -Value ($PoshRS_JobId + 1) -Force -Scope Script
    Write-Output $PoshRS_JobId
}