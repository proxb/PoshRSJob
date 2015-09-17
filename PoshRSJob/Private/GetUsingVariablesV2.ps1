Function GetUsingVariablesV2 {
    Param ([scriptblock]$ScriptBlock)
    $errors = [System.Management.Automation.PSParseError[]] @()
    $Results = [Management.Automation.PsParser]::Tokenize($ScriptBlock.tostring(), [ref] $errors)
    $Results | Where {
        $_.Content -match '^Using:' -AND $_.Type -eq 'Variable'
    }
}