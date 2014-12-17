Function Start-AsyncJob {
    [cmdletbinding(
        DefaultParameterSetName = 'All'
    )]
    Param (
        [parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [object]$InputObject,
        [parameter(ParameterSetName = 'ScriptBlock')]
        [ScriptBlock]$ScriptBlock,
        [parameter(ParameterSetName = 'ScriptPath')]
        [string]$FilePath,
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
        Write-Verbose "Creating runspacepool with max threads: $Throttle"
        $RunspacePoolID = [guid]::NewGuid().ToString()
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
        $RSPObject = [PSAsync.PowerShell.AsyncRunspacePool]@{
            RunspacePool = $RunspacePool
            MaxJobs = $RunspacePool.GetMaxRunspaces()
            RunspacePoolID = $RunspacePoolID
        }
        Write-Verbose "ScriptBlock: $($ScriptBlock)"
        [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
        [void]$RunspacePools.Add($RSPObject)
        [System.Threading.Monitor]::Exit($RunspacePools.syncroot) 
    }
    Process {
        ForEach ($Object in $InputObject) {   
            $RunspacePoolJobs++
            $ID = Increment                    
            Write-Verbose "Using $($Object)"
            $PowerShell = [powershell]::Create().AddScript($ScriptBlock)
            $PowerShell.RunspacePool = $RunspacePool
            [void]$PowerShell.AddArgument($Object)
            ForEach ($item in $ArgumentList) {
                Write-Verbose "Adding Argument: $($Item)"
                [void]$PowerShell.AddArgument($item)    
            }
            $Handle = $PowerShell.BeginInvoke()
            $Object = [PSAsync.PowerShell.AsyncJob]@{
                Name = $Name.InvokeReturnAsIs()
                InstanceID = [guid]::NewGuid().ToString()
                ID = $ID  
                Handle = $Handle
                InnerJob = $PowerShell
                Runspace = $PowerShell.Runspace
                Finished = $handle.AsyncWaitHandle
                Command  = $PowerShell.Commands.Commands.CommandText
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