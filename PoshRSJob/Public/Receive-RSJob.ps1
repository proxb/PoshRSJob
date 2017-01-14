Function Receive-RSJob {
    <#
        .SYNOPSIS
            Gets the results of the Windows PowerShell runspace jobs in the current session.

        .DESCRIPTION
            Gets the results of the Windows PowerShell runspace jobs in the current session. You can use
            Get-RSJob and pipe the results into this function to get the results as well.

        .PARAMETER InputObject
            Represents the RSJob object being sent to command.

        .PARAMETER Name
            The name of the jobs to receive available data from.

        .PARAMETER ID
            The ID of the jobs to receive available data from.

        .PARAMETER InstanceID
            The GUID of the jobs to receive available data from.         
            
        .PARAMETER Batch 
            Name of the set of jobs             

        .NOTES
            Name: Receive-RSJob
            Author: Boe Prox                

        .EXAMPLE
            Get-RSJob -State Completed | Receive-RSJob

            Description
            -----------
            Retrieves any available data that is outputted from completed RSJobs.

        .EXAMPLE
            Receive-RSJob -ID 1,5,78

            Description
            -----------
            Receives data from RSJob with IDs 1,5,78.

        .EXAMPLE
            Receive-RSJob -InputObject (Get-RSJob)

            Description
            -----------
            Receives data from all RSJobs.
    #>
    [cmdletbinding(
        DefaultParameterSetName='Job'
    )]
    Param (
        [parameter(Position=0,ValueFromPipeline=$True,ParameterSetName='Job')]
        [RSJob[]]$InputObject,
        [parameter(Position=1,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Name')]
        [string[]]$Name,
        [parameter(Position=2,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Id')]
        [int[]]$Id,
        [parameter(Position=3,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Guid')]
        [guid[]]$InstanceID,
        [parameter(Position=4,ValueFromPipelineByPropertyName=$True,
        ParameterSetName='Batch')]
        [string[]]$Batch
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        $List = New-Object System.Collections.ArrayList
        $StringBuilder = New-Object System.Text.StringBuilder
        $Bound = $False
        $IsInputObject = $False

        #Take care of bound parameters
        If ($PSBoundParameters['Name']) {
            [void]$list.AddRange($Name)
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
        If ($PSBoundParameters['InputObject']) {
            $IsInputObject = $True
            [void]$list.AddRange($InputObject)
            $Bound = $True
        }
        If ($PSBoundParameters['Batch']) {
            [void]$list.AddRange($Batch)
            $Bound = $True
        }
        Write-Debug "Bound: $Bound"
    }
    Process {
        If (-NOT $Bound -and $InputObject) {
            $IsInputObject = $True
            $_ | WriteStream
            if (@("Completed", "Failed", "Stopped") -contains $_.State) { 
                $_ | SetIsReceived -SetTrue
            }
        }
        elseif (-Not $Bound) {
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
        Write-Debug "ScriptBlock: $($ScriptBlock)"
        If ($ScriptBlock) {
            Write-Debug "Running Scriptblock"
            $PoshRS_jobs | Where $ScriptBlock | ForEach-Object{ 
                $_ | WriteStream
                if (@("Completed", "Failed", "Stopped") -contains $_.State) { 
                    $_ | SetIsReceived -SetTrue
                }
            }
        } 
        ElseIf ($IsInputObject) {
            $List | ForEach-Object{ 
                $_ | WriteStream
                if (@("Completed", "Failed", "Stopped") -contains $_.State) { 
                    $_ | SetIsReceived -SetTrue
                }
            }            
        }
        ElseIf ($Bound) {
            $PoshRS_jobs | ForEach-Object{ 
                $_ | WriteStream
                if (@("Completed", "Failed", "Stopped") -contains $_.State) { 
                    $_ | SetIsReceived -SetTrue
                }
            }
        }
    }
}

