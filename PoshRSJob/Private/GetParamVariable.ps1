Function GetParamVariable {
    [CmdletBinding()]
    param (
        [scriptblock]$ScriptBlock
    )     
    # Tokenize the script
    [array] $tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null) | Where-Object {
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