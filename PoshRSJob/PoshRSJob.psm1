$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
#region Custom Object
Write-Verbose "Creating custom RSJob object"
Add-Type -TypeDefinition @"
    using System;

    namespace PoshRS.PowerShell
    {
        public class RSJob
        {
            public string Name;
            public int ID;
            public System.Management.Automation.PSInvocationState State;
            public System.Guid InstanceID;
            public object Handle;
            public object Runspace;
            public System.Management.Automation.PowerShell InnerJob;
            public System.Threading.ManualResetEvent Finished;
            public string Command;
            public System.Management.Automation.PSDataCollection<System.Management.Automation.ErrorRecord> Error;
            public System.Management.Automation.PSDataCollection<System.Management.Automation.VerboseRecord> Verbose;
            public System.Management.Automation.PSDataCollection<System.Management.Automation.DebugRecord> Debug;
            public System.Management.Automation.PSDataCollection<System.Management.Automation.WarningRecord> Warning;
            public System.Management.Automation.PSDataCollection<System.Management.Automation.ProgressRecord> Progress;
            public bool HasMoreData;
            public bool HasErrors;
            public object Output;
            public System.Guid RunspacePoolID;
            public bool Completed = false;
        }
        public class RSRunspacePool
        {
            public System.Management.Automation.Runspaces.RunspacePool RunspacePool;
            public System.Management.Automation.Runspaces.RunspacePoolState State;
            public int AvailableJobs;
            public int MaxJobs;
            public DateTime LastActivity = DateTime.MinValue;
            public System.Guid RunspacePoolID;
            public bool CanDispose = false;
        }
        public class V2UsingVariable
        {
            public string Name;
            public string NewName;
            public object Value;
            public string NewVarName;
        }
    }
"@ -Language CSharpVersion3
#endregion Custom Object

#region RSJob Collections
Write-Verbose "Creating RS collections"
New-Variable Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable JobCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
New-Variable JobID -Value ([int64]0) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePools -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option AllScope,ReadOnly -Scope Global
New-Variable RunspacePoolCleanup -Value ([hashtable]::Synchronized(@{})) -Option AllScope,ReadOnly -Scope Global
#endregion RSJob Collections

#region Cleanup Routine
Write-Verbose "Creating routine to monitor RS jobs"
$jobCleanup.Flag=$True
$jobCleanup.Host = $Host
$jobcleanup.Runspace =[runspacefactory]::CreateRunspace()   
$jobcleanup.Runspace.Open()         
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$jobcleanup.Runspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do {   
        [System.Threading.Monitor]::Enter($Jobs.syncroot) 
        Foreach($job in $jobs) {
            $job.state = $job.InnerJob.InvocationStateInfo.State
            If ($job.Handle.isCompleted -AND (-NOT $Job.Completed)) {   
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) completed")  
                Try {           
                    $data = $job.InnerJob.EndInvoke($job.Handle)
                } Catch {
                    $CaughtErrors = $Error
                    #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Caught terminating Error in job: $_") 
                }
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Checking for errors") 
                If ($job.InnerJob.Streams.Error -OR $CaughtErrors) {
                    #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Errors Found!")
                    $ErrorList = New-Object System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]
                    If ($job.InnerJob.Streams.Error) {
                        ForEach ($Err in $job.InnerJob.Streams.Error) {
                            #$jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")             
                            [void]$ErrorList.Add($Err)
                        }
                    }
                    If ($CaughtErrors) {
                        ForEach ($Err in $CaughtErrors) {
                            #$jobCleanup.Host.UI.WriteVerboseLine("`t$($Job.Id) Adding Error")             
                            [void]$ErrorList.Add($Err)
                        }                    
                    }
                    $job.Error = $ErrorList
                }
                #$jobCleanup.Host.UI.WriteVerboseLine("$($Job.Id) Disposing job")
                $job.InnerJob.dispose() 
                $job.Completed = $True  
                If ((Get-Variable data -ErrorAction SilentlyContinue).Value) {
                    $job.output = $data
                    $job.HasMoreData = $True
                    Remove-Variable data -ErrorAction SilentlyContinue                    
                }                            
                $Error.Clear()
            } 
        }        
        [System.Threading.Monitor]::Exit($Jobs.syncroot)
        Start-Sleep -Milliseconds 100     
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $jobcleanup.Runspace
$jobCleanup.Handle = $jobCleanup.PowerShell.BeginInvoke()  

Write-Verbose "Creating routine to monitor Runspace Pools"
$RunspacePoolCleanup.Flag=$True
$RunspacePoolCleanup.Host=$Host
#5 minute timeout for unused runspace pools
$RunspacePoolCleanup.Timeout = [timespan]::FromMinutes(1).Ticks
$RunspacePoolCleanup.Runspace =[runspacefactory]::CreateRunspace()
 
#Create Type Collection so the object will work properly 
$Types = Get-ChildItem "$($PSScriptRoot)\TypeData" -Filter *Types* | Select -ExpandProperty Fullname 
$Types | ForEach { 
    $TypeEntry = New-Object System.Management.Automation.Runspaces.TypeConfigurationEntry -ArgumentList $_ 
    $RunspacePoolCleanup.Runspace.RunspaceConfiguration.types.Append($TypeEntry) 
} 
  
$RunspacePoolCleanup.Runspace.Open()         
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePoolCleanup",$RunspacePoolCleanup)     
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("RunspacePools",$RunspacePools) 
$RunspacePoolCleanup.Runspace.SessionStateProxy.SetVariable("ParentHost",$Host) 
$RunspacePoolCleanup.PowerShell = [PowerShell]::Create().AddScript({
    #Routine to handle completed runspaces
    Do { 
        $DisposeRunspacePools=$False  
        If ($RunspacePools.Count -gt 0) { 
            #$ParentHost.ui.WriteVerboseLine("$($RunspacePools | Out-String)")           
            [System.Threading.Monitor]::Enter($RunspacePools.syncroot) 
            Foreach($RunspacePool in $RunspacePools) {                
                #$ParentHost.ui.WriteVerboseLine("RunspacePool <$($RunspacePool.RunspaceID)> | MaxJobs: $($RunspacePool.MaxJobs) | AvailJobs: $($RunspacePool.AvailableJobs)")
                If (($RunspacePool.AvailableJobs -eq $RunspacePool.MaxJobs) -AND $RunspacePools.LastActivity.Ticks -ne 0) {
                    If ((Get-Date).Ticks - $RunspacePool.LastActivity.Ticks -gt $RunspacePoolCleanup.Timeout) {
                        #Dispose of runspace pool
                        $RunspacePool.RunspacePool.Close()
                        $RunspacePool.RunspacePool.Dispose()
                        $RunspacePool.CanDispose = $True
                        $DisposeRunspacePools=$True
                    }
                } Else {
                    $RunspacePool.LastActivity = (Get-Date)
                }               
            }       
            #Remove runspace pools
            If ($DisposeRunspacePools) {
                $TempCollection = $RunspacePools.Clone()
                $TempCollection | Where {
                    $_.CanDispose
                } | ForEach {
                    #$ParentHost.ui.WriteVerboseLine("Removing runspacepool <$($_.RunspaceID)>")
                    [void]$RunspacePools.Remove($_)
                }
            }
            Remove-Variable TempCollection
            [System.Threading.Monitor]::Exit($RunspacePools.syncroot)
        }
        Start-Sleep -Milliseconds 5000     
    } while ($RunspacePoolCleanup.Flag)
})
$RunspacePoolCleanup.PowerShell.Runspace = $RunspacePoolCleanup.Runspace
$RunspacePoolCleanup.Handle = $RunspacePoolCleanup.PowerShell.BeginInvoke() 
#endregion Cleanup Routine

#region Load Functions
Try {
    Get-ChildItem "$ScriptPath\Scripts" -Filter *.ps1 | Select -Expand FullName | ForEach {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#endregion Load Functions

#region Format and Type Data
Update-FormatData "$ScriptPath\TypeData\PoshRSJob.Format.ps1xml"
Update-TypeData "$ScriptPath\TypeData\PoshRSJob.Types.ps1xml"
#endregion Format and Type Data

#region Private Functions
Function Increment {
    Set-Variable -Name JobId -Value ($JobId + 1) -Force -Scope Global
    Write-Output $JobId
}

Function GetUsingVariables {
    Param ([scriptblock]$ScriptBlock)
    $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]},$True)    
}

Function GetUsingVariableValues {
    Param ([System.Management.Automation.Language.UsingExpressionAst[]]$UsingVar)
    $UsingVar = $UsingVar | Group SubExpression | ForEach {$_.Group | Select -First 1}    
    ForEach ($Var in $UsingVar) {
        Try {
            $Value = Get-Variable -Name $Var.SubExpression.VariablePath.UserPath -ErrorAction Stop
            [pscustomobject]@{
                Name = $Var.SubExpression.Extent.Text
                Value = $Value.Value
                NewName = ('$__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                NewVarName = ('__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
            }
        } Catch {
            Throw "$($Var.SubExpression.Extent.Text) is not a valid Using: variable!"
        }
    }
}

Function ConvertScript {
    Param (
        [scriptblock]$ScriptBlock
    )
    $UsingVariables = @(GetUsingVariables -ScriptBlock $ScriptBlock)
    $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
    $Params = New-Object System.Collections.ArrayList
    If ($Script:Add_) {
        [void]$Params.Add('$_')
    }
    If ($UsingVariables) {        
        ForEach ($Ast in $UsingVariables) {
            [void]$list.Add($Ast.SubExpression)
        }
        $UsingVariableData = @(GetUsingVariableValues $UsingVariables)
        [void]$Params.AddRange(@($UsingVariableData.NewName | Select -Unique))
    } 
    $NewParams = $Params -join ', '
    $Tuple=[Tuple]::Create($list,$NewParams)
    $bindingFlags = [Reflection.BindingFlags]"Default,NonPublic,Instance"

    $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl',$bindingFlags))
    $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast,@($Tuple))
    If ([scriptblock]::Create($StringScriptBlock).ast.endblock[0].statements.extent.text.startswith('$input |')) {
        $StringScriptBlock = $StringScriptBlock -replace '\$Input \|'
    }
    If (-NOT $ScriptBlock.Ast.ParamBlock) {
        $StringScriptBlock = "Param($($NewParams))`n$($StringScriptBlock)"
        [scriptblock]::Create($StringScriptBlock)
    } Else {
        [scriptblock]::Create($StringScriptBlock)
    }
}

Function IsExistingParamBlock {
    Param([scriptblock]$ScriptBlock)
    $errors = [System.Management.Automation.PSParseError[]] @()
    $Tokens = [Management.Automation.PsParser]::Tokenize($ScriptBlock.tostring(), [ref] $errors)       
    $Finding=$True
    For ($i=0;$i -lt $Tokens.count; $i++) {       
        If ($Tokens[$i].Content -eq 'Param' -AND $Tokens[$i].Type -eq 'Keyword') {
            $HasParam = $True
            BREAK
        }
    }
    If ($HasParam) {
        $True
    } Else {
        $False
    }
}

Function GetUsingVariablesV2 {
    Param ([scriptblock]$ScriptBlock)
    $errors = [System.Management.Automation.PSParseError[]] @()
    $Results = [Management.Automation.PsParser]::Tokenize($ScriptBlock.tostring(), [ref] $errors)
    $Results | Where {
        $_.Content -match '^Using:' -AND $_.Type -eq 'Variable'
    }
}

Function GetUsingVariableValuesV2 {
    Param ([System.Management.Automation.PSToken[]]$UsingVar)
    $UsingVar | ForEach {
        $Name = $_.Content -replace 'Using:'
        New-Object PoshRS.PowerShell.V2UsingVariable -Property @{
            Name = $Name
            NewName = '$__using_{0}' -f $Name
            Value = (Get-Variable -Name $Name).Value
            NewVarName = ('__using_{0}') -f $Name
        }
    }
}

Function ConvertScriptBlockV2 {
    Param ([scriptblock]$ScriptBlock)
    $UsingVariables = GetUsingVariablesV2 -ScriptBlock $ScriptBlock
    $UsingVariable = GetUsingVariableValuesV2 -UsingVar $UsingVariables
    $errors = [System.Management.Automation.PSParseError[]] @()
    $Tokens = [Management.Automation.PsParser]::Tokenize($ScriptBlock.tostring(), [ref] $errors)
    $StringBuilder = New-Object System.Text.StringBuilder
    $UsingHash = @{}
    $UsingVariable | ForEach {
        $UsingHash["Using:$($_.Name)"] = $_.NewVarName
    }
    $HasParam = IsExistingParamBlock -ScriptBlock $ScriptBlock
    $Params = New-Object System.Collections.ArrayList
    If ($Script:Add_) {
        [void]$Params.Add('$_')
    }
    If ($UsingVariable) {        
        [void]$Params.AddRange(($UsingVariable | Select -expand NewName))
    } 
    $NewParams = $Params -join ', '  
    If (-Not $HasParam) {
        [void]$StringBuilder.Append("Param($($NewParams))")
    }
    For ($i=0;$i -lt $Tokens.count; $i++){
        #Write-Verbose "Type: $($Tokens[$i].Type)"
        #Write-Verbose "Previous Line: $($Previous.StartLine) -- Current Line: $($Tokens[$i].StartLine)"
        If ($Previous.StartLine -eq $Tokens[$i].StartLine) {
            $Space = " " * [int]($Tokens[$i].StartColumn - $Previous.EndColumn)
            [void]$StringBuilder.Append($Space)
        }
        Switch ($Tokens[$i].Type) {
            'NewLine' {[void]$StringBuilder.Append("`n")}
            'Variable' {
                If ($UsingHash[$Tokens[$i].Content]) {
                    [void]$StringBuilder.Append(("`${0}" -f $UsingHash[$Tokens[$i].Content]))
                } Else {
                    [void]$StringBuilder.Append(("`${0}" -f $Tokens[$i].Content))
                }
            }
            'String' {
                [void]$StringBuilder.Append(("`"{0}`"" -f $Tokens[$i].Content))
            }
            'GroupStart' {
                $Script:GroupStart++
                If ($Script:AddUsing -AND $Script:GroupStart -eq 1) {
                    $Script:AddUsing = $False
                    [void]$StringBuilder.Append($Tokens[$i].Content)                    
                    If ($HasParam) {
                        [void]$StringBuilder.Append("$($NewParams),")
                    }
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }
            }
            'GroupEnd' {
                $Script:GroupStart--
                If ($Script:GroupStart -eq 0) {
                    $Script:Param = $False
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }
            }
            'KeyWord' {
                If ($Tokens[$i].Content -eq 'Param') {
                    $Script:Param = $True
                    $Script:AddUsing = $True
                    $Script:GroupStart=0
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                } Else {
                    [void]$StringBuilder.Append($Tokens[$i].Content)
                }                
            }
            Default {
                [void]$StringBuilder.Append($Tokens[$i].Content)         
            }
        } 
        $Previous = $Tokens[$i]   
    }
    #$StringBuilder.ToString()
    [scriptblock]::Create($StringBuilder.ToString())
}

Function GetParamVariable {
    [CmdletBinding()]
    param (
        [scriptblock]$ScriptBlock
    )     
    # Tokenize the script
    $tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null) | Where {
        $_.Type -ne 'NewLine'
    }

    # First Pass - Grab all tokens between the first param block.
    $paramsearch = $false
    $groupstart = 0
    $groupend = 0
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if (!$paramsearch) {
            if ($tokens[$i].Content -eq "param" ) {
                $paramsearch = $true
            }
        }
        if ($paramsearch) {
            if (($tokens[$i].Type -eq "GroupStart") -and ($tokens[$i].Content -eq '(') ) {
                $groupstart++
            }
            if (($tokens[$i].Type -eq "GroupEnd") -and ($tokens[$i].Content -eq ')') ) {
                $groupend++
            }
            if (($groupstart -ge 1) -and ($groupstart -eq $groupend)) {
                $paramsearch = $false
            }
            if (($tokens[$i].Type -eq 'Variable') -and ($tokens[($i-1)].Content -ne '=')) {
                if ((($groupstart - $groupend) -eq 1)) {
                    "$($tokens[$i].Content)"
                }
            }
        }
    }
}
#endregion Private Functions

#region Aliases
New-Alias -Name ssj -Value Start-RSJob
New-Alias -Name gsj -Value Get-RSJob
New-Alias -Name rsj -Value Receive-RSJob
New-Alias -Name rmsj -Value Remove-RSJob
New-Alias -Name spsj -Value Stop-RSJob
New-Alias -Name wsj -Value Wait-RSJob
#endregion Aliases

#region Handle Module Removal
$ExecutionContext.SessionState.Module.OnRemove ={
    $jobCleanup.Flag=$False
    $RunspacePoolCleanup.Flag=$False
    #Let sit for a second to make sure it has had time to stop
    Start-Sleep -Seconds 1
    $jobCleanup.PowerShell.EndInvoke($jobCleanup.Handle)
    $jobCleanup.PowerShell.Dispose()    
    $RunspacePoolCleanup.PowerShell.EndInvoke($RunspacePoolCleanup.Handle)
    $RunspacePoolCleanup.PowerShell.Dispose()
    Remove-Variable JobId -Scope Global -Force
    Remove-Variable Jobs -Scope Global -Force
    Remove-Variable JobCleanup -Scope Global -Force
    Remove-Variable RunspacePoolCleanup -Scope Global -Force
    Remove-Variable RunspacePools -Scope Global -Force
}
#endregion Handle Module Removal

Export-ModuleMember -Alias * -Function '*-RSJob'
