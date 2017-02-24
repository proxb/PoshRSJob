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
        [void]$Params.AddRange(@($UsingVariableData.NewName | Select-Object -Unique))
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