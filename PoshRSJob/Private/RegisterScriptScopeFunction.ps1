Function RegisterScriptScopeFunction {
    [cmdletbinding()]
    Param (
        [parameter()]
        [string[]]$Name
    )    
    Write-Verbose "Getting callstacks"
    $PSCallStack = Get-PSCallStack
    Write-Verbose "PSCallStacks: `n$($PSCallStack|Out-String)"
    If ($PSCallStack.count -gt 1) {
        #Ensure that I always get the second item in the call stack
        $CallStack = $PSCallStack[-2]
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
        Write-Verbose "Functions found: `n$($Functions | Select -Expand Name|Out-String)"
        $Functions | ForEach {
            If ($PSBoundParameters.ContainsKey('Name')) {
                If ($Name -contains $_.Name ) {
                    Write-Verbose "Loading $($_.Name)" 
                    .([scriptblock]::Create("Function Script:$($_.Name) $($_.Body)"))
                }
            } Else {
                Write-Verbose "Loading $($_.Name)" 
                .([scriptblock]::Create("Function Script:$($_.Name) $($_.Body)"))
            }
        }
    }
}