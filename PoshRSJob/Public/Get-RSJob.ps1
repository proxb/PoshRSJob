Function Get-RSJob {
    <#
        .SYNOPSIS
            Gets runspace jobs that are currently available in the session.

        .DESCRIPTION
            Get-RSJob will display all jobs that are currently available to include completed and currently running jobs.
            If no parameters are given, all jobs are displayed to view.

        .PARAMETER Name
            The name of the jobs to query for.

        .PARAMETER ID
            The ID of the jobs that you want to display.

        .PARAMETER InstanceID
            The GUID of the jobs that you want to display.

        .PARAMETER State
            The State of the job that you want to display. Accepted values are:

            NotStarted
            Running
            Completed
            Failed
            Stopping
            Stopped
            Disconnected

        .PARAMETER Batch 
            Name of the set of jobs

        .PARAMETER HasMoreData
            Displays jobs that have data being outputted. You can specify -HasMoreData:$False to display jobs
            that have no data to output.            

        .NOTES
            Name: Get-RSJob
            Author: Boe Prox                

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
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
        [int[]]$Id,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Guid')]
        [guid[]]$InstanceID,
        [parameter(ParameterSetName='Batch')]
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='Guid')]
        [parameter(ParameterSetName='All')]
        [ValidateSet('NotStarted','Running','Completed','Failed','Stopping','Stopped','Disconnected')]
        [string[]]$State,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Batch')]
        [string[]]$Batch,
        [parameter(ParameterSetName='Batch')]
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='Guid')]
        [parameter(ParameterSetName='All')]
        [Switch]$HasMoreData,
        [parameter(ValueFromPipeline=$True,ParameterSetName='Job')]
        [RSJob[]]$Job        
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        Write-Debug "ParameterSet: $($PSCmdlet.parametersetname)"
        $List = New-Object System.Collections.ArrayList
        $WhereList = New-Object System.Collections.ArrayList
        
        #Take care of bound parameters
        $Bound = $False
        If ($PSBoundParameters['Name']) {
            [void]$list.AddRange($Name)
            $Bound = $True
        }
        If ($PSBoundParameters['Batch']) {
            [void]$list.AddRange($Batch)
            $Bound = $True
        }
        If ($PSBoundParameters['Id']) {
            [void]$list.AddRange($Id)
            $Bound = $True
        }
        If ($PSBoundParameters['InstanceId']) {
            [void]$list.AddRange($InstanceId)
            $Bound = $True
        }
        If ($PSBoundParameters['Job']){
            [void]$list.AddRange($Job)
            $Bound = $True
        }                
    }
    Process {
        If ($PSCmdlet.ParameterSetName -ne 'All' -AND -NOT $Bound) {
            Write-Verbose "Adding $($_)"
            [void]$List.Add($_)
        }
    }
    End {        
        Switch ($PSCmdlet.parametersetname) {
            'Name' {
                $Items = '"{0}"' -f (($list | ForEach-Object {"^{0}$" -f $_}) -join '|') -replace '\*','.*'
                [void]$WhereList.Add("`$_.Name -match $Items")                    
            }
            'Id' {
                $Items = '"{0}"' -f (($list | ForEach-Object {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.Id -match $Items")                
            }
            'Guid' {
                $Items = '"{0}"' -f (($list | ForEach-Object {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.InstanceId -match $Items")  
            }
            'Job' {
                $Items = '"{0}"' -f (($list | ForEach-Object {"^{0}$" -f $_.Id}) -join '|')
                [void]$WhereList.Add("`$_.id -match $Items")
            }   
            'Batch' {
                $Items = '"{0}"' -f (($list | ForEach-Object {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.batch -match $Items")
            }                      
        }
        If ($PSBoundParameters['State']) {
            [void]$WhereList.Add("`$_.State -match `"$($State -join '|')`"")
        }
        If ($PSBoundParameters.ContainsKey('HasMoreData')) {
            [void]$WhereList.Add("`$_.HasMoreData -eq `$$HasMoreData")
        }
        Write-Debug "WhereListCount: $($WhereList.count)"
        If ($WhereList.count -gt 0) {
            $WhereString = $WhereList -join ' -AND '
            $WhereBlock = [scriptblock]::Create($WhereString)
            Write-Debug "WhereString: $($WhereString)" 
            Write-Verbose "Using scriptblock"
            $PoshRS_Jobs | Where-Object $WhereBlock 
        } Else {
            $PoshRS_Jobs
        }
    }
}
