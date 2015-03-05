Function Start-RSJob {
    [cmdletbinding(
        DefaultParameterSetName = 'All'
    )]
    Param (
        [parameter(Position=0,ParameterSetName = 'ScriptBlock')]
        [ScriptBlock]$ScriptBlock,
        [parameter(Position=0,ParameterSetName = 'ScriptPath')]
        [string]$FilePath,
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [object]$InputObject,
        [parameter()]
        [object]$Name,
        [parameter()]
        [object]$ArgumentList,
        [parameter()]
        [int]$Throttle = 5,
        [parameter()]
        [string[]]$ModulesToImport,
        [parameter()]
        [string[]]$FunctionsToLoad
    )
    Begin {  
        If ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        } 
        If ($PSBoundParameters['Name']) {
            If ($Name -isnot [scriptblock]) {
                $Name = [scriptblock]::Create("Write-Output $Name")
            } Else {
                $Name = [scriptblock]::Create( ($Name -replace '\$_','$Object'))
            }
        } Else {
            $Name = [scriptblock]::Create('Write-Output Job$($Id)')
        }
        $RunspacePoolID = [guid]::NewGuid().ToString()
        Write-Verbose "Creating runspacepool <$($RunspacePoolID)> with max threads: $Throttle"        
        $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        If ($PSBoundParameters['ModulesToImport']) {
            [void]$InitialSessionState.ImportPSModule($ModulesToImport)
        }
        If ($PSBoundParameters['FunctionsToLoad']) {
            ForEach ($Function in $FunctionsToLoad) {
                Try {
                    $Definition = Get-Content Function:\$Function -ErrorAction Stop
                    $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function, $Definition
                    $InitialSessionState.Commands.Add($SessionStateFunction) 
                } Catch {
                    Write-Warning "$($Function): $($_.Exception.Message)"
                }
            }           
        }
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1,$Throttle,$InitialSessionState,$Host)
        $RunspacePool.CleanupInterval = [timespan]::FromMinutes(2)    
        $RunspacePool.Open()
        If ($PSBoundParameters['FilePath']) {
            $ScriptBlock = [scriptblock]::Create((Get-Content $FilePath))
        }
        $RSPObject = [PoshRS.PowerShell.RSRunspacePool]@{
            RunspacePool = $RunspacePool
            MaxJobs = $RunspacePool.GetMaxRunspaces()
            RunspacePoolID = $RunspacePoolID
        }
        #Convert ScriptBlock for $Using:
        $UsingVariables = GetUsingVariables $ScriptBlock
        If ($UsingVariables) {
            Write-Verbose "Found $($UsingVariables.Count) '`$Using:' variables"
            $UsingVariableValues = @(GetUsingVariableValues $UsingVariables)
            $NewScriptBlock = ConvertScript $ScriptBlock
        } Else {
            $NewScriptBlock = $ScriptBlock
        }

        Write-Debug "ScriptBlock: $($NewScriptBlock)"
        [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
        [void]$RunspacePools.Add($RSPObject)
        [System.Threading.Monitor]::Exit($RunspacePools.syncroot) 
    }
    Process {
        ForEach ($Object in $InputObject) {   
            $RunspacePoolJobs++
            $ID = Increment                    
            Write-Verbose "Using $($Object) as pipline variable"
            $PowerShell = [powershell]::Create().AddScript($NewScriptBlock)
            $PowerShell.RunspacePool = $RunspacePool
            [void]$PowerShell.AddArgument($Object)
            If ($UsingVariableValues) {
                For ($i=0;$i -lt $UsingVariableValues.count;$i++) {
                    Write-Verbose "Adding Param: $($UsingVariableValues[$i].Name) Value: $($UsingVariableValues[$i].Value)"
                    [void]$PowerShell.AddParameter($UsingVariableValues[$i].NewVarName,$UsingVariableValues[$i].Value)
                }
            }
            ForEach ($item in $ArgumentList) {
                Write-Verbose "Adding Argument: $($Item)"
                [void]$PowerShell.AddArgument($item)    
            }
            $Handle = $PowerShell.BeginInvoke()
            $Object = [PoshRS.PowerShell.RSJob]@{
                Name = $Name.InvokeReturnAsIs()
                InstanceID = [guid]::NewGuid().ToString()
                ID = $ID  
                Handle = $Handle
                InnerJob = $PowerShell
                Runspace = $PowerShell.Runspace
                Finished = $handle.RSWaitHandle
                Command  = $ScriptBlock.ToString()
                RunspacePoolID = $RunSpacePoolID
            }

            [System.Threading.Monitor]::Enter($Jobs.syncroot) 
            [void]$Jobs.Add($Object)
            [System.Threading.Monitor]::Exit($Jobs.syncroot) 
            $Object
        }
    }
    End {        
    }
}
