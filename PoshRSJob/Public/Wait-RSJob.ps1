Function Wait-RSJob {
    <#
        .SYNOPSIS
            Waits until all RSJobs are in one of the following states:

        .DESCRIPTION
            Waits until all RSJobs are in one of the following states:

        .PARAMETER Job
            The job object to wait for.

        .PARAMETER Name
            The name of the jobs to wait for.

        .PARAMETER ID
            The ID of the jobs that you want to wait for.

        .PARAMETER InstanceID
            The GUID of the jobs that you want to wait for.

        .PARAMETER State
            The State of the job that you want to wait for. Accepted values are:
            NotStarted
            Running
            Completed
            Failed
            Stopping
            Stopped
            Disconnected

        .PARAMETER Batch
            Name of the set of jobs that you want to wait for.

        .PARAMETER HasMoreData
            Waits for jobs that have data being outputted. You can specify -HasMoreData:$False to wait for jobs
            that have no data to output.

        .PARAMETER Timeout
            Timeout after specified number of seconds. This is a global timeout meaning that it is not a per
            job timeout.

        .PARAMETER ShowProgress
            Displays a progress bar

        .NOTES
            Name: Wait-RSJob
            Author: Ryan Bushe/Boe Prox/Max Kozlov

        .EXAMPLE
            Get-RSJob | Wait-RSJob
            Description
            -----------
            Waits for jobs which have to be completed.
    #>
    [cmdletbinding(
        DefaultParameterSetName='All'
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

        [parameter(ParameterSetName='Batch')]
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='InstanceID')]
        [parameter(ParameterSetName='All')]
        [ValidateSet('NotStarted','Running','Completed','Failed','Stopping','Stopped','Disconnected')]
        [string[]]$State,
        [int]$Timeout,
        [switch]$ShowProgress
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
        if ($PSCmdlet.ParameterSetName -ne 'All' -and $PSBoundParameters[$Property]) {
            Write-Verbose "Adding $($PSBoundParameters[$Property])"
            [void]$List.AddRange($PSBoundParameters[$Property])
        }
    }
    End {
        if ($PSCmdlet.ParameterSetName -ne 'All') {
            $PSBoundParameters[$Property] = $List
        }
        if (-not $List.Count) { return } # No jobs selected to search
        [void]$PSBoundParameters.Remove('Timeout')
        [void]$PSBoundParameters.Remove('ShowProgress')
        [array]$WaitJobs = Get-RSJob @PSBoundParameters

        $TotalJobs = $WaitJobs.Count
        $Completed = 0
        Write-Verbose "Wait for $($TotalJobs) jobs"
        $Date = Get-Date
        while ($Waitjobs.Count -ne 0) {
            Start-Sleep -Milliseconds 100
            #only ever check $WaitJobs State once per loop, and do all operations based on that snapshot to avoid bugs where the state of a job may have changed mid loop
            $JustFinishedJobs = New-Object System.Collections.ArrayList
            $RunningJobs = New-Object System.Collections.ArrayList
            ForEach ($WaitJob in $WaitJobs) {
                If($WaitJob.State -match 'Completed|Failed|Stopped|Suspended|Disconnected' -and $WaitJob.Completed) {
                    [void]$JustFinishedJobs.Add($WaitJob)
                } Else {
                    [void]$RunningJobs.Add($WaitJob)
                }
            }
            $WaitJobs = $RunningJobs

            $JustFinishedJobs

            $Completed += $JustFinishedJobs.Count
            Write-Debug "Wait: $($Waitjobs.Count)"
            Write-Debug "Completed: ($Completed)"
            Write-Debug "Total: ($Totaljobs)"
            Write-Debug "Status: $($Completed/$TotalJobs)"
            If ($ShowProgress) {
                Write-Progress -Activity "RSJobs Tracker" -Status ("Remaining Jobs: {0}" -f $Waitjobs.Count) -PercentComplete (($Completed/$TotalJobs)*100)
            }
            if($Timeout -and (New-Timespan $Date).TotalSeconds -ge $Timeout){
                break
            }
        }
        If ($ShowProgress) {
            Write-Progress -Activity "RSJobs Tracker" -Completed
        }
    }
}
