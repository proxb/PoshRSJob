Function Remove-RSJob {
    <#
        .SYNOPSIS
            Deletes a Windows PowerShell runspace job.

        .DESCRIPTION
            Deletes a Windows PowerShell background job that has been started using Start-RSJob

        .PARAMETER Job
            The job object to remove.

        .PARAMETER Name
            The name of the jobs to remove..

        .PARAMETER ID
            The ID of the jobs to remove.

        .PARAMETER InstanceID
            The GUID of the jobs to remove.

        .PARAMETER Batch
            Name of the set of jobs to remove.

        .PARAMETER Force
            Force a running job to stop prior to being removed.

        .NOTES
            Name: Remove-RSJob
            Author: Boe Prox/Max Kozlov

        .EXAMPLE
            Get-RSJob -State Completed | Remove-RSJob

            Description
            -----------
            Deletes all jobs with a State of Completed.

            .EXAMPLE
            Remove-RSJob -ID 1,5,78

            Description
            -----------
            Removes jobs with IDs 1,5,78.
    #>
    [cmdletbinding(
        DefaultParameterSetName='Job',
        SupportsShouldProcess = $True
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
        [string[]]$Batch,

        [parameter()]
        [switch]$Force
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
        [void]$PSBoundParameters.Remove('Force')
        [array]$ToRemove = Get-RSJob @PSBoundParameters
        if ($ToRemove.Count) {
            [System.Threading.Monitor]::Enter($PoshRS_Jobs.syncroot)
            try {
                $ToRemove | ForEach-Object {
                    If ($PSCmdlet.ShouldProcess("Name: $($_.Name), associated with JobID $($_.Id)",'Remove')) {
                        If ($_.State -notmatch 'Completed|Failed|Stopped') {
                            If ($Force) {
                                [void] $_.InnerJob.Stop()
                                $PoshRS_Jobs.Remove($_)
                            } Else {
                                Write-Error "Unable to remove job $($_.InstanceID)"
                            }
                        } Else {
                            [void]$PoshRS_Jobs.Remove($_)
                        }
                    }
                }
            }
            finally {
                [System.Threading.Monitor]::Exit($PoshRS_Jobs.syncroot)
            }
        }
    }
}
