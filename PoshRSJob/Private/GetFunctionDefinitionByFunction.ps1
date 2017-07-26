Function GetFunctionDefinitionByFunction {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $True)]
        $FunctionItem
    )

    if ($FunctionItem -is [PSCustomObject]) {
        # In case of Powershell v2
        $function.Body.Trim().Trim("{}")
    }
    else {
        # In case of Powershell v3+
        $function.Body.Extent.Text.Trim("{}")
    }
}
