Function Remove-RSJob {
    <#
        .SYNOPSIS
            Deletes a Windows PowerShell runspace job.

        .DESCRIPTION
            Deletes a Windows PowerShell background job that has been started using Start-RSJob

        .PARAMETER Name
            The name of the jobs to remove..

        .PARAMETER ID
            The ID of the jobs to remove.

        .PARAMETER InstanceID
            The GUID of the jobs to remove.

        .PARAMETER Batch 
            Name of the set of jobs
            
        .PARAMETER Job
            The job object to remove.  
            
        .PARAMETER Force
            Force a running job to stop prior to being removed.        

        .NOTES
            Name: Remove-RSJob
            Author: Boe Prox                

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
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
        [int[]]$Id,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Guid')]
        [guid[]]$InstanceID,
        [parameter(ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Batch')]
        [string[]]$Batch,
        [parameter(ValueFromPipeline=$True,ParameterSetName='Job')]
        [RSJob[]]$Job,
        [parameter()]
        [switch]$Force
    )
    Begin {        
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }      
        $List = New-Object System.Collections.ArrayList
        $StringBuilder = New-Object System.Text.StringBuilder

        #Take care of bound parameters
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
        If ($PSBoundParameters['Job']) {
            [void]$list.AddRange($Job)
            $Bound = $True
        }
    }
    Process {
        If (-Not $Bound) {
            [void]$List.Add($_)
        }
    }
    End {
        Write-Debug "ParameterSet: $($PSCmdlet.parametersetname)"
        Switch ($PSCmdlet.parametersetname) {
            'Name' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|') -replace '\*','.*'
                [void]$StringBuilder.Append("`$_.Name -match $Items") 
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())                    
            }
            'Id' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$StringBuilder.Append("`$_.Id -match $Items") 
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())                
            }
            'Guid' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$StringBuilder.Append("`$_.InstanceId -match $Items")   
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())   
            }
            'Batch' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$StringBuilder.Append("`$_.batch -match $Items")   
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())   
            } 	
            Default {$ScriptBlock=$Null}
        }
        If ($ScriptBlock) {
            Write-Verbose "Using ScriptBlock"
            $ToRemove = $PoshRS_jobs | Where $ScriptBlock
        } Else {
            $ToRemove = $List
        }
        [System.Threading.Monitor]::Enter($PoshRS_Jobs.syncroot) 
        $ToRemove | ForEach {
            If ($PSCmdlet.ShouldProcess("Name: $($_.Name), associated with JobID $($_.Id)",'Remove')) {
                If ($_.State -notmatch 'Completed|Failed|Stopped') {
                    If ($PSBoundParameters.ContainsKey('Force')) {
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
        [System.Threading.Monitor]::Exit($PoshRS_Jobs.syncroot) 
    }
}
