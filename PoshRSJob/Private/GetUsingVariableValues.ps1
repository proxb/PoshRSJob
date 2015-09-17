Function GetUsingVariableValues {
    Param ([System.Management.Automation.Language.UsingExpressionAst[]]$UsingVar)
    $UsingVar = $UsingVar | Group SubExpression | ForEach {$_.Group | Select -First 1}        
    ForEach ($Var in $UsingVar) {
        Try {
            $Value = ($PSCmdlet.SessionState.PSVariable.Get('Something')).Value
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