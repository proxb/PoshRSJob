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
        [PoshRS.PowerShell.RSJob[]]$Job,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
        [int[]]$Id,
        [parameter(ValueFromPipelineByPropertyName=$True,
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
		[int]$Timeout,
        [switch]$ShowProgress
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        Write-Verbose "ParameterSet: $($PSCmdlet.parametersetname)"
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
                $Items = '"{0}"' -f (($list | Select -Expand id | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$WhereList.Add("`$_.id -match $Items")
            }			
        }
        If ($PSBoundParameters['State']) {
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
            Write-Verbose "WhereString: $($WhereString)" 
            Write-Verbose "Using scriptblock"
            $FilteredJobs = @($list | Where $ScriptBlock)
            $WaitJobs = $FilteredJobs
            $TotalJobs = $FilteredJobs.Count
            Write-Verbose "$($FilteredJobs.Count)"
            $Date = Get-Date
            Do{               
            	$JustFinishedJobs = @($Waitjobs | Where {
            	    #Since the jobs' state can change independent of this cmdlet we only check it once per loop for consistency
            	    $_.State -match 'Completed|Failed|Stopped|Suspended|Disconnected'
                })
              
                #reuse $JustFinishedJobs to determine $WaitJobs in case a job state has changed between then and now for consistency
                #Update $WaitJobs so the next loop cana determine the differences between this loop and the next for the $JustFinishedJobs to output
                $Waitjobs = $Waitjobs | Where { $_.ID -notin $JustFinishedJobs.ID }

                #Wait just a bit so the HasMoreData can update if needed
                Start-Sleep -Milliseconds 100
                $JustFinishedJobs

                $Completed += $JustFinishedJobs.Count
		Write-Verbose "Wait: $($Waitjobs.Count)"
                Write-Verbose "Completed: ($Completed)"
                Write-Verbose "Total: ($Totaljobs)"
                Write-Verbose "Status: $($Completed/$TotalJobs)"
                If ($PSBoundParameters.ContainsKey('ShowProgress')) {
                    Write-Progress -Activity "RSJobs Tracker" -Status ("Remaining Jobs: {0}" -f $Waitjobs.Count) -PercentComplete (($Completed/$TotalJobs)*100)
                }
		if($Timeout){
		    if((New-Timespan $Date).TotalSeconds -ge $Timeout){
		        $TimedOut = $True
		        break
		    }
		}		
	    } 
            While($Waitjobs.Count -ne 0)
        }
    }
}
