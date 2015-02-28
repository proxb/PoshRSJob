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
                $Name = [scriptblock]::Create( ($Name -replace '\$_','$Item'))
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
        Write-Debug "ScriptBlock: $($ScriptBlock)"
        [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
        [void]$RunspacePools.Add($RSPObject)
        [System.Threading.Monitor]::Exit($RunspacePools.syncroot) 
    }
    Process {
        If ($InputObject) {
            ForEach ($Item in $InputObject) {   
                $RunspacePoolJobs++
                $ID = Increment                    
                Write-Verbose "Using $($Item)"
                $PowerShell = [powershell]::Create().AddScript($ScriptBlock)
                $PowerShell.RunspacePool = $RunspacePool
                [void]$PowerShell.AddArgument($Item)
                ForEach ($argument in $ArgumentList) {
                    Write-Verbose "Adding Argument: $($argument)"
                    [void]$PowerShell.AddArgument($argument)    
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
                    Command  = $PowerShell.Commands.Commands.CommandText
                    RunspacePoolID = $RunSpacePoolID
                }

                [System.Threading.Monitor]::Enter($Jobs.syncroot) 
                [void]$Jobs.Add($Object)
                [System.Threading.Monitor]::Exit($Jobs.syncroot) 
                Write-Verbose "Outputting job object"
                $Object
            }
        } Else {
            $RunspacePoolJobs++
            $ID = Increment                    
            Write-Verbose "Using $($Item)"
            $PowerShell = [powershell]::Create().AddScript($ScriptBlock)
            $PowerShell.RunspacePool = $RunspacePool
            ForEach ($argument in $ArgumentList) {
                Write-Verbose "Adding Argument: $($argument)"
                [void]$PowerShell.AddArgument($argument)    
            }
            $Handle = $PowerShell.BeginInvoke()
            $Object = [PoshRS.PowerShell.RSJob]@{
                Name = $Name
                InstanceID = [guid]::NewGuid().ToString()
                ID = $ID  
                Handle = $Handle
                InnerJob = $PowerShell
                Runspace = $PowerShell.Runspace
                Finished = $handle.RSWaitHandle
                Command  = $PowerShell.Commands.Commands.CommandText
                RunspacePoolID = $RunSpacePoolID
            }

            [System.Threading.Monitor]::Enter($Jobs.syncroot) 
            [void]$Jobs.Add($Object)
            [System.Threading.Monitor]::Exit($Jobs.syncroot) 
            Write-Verbose "Outputting job object"
            $Object            
        }
    }
    End {        
    }
}
