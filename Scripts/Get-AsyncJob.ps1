Function Get-AsyncJob {
    [OutputType('PSAsync.PowerShell.AsyncJob')]
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
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [ValidateSet('Running','Completed')]
        [string]$State,
        [parameter()]
        [boolean]$HasMoreData
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
        }
        If ($PSBoundParameters['Id']) {
            [void]$list.AddRange($Id)
        }
        If ($PSBoundParameters['InstanceId']) {
            [void]$list.AddRange($InstanceId)
        }
    }
    Process {
        If ($PSCmdlet.ParameterSetName -ne 'All') {
            Write-Verbose "Adding $($_)"
            [void]$List.Add($_)
        }
    }
    End {
        Write-Debug "ParameterSet: $($PSCmdlet.parametersetname)"
        Switch ($PSCmdlet.parametersetname) {
            'Name' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|') -replace '\*','.*'
                [void]$StringBuilder.Append("`$_.Name -match $Items")
                If ($PSBoundParameters['State']) {
                    [void]$StringBuilder.Append(" -AND `$_.State -eq `"$State`"")
                }
                If ($PSBoundParameters.ContainsKey('HasMoreData')) {
                    [void]$StringBuilder.Append(" -AND `$_.HasMoreData -eq `$$HasMoreData")
                }   
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())                    
            }
            'Id' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$StringBuilder.Append("`$_.Id -match $Items")
                If ($PSBoundParameters['State']) {
                    [void]$StringBuilder.Append(" -AND `$_.State -eq `"$State`"")
                }
                If ($PSBoundParameters.ContainsKey('HasMoreData')) {
                    [void]$StringBuilder.Append(" -AND `$_.HasMoreData -eq `$$HasMoreData")
                }  
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())                
            }
            'Guid' {
                $Items = '"{0}"' -f (($list | ForEach {"^{0}$" -f $_}) -join '|')
                [void]$StringBuilder.Append("`$_.InstanceId -match $Items")
                If ($PSBoundParameters['State']) {
                    [void]$StringBuilder.Append(" -AND `$_.State -eq `"$State`"")
                }
                If ($PSBoundParameters.ContainsKey('HasMoreData')) {
                    [void]$StringBuilder.Append(" -AND `$_.HasMoreData -eq `$$HasMoreData")
                }    
                $ScriptBlock = [scriptblock]::Create($StringBuilder.ToString())   
            }
            'All' {$ScriptBlock=$Null}
        }
        If ($PSCmdlet.ParameterSetName -eq 'All') {
            $jobs
        } Else {
            Write-Debug "Items: $Items"
            Write-Debug "WhereString: $($StringBuilder.ToString())" 
            Write-Verbose "Using scriptblock"
            $Jobs | Where $ScriptBlock 
        }
    }
}