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