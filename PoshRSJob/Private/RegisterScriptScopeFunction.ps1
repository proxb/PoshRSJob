Function RegisterScriptScopeFunction {
    [cmdletbinding()]
    Param (
        [parameter()]
        [string[]]$Name
    )    
    $FoundName = @()
    Write-Verbose "Getting callstacks"
    $PSCallStack = Get-PSCallStack
    Write-Verbose "PSCallStacks: `n$($PSCallStack|Out-String)"
    If ($PSCallStack.count -gt 1) {
        foreach ($CallStack in ($PSCallStack | Select-Object -Skip 2)) {
            Switch ($PSVersionTable.PSVersion.Major) {
                '2' {
                    $ScriptBlock = Get-Content $CallStack.ScriptName
                    $Functions = @(FindFunction -ScriptBlock ($ScriptBlock | Out-String))
                }
                Default {
                    $Flags = [System.Reflection.BindingFlags]'nonpublic,instance,static'
                    $FunctionContext = $CallStack.GetType().GetProperty('FunctionContext',$Flags).GetValue($CallStack,$Null)
                    $ScriptBlock = $FunctionContext.GetType().GetField('_scriptBlock',$Flags).GetValue($FunctionContext)
                    $Functions = @(($ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]},$False)))
                }
            }
            Write-Verbose ("Found {0} functions" -f $Functions.count)
            Write-Verbose "Functions found in callstack $Callstack`n$($Functions | Select-Object -ExpandProperty Name|Out-String)"
            if ($Functions) {
                $Functions | ForEach-Object {
                    If ($PSBoundParameters.ContainsKey('Name')) {
                        If ($Name -contains $_.Name -and $FoundName -notcontains $_.Name) {
                            Write-Verbose "Loading $($_.Name)" 
                            $FoundName += $_.Name
                            .([scriptblock]::Create("Function Script:$($_.Name) $($_.Body)"))
                        }
                    } Else {
                        if ($FoundName -notcontains $_.Name) {
                            Write-Verbose "Loading $($_.Name)" 
                            $FoundName += $_.Name
                            .([scriptblock]::Create("Function Script:$($_.Name) $($_.Body)"))
                        }
                    }
                }

                # Stop searching callstacks once we found what we want   
                if ($Name.Count -eq $FoundName.Count) {       
                    break
                }
            }
        }
    }
}