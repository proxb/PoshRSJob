Function Wait-RSJob {
    <#
        .SYNOPSIS
            Waits until all RSJobs are in one of the following states: 

        .DESCRIPTION
            Waits until all RSJobs are in one of the following states:

        .PARAMETER Name
            The name of the jobs to query for.

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
            Name tof the set of RSJobs

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
            Author: Ryan Bushe/Boe Prox
        Notes: This function is a slightly modified version of Get-RSJob by Boe Prox.(~10 lines of code changed)

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
        [parameter(ValueFromPipeline=$True,ParameterSetName='Job')]
        [RSJob[]]$Job,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
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
        [parameter(ParameterSetName='Batch')]
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='InstanceID')]
        [parameter(ParameterSetName='All')]
        [Switch]$HasMoreData,
        [int]$Timeout,
        [switch]$ShowProgress
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        Write-Verbose "ParameterSet: $($PSCmdlet.ParameterSetName)"
        $WaitJobs = New-Object System.Collections.ArrayList
        $Hash = @{}
        $Property = $PSCmdlet.ParameterSetName
        $IsPipeline = $true
        #Take care of bound parameters
        If ($PSBoundParameters['Name']) {
            $IsPipeline = $false
            foreach ($v in $Name) {
                $Hash.Add($v,1)
            }
        }
        If ($PSBoundParameters['Batch']) {
            $IsPipeline = $false
            foreach ($v in $Batch) {
                $Hash.Add($v,1)
            }
        }
        If ($PSBoundParameters['Id']) {
            $IsPipeline = $false
            foreach ($v in $Id) {
                $Hash.Add($v,1)
            }
        }
        If ($PSBoundParameters['InstanceId']) {
            $IsPipeline = $false
            foreach ($v in $InstanceId) {
                $Hash.Add($v,1)
            }
        }
        If ($PSBoundParameters['Job']){
            $IsPipeline = $false
            [void]$WaitJobs.AddRange($Job)
        }
    }
    Process {
        Write-Debug "ParameterSet: $($PSCmdlet.ParameterSetName)"
        if ($IsPipeline) {
            $Property = $PSCmdlet.ParameterSetName
            if ($PSCmdlet.ParameterSetName -eq 'Job') {
                [void]$WaitJobs.AddRange($Job)
            }
            elseif ($PSCmdlet.ParameterSetName -ne 'All') {
                Write-Verbose "Adding $($PSBoundParameters[$Property])"
                foreach ($v in $PSBoundParameters[$Property]) {
                    $Hash.Add($v,1)
                }
            }
        }
    }
    End {
        $WhereList = New-Object System.Collections.ArrayList
        if ($PSBoundParameters['State']) {
            [void]$WhereList.Add("`$_.State -match `"$($State -join '|')`"")
        }
        if ($PSBoundParameters.ContainsKey('HasMoreData')) {
            [void]$WhereList.Add("`$_.HasMoreData -eq `$$HasMoreData")
        }
        # IF faster than any scriptblocks
        if ($PSCmdlet.ParameterSetName -ne 'Job') {
            if ($PSCmdlet.ParameterSetName -eq 'All') {
                $WaitJobs = $PoshRS_Jobs
            }
            else {
                foreach ($job in $PoshRS_Jobs) {
                    if ($Hash.ContainsKey($job.$Property)) {
                        [void]$WaitJobs.Add($job)
                    }
                }
            }
        }
        if ($WaitJobs.Count -and $PSBoundParameters.ContainsKey('State')) {
            $States = '^' + $State -join '$|^' + '$'
            $WaitJobs = foreach ($job in $WaitJobs) {
                if ($job.State -match $States) {
                    $job
                }
            }
        }
        if ($WaitJobs.Count -and $PSBoundParameters.ContainsKey('HasMoreData')) {
            $WaitJobs = foreach ($job in $WaitJobs) {
                if ($job.HasMoreData -eq $HasMoreData) {
                    $job
                }
            }
        }
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
            If ($PSBoundParameters.ContainsKey('ShowProgress')) {
                Write-Progress -Activity "RSJobs Tracker" -Status ("Remaining Jobs: {0}" -f $Waitjobs.Count) -PercentComplete (($Completed/$TotalJobs)*100)
            }
            if($Timeout -and (New-Timespan $Date).TotalSeconds -ge $Timeout){
                break
            }
        }
    }
}
