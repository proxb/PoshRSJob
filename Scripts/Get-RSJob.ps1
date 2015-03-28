Function Get-RSJob {
    [OutputType('PoshRS.PowerShell.RSJob')]
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
        [ValidateSet('NotStarted','Running','Completed','Failed','Stopping','Stopped','Disconnected')]
        [string]$State,
        [parameter()]
        [Switch]$HasMoreData
    )
    Begin {
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }        
        $List = New-Object System.Collections.ArrayList

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
        $WhereList = New-Object System.Collections.ArrayList
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
        }
        If ($PSBoundParameters['State']) {
            [void]$WhereList.Add("`$_.State -eq `"$State`"")
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
            $Jobs | Where $ScriptBlock 
        } Else {$Jobs}
    }
}
