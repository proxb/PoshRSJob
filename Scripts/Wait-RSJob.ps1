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
        .PARAMETER HasMoreData
            Waits for jobs that have data being outputted. You can specify -HasMoreData:$False to wait for jobs
            that have no data to output.
		.PARAMETER Timeout
			Timeout after specified number of seconds
        .NOTES
            Name: Wait-RSJob
            Author: Ryan Bushe/
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
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
        [int[]]$Id,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Guid')]
        [guid[]]$InstanceID,
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='Guid')]
        [parameter(ParameterSetName='All')]
        [ValidateSet('NotStarted','Running','Completed','Failed','Stopping','Stopped','Disconnected')]
        [string[]]$State,
        [parameter(ParameterSetName='Name')]
        [parameter(ParameterSetName='Id')]
        [parameter(ParameterSetName='Guid')]
        [parameter(ParameterSetName='All')]
        [Switch]$HasMoreData,
        [parameter(ValueFromPipeline=$True,ParameterSetName='Job')]
        [PoshRS.PowerShell.RSJob[]]$Job,
		[int]$Timeout
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        Write-Debug "ParameterSet: $($PSCmdlet.parametersetname)"
        $List = New-Object System.Collections.ArrayList
        $WhereList = New-Object System.Collections.ArrayList
        
        #Take care of bound parameters
        If ($PSBoundParameters['Name']) {
            [void]$list.AddRange($Name)
        }
        If ($PSBoundParameters['Id']) {
            [void]$list.AddRange($Id)
        }
        If ($PSBoundParameters['InstanceId']) {
            [void]$list.AddRange($InstanceId)
        }
		If ($PSBoundParameters['Job']){
			[void]$list.AddRange($Job)
		}		
    }
    Process {
        If ($PSCmdlet.ParameterSetName -ne 'All') {
            Write-Verbose "Adding $($_)"
            [void]$List.Add($_)
        }
    }
    End {        
        Switch ($PSCmdlet.parametersetname) {
            'Name' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|') -replace '\*','.*'
                [void]$WhereList.Add("`$_.Name -match $Items")                    
            }
            'Id' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.Id -match $Items")                
            }
            'Guid' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.InstanceId -match $Items")  
            }
            'Job' {
                $Items = '"{0}"' -f (($list.id | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.id -match $Items")
            }			
        }
        If ($PSBoundParameters['State']) {get-
            [void]$WhereList.Add("`$_.State -match `"$($State -join '|')`"")
        }
        If ($PSBoundParameters.ContainsKey('HasMoreData')) {
            [void]$WhereList.Add("`$_.HasMoreData -eq `$$HasMoreData")
        }
        If ($WhereList.count -gt 0) {
            $WhereString = $WhereList -join ' -AND '
            $ScriptBlock = [scriptblock]::Create($WhereString)
        }               
        If ($ScriptBlock) {
            Write-Debug "WhereString: $($WhereString)" 
            Write-Verbose "Using scriptblock"
            $FilteredJobs = $Jobs | Where $ScriptBlock
			$Date = Get-Date
			Do{
				$Waitjobs = $FilteredJobs | Where $ScriptBlock | Where {
                    $_.State -notmatch 'Completed|Failed|Stopped|Suspended|Disconnected'
                }
				Write-Verbose "$($Waitjobs.Count) Jobs Left"
				if($Timeout){
					if((New-Timespan $Date).TotalSeconds -ge $Timeout){
						$TimedOut = $True
                        break;
					}
				}
			}While($Waitjobs.Count -ne 0)
        }
        If (-NOT $TimedOut) {
            $FilteredJobs
        }
    }
}