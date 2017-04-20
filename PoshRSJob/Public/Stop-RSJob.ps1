Function Stop-RSJob {
    <#
        .SYNOPSIS
            Stops a Windows PowerShell runspace job.

        .DESCRIPTION
            Stops a Windows PowerShell background job that has been started using Start-RSJob

        .PARAMETER Job
            The job object to stop.

        .PARAMETER Name
            The name of the jobs to stop..

        .PARAMETER ID
            The ID of the jobs to stop.

        .PARAMETER InstanceID
            The GUID of the jobs to stop.

        .PARAMETER Batch
            Name of the set of jobs to stop.

        .NOTES
            Name: Stop-RSJob
            Author: Boe Prox/Max Kozlov

        .EXAMPLE
            Get-RSJob -State Completed | Stop-RSJob

            Description
            -----------
            Stop all jobs with a State of Completed.

            .EXAMPLE
            Stop-RSJob -ID 1,5,78

            Description
            -----------
            Stop jobs with IDs 1,5,78.
    #>
    [cmdletbinding(
        DefaultParameterSetName='Job'
    )]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Job', Position=0)]
        [Alias('InputObject')]
        [RSJob[]]$Job,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Name', Position=0)]
        [string[]]$Name,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id', Position=0)]
        [int[]]$Id,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='InstanceID')]
        [string[]]$InstanceID,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Batch')]
        [string[]]$Batch
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }
        $List = New-Object System.Collections.ArrayList
    }
    Process {
        Write-Debug "ParameterSet: $($PSCmdlet.ParameterSetName)"
        $Property = $PSCmdlet.ParameterSetName
        if ($PSBoundParameters[$Property]) {
            Write-Verbose "Adding $($PSBoundParameters[$Property])"
            [void]$List.AddRange($PSBoundParameters[$Property])
        }
    }
    End {
        if (-not $List.Count) { return } # No jobs selected to search
        $PSBoundParameters[$Property] = $List
        [array]$ToStop = Get-RSJob @PSBoundParameters

        If ($ToStop.Count) {
            [System.Threading.Monitor]::Enter($PoshRS_jobs.syncroot)
            try {
                $ToStop | ForEach-Object {
                    Write-Verbose "Stopping $($_.InstanceId)"
                    if ($_.State -ne 'Completed') {
                        Write-Verbose "Killing job $($_.InstanceId)"
                        [void] $_.InnerJob.Stop()
                    }
                }
            }
            finally {
                [System.Threading.Monitor]::Exit($PoshRS_jobs.syncroot)
            }
        }
    }
}
