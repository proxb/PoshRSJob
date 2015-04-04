Function Start-RSJob {
    <#
        .SYNOPSIS
            Starts a background job using runspaces.

        .DESCRIPTION
            This will run a command in the background, leaving your console available to perform other tasks. This uses
            runspaces in runspacepools which allows for throttling of running jobs. As the jobs are finished, they will automatically
            dispose of each runspace and allow other runspace jobs in queue to begin based on the throttling of the runspacepool.

            This is available on PowerShell V3 and above. By doing this, you can use the $Using: variable to take variables
            in the local scope and apply those directly into the scriptblock of the background runspace job.

        .PARAMETER ScriptBlock
            The scriptblock that holds all of the commands which will be run in the background runspace. You must specify
            at least one Parameter in the Param() to account for the item that is being piped into Start-Job.

        .PARAMETER FilePath
            This is the path to a file containing code that will be run in the background runspace job.

        .PARAMETER InputObject
            The object being piped into Start-RSJob or applied via the parameter.

        .PARAMETER Name
            The name of a background runspace job

        .PARAMETER ArgumentList
            List of values that will be applied at the end of the argument list in the Param() statement.

        .PARAMETER Throttle
            Number of concurrent running runspace jobs which are allowed at a time.

        .PARAMETER ModulesToImport
            A collection of modules that will be imported into the background runspace job.

        .PARAMETER FunctionsToImport
            A collection of functions that will be imported for use with a background runspace job.

        .NOTES
            Name: Start-RSJob
            Author: Boe Prox                

        .EXAMPLE
            Get-ChildItem -Directory | Start-RSjob -Name {$_.Name} -ScriptBlock {
                Param($Directory)
                Write-Verbose $_
                $Sum = (Get-ChildItem $Directory.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
                [pscustomobject]@{
                    Name = $Directory.Name
                    SizeMB = ([math]::round(($Sum/1MB),2))
                }
            } 
            
            Id  Name                 State           HasMoreData  HasErrors    Command
            --  ----                 -----           -----------  ---------    -------
            11  .shsh                Running         False        False        ...
            12  .ssh                 Running         False        False        ...
            13  Contacts             Running         False        False        ...
            14  Desktop              Running         False        False        ...
            15  Documents            Running         False        False        ...
            16  Downloads            Running         False        False        ...
            17  Favorites            Running         False        False        ...
            18  Links                Running         False        False        ...
            19  Music                Running         False        False        ...
            20  OneDrive             Running         False        False        ...
            21  Pictures             Running         False        False        ...
            22  Saved Games          Running         False        False        ...
            23  Searches             Running         False        False        ...
            24  Videos               Running         False        False        ...

            Get-RSJob | Receive-RSJob

            Name          SizeMB
            ----          ------
            .shsh              0
            .ssh               0
            Contacts           0
            Desktop         7.24
            Documents      83.99
            Downloads    10259.6
            Favorites          0
            Links              0
            Music       16691.89
            OneDrive     1485.24
            Pictures     1734.91
            Saved Games        0
            Searches           0
            Videos         17.19

            Description
            -----------
            Starts a background runspace job that looks at the total size of each folder. Using Get-RSJob | Recieve-RSJob shows 
            the results when the State is Completed.         

        .EXAMPLE
            $Test = 'test'
            $Something = 1..10
            1..5|start-rsjob -Name {$_} -ScriptBlock {
                Param($Object) [pscustomobject]@{
                    Result=($Object*2)
                    Test=$Using:Test
                    Something=$Using:Something
                }
            }            

            Id  Name                 State           HasMoreData  HasErrors    Command
            --  ----                 -----           -----------  ---------    -------
            76  1                    Completed       True         False        ...
            77  2                    Running         False        False        ...
            78  3                    Running         False        False        ...
            79  4                    Completed       False        False        ...
            80  5                    Completed       False        False        ...
            
            Get-RSjob | Receive-RSJob

            Result Test Something
            ------ ---- ---------
                 2 test {1, 2, 3, 4...}
                 4 test {1, 2, 3, 4...}
                 6 test {1, 2, 3, 4...}
                 8 test {1, 2, 3, 4...}
                10 test {1, 2, 3, 4...}
            
            Description
            -----------
            Shows an example of the $Using: variable being used in the scriptblock.

    #>
    [OutputType('PoshRS.PowerShell.RSJob')]
    [cmdletbinding(
        DefaultParameterSetName = 'ScriptBlock'
    )]
    Param (
        [parameter(Position=0,ParameterSetName = 'ScriptBlock')]
        [ScriptBlock]$ScriptBlock,
        [parameter(Position=0,ParameterSetName = 'ScriptPath')]
        [string]$FilePath,
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
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
        $RunspacePool = [runspacefactory]::CreateRunspacePool($InitialSessionState)
        [void]$RunspacePool.SetMaxRunspaces($Throttle)
        If ($PSVersionTable.PSVersion.Major -gt 2) {
            $RunspacePool.CleanupInterval = [timespan]::FromMinutes(2)    
        }
        $RunspacePool.Open()
        If ($PSBoundParameters['FilePath']) {
            $ScriptBlock = [scriptblock]::Create((Get-Content $FilePath))
        }
        $RSPObject = New-Object PoshRS.PowerShell.RSRunspacePool -Property @{
            RunspacePool = $RunspacePool
            MaxJobs = $RunspacePool.GetMaxRunspaces()
            RunspacePoolID = $RunspacePoolID
        }
        $List = New-Object System.Collections.ArrayList
        If ($PSBoundParameters.ContainsKey('InputObject')) {            
            [void]$list.AddRange($InputObject)    
            $IsPipeline = $False
        } Else {
            $IsPipeline = $True
        }
        #Convert ScriptBlock for $Using:
        Switch ($PSVersionTable.PSVersion.Major) {
            2 {
                Write-Debug "Using PSParser with PowerShell V2"
                $UsingVariables = GetUsingVariablesV2 -ScriptBlock $ScriptBlock
                If ($UsingVariables) {
                    $UsingVariableValues = @(GetUsingVariableValuesV2 -UsingVar $UsingVariables)
                    Write-Verbose "Found $($UsingVariableValues.Count) Using values"
                    $NewScriptBlock = ConvertScriptBlockV2 -ScriptBlock $ScriptBlock -UsingVariable $UsingVariableValues 
                } Else {
                    $NewScriptBlock = $ScriptBlock
                }
            }
            Default {
                Write-Debug "Using AST with PowerShell V3+"
                $UsingVariables = GetUsingVariables $ScriptBlock | Group SubExpression | ForEach {
                    $_.Group | Select -First 1
                }
                If ($UsingVariables) {                    
                    $UsingVariableValues = @(GetUsingVariableValues $UsingVariables)
                    Write-Verbose "Found $($UsingVariableValues.Count) Using values"
                    $NewScriptBlock = ConvertScript $ScriptBlock
                } Else {
                    $NewScriptBlock = $ScriptBlock
                }            
            }
        }

        Write-Debug "ScriptBlock: $($NewScriptBlock)"
        [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
        [void]$RunspacePools.Add($RSPObject)
        [System.Threading.Monitor]::Exit($RunspacePools.syncroot) 
    }
    Process {
        If ($IsPipeline -AND $PSBoundParameters.ContainsKey('InputObject')) {
            [void]$List.Add($InputObject)
        }
    }
    End {  
        If ($List.Count -gt 0) {
            Write-Debug "InputObject"
            ForEach ($Item in $list) {
                $ID = Increment                    
                Write-Verbose "Using $($Item) as pipline variable"
                $PowerShell = [powershell]::Create().AddScript($NewScriptBlock)
                $PowerShell.RunspacePool = $RunspacePool
                [void]$PowerShell.AddArgument($Item)
                If ($UsingVariableValues) {
                    For ($i=0;$i -lt $UsingVariableValues.count;$i++) {
                        Write-Verbose "Adding Param: $($UsingVariableValues[$i].Name) Value: $($UsingVariableValues[$i].Value)"
                        [void]$PowerShell.AddParameter($UsingVariableValues[$i].NewVarName,$UsingVariableValues[$i].Value)
                    }
                }
                If ($PSBoundParameters.ContainsKey('ArgumentList')) {
                    ForEach ($Argument in $ArgumentList) {
                        Write-Verbose "Adding Argument: $($Argument)"
                        [void]$PowerShell.AddArgument($Argument)    
                    }
                }
                $Handle = $PowerShell.BeginInvoke()
                $Object = New-Object PoshRS.PowerShell.RSJob -Property @{
                    Name = $Name.InvokeReturnAsIs()
                    InstanceID = [guid]::NewGuid().ToString()
                    ID = $ID  
                    Handle = $Handle
                    InnerJob = $PowerShell
                    Runspace = $PowerShell.Runspace
                    Finished = $handle.IsCompleted
                    Command  = $ScriptBlock.ToString()
                    RunspacePoolID = $RunSpacePoolID
                    State = [System.Management.Automation.PSInvocationState]::Running
                }
                
                $RSPObject.LastActivity = Get-Date
                [System.Threading.Monitor]::Enter($Jobs.syncroot) 
                [void]$Jobs.Add($Object)
                [System.Threading.Monitor]::Exit($Jobs.syncroot) 
                $Object            
            }
        } Else {
            Write-Debug "No InputObject"
            $ID = Increment                    
            $PowerShell = [powershell]::Create().AddScript($NewScriptBlock)
            $PowerShell.RunspacePool = $RunspacePool
            If ($UsingVariableValues) {
                For ($i=0;$i -lt $UsingVariableValues.count;$i++) {
                    Write-Verbose "Adding Param: $($UsingVariableValues[$i].Name) Value: $($UsingVariableValues[$i].Value)"
                    [void]$PowerShell.AddParameter($UsingVariableValues[$i].NewVarName,$UsingVariableValues[$i].Value)
                }
            }
            If ($PSBoundParameters.ContainsKey('ArgumentList')) {
                ForEach ($Argument in $ArgumentList) {
                    Write-Verbose "Adding Argument: $($Argument)"
                    [void]$PowerShell.AddArgument($Argument)    
                }
            }
            $Handle = $PowerShell.BeginInvoke()
            $Object = New-Object PoshRS.PowerShell.RSJob -Property @{
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
            
            $RSPObject.LastActivity = Get-Date
            [System.Threading.Monitor]::Enter($Jobs.syncroot) 
            [void]$Jobs.Add($Object)
            [System.Threading.Monitor]::Exit($Jobs.syncroot) 
            $Object        
        }      
    }
}
