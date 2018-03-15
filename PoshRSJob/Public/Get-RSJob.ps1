Function Get-RSJob {
    <#
        .SYNOPSIS
            Gets runspace jobs that are currently available in the session.

        .DESCRIPTION
            Get-RSJob will display all jobs that are currently available to include completed and currently running jobs.
            If no parameters are given, all jobs are displayed to view.

        .PARAMETER Job
            Represents the RSJob object being sent to query for.

        .PARAMETER Name
            The name of the jobs to query for.

        .PARAMETER ID
            The ID of the jobs to query for.

        .PARAMETER InstanceID
            The GUID of the jobs to query for.

        .PARAMETER Batch
            Name of the set of jobs to query for.

        .PARAMETER State
            The State of the job that you want to display. Accepted values are:

            NotStarted
            Running
            Completed
            Failed
            Stopping
            Stopped
            Disconnected

        .PARAMETER HasMoreData
            Displays jobs that have data being outputted. You can specify -HasMoreData:$False to display jobs
            that have no data to output.

        .NOTES
            Name: Get-RSJob
            Author: Boe Prox/Max Kozlov

        .EXAMPLE
            Get-RSJob -State Completed

            Description
            -----------
            Displays a list of jobs which have completed.

        .EXAMPLE
            Get-RSJob -ID 1,5,78

            Id  Name                 State           HasMoreData  HasErrors    Command
            --  ----                 -----           -----------  ---------    -------
            1   Test_1               Completed       True         False        ...
            5   Test_5               Completed       True         False        ...
            78  Test_78              Completed       True         False        ...

            Description
            -----------
            Displays list of jobs with IDs 1,5,78.
    #>
    [OutputType('RSJob')]
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
        [parameter(ParameterSetName='Batch')]
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='InstanceID')]
        [parameter(ParameterSetName='All')]
        [Switch]$HasMoreData
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }
        Write-Debug "ParameterSet: $($PSCmdlet.parametersetname)"
        $SearchProps = New-Object System.Collections.ArrayList
        $ResultJobs = New-Object System.Collections.ArrayList
    }
    Process {
        Write-Debug "ParameterSet: $($PSCmdlet.ParameterSetName)"
        $Property = $PSCmdlet.ParameterSetName

        if ($PSCmdlet.ParameterSetName -eq 'Job') {
            Write-Verbose "Adding Job $($PSBoundParameters[$Property].Id)"
            foreach ($v in $PSBoundParameters[$Property]) {
               [void]$SearchProps.Add($v.ID)
            }
        }
        elseif ($PSCmdlet.ParameterSetName -ne 'All') {
            Write-Verbose "Adding $($PSBoundParameters[$Property])"
            $SearchProps.AddRange($PSBoundParameters[$Property])
        }
    }
    End {
        #Job objects searched by ID
        if ($Property -eq 'Job') { $Property = 'ID' }
        $States = if ($PSBoundParameters.ContainsKey('State')) { '^' + ($State -join '$|^') + '$' } else { '.' }

        # IF faster than any scriptblocks
        if ($Property -eq 'All') {
            Write-Verbose "Get all Jobs"
            $ResultJobs = $PoshRS_Jobs
        }
        else {
            Write-Verbose "Jobs by $Property"
            # And Hash much faster than foreach{ foreach {} } inner loop
            $Hash = @{}
            foreach ($jobobj in $PoshRS_Jobs) {
                $Hash[$jobobj.$Property] = $jobobj
            }
            foreach ($prop in $SearchProps) {
                if ($Hash.Contains($prop)) {
                    [void]$ResultJobs.Add($Hash[$prop])
                }
            }
        }
        foreach ($job in $ResultJobs) {
            if (($job.State -match $States) -and
                (-not $PSBoundParameters.ContainsKey('HasMoreData') -or $job.HasMoreData -eq $HasMoreData)
               )
            {
                $job
            }
        }
    }
}
