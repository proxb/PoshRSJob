Function GetParamVariable {
    [CmdletBinding()]
    param (
        [scriptblock]$ScriptBlock
    )     
    # Tokenize the script
    [array] $tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null) | Where-Object {
        $_.Type -ne 'NewLine' -and  $_.Type -ne 'Comment'
    }
    # old code was buggy - it can grab internal param block for code like { $a = 1; invoke-command { param($b) } -argumentlist $a }
    # New code know that scriptblock param() can only be the first token or right after [attribute] tokens, any other - ignored.
    # It also get right variable names when param($a = $b + $c, $d) and other difficult cases (see tests)
    $state = 0
    $bracket = 0
    $awaitVariable = $false
    foreach ($token in $tokens)
    {
        # using state machine method
        switch ($state) {
            0 { # search for sttribute start or param
                if ($token.Type -eq 'Keyword' -and $token.Content -eq 'param') {
                    $state = 3 # collect variables start
                    $awaitVariable = $true # catch variable name after param(
                }
                elseif ($token.Type -eq 'Operator' -and $token.Content -eq '[') { #attribute start
                    $state = 1 # check for attribute token
                    $bracket++
                }
                else { # no param found, break
                    $state = -1
                }
            }
            1 { # Attribute token check. may be excessive?
                if ($token.Type -eq 'Attribute') {
                    $state = 2 # wait for close attribute block
                }
            }
            2 { # await attribte end
                if ($token.Type -eq 'Operator') {
                    if ($token.Content -eq '[') {
                        $bracket++
                    }
                    elseif  ($token.Content -eq ']') {
                        $bracket--
                        if ($bracket -eq 0) {
                            # catched attribute close bracket
                            $state = 0 # back to param() search
                        }
                    }
                }
            }
            3 { # inside params
                if ($token.Type -eq 'GroupStart' -and $token.Content -eq '(') {
                    $bracket++
                }
                elseif ($token.Type -eq 'GroupEnd' -and $token.Content -eq ')') {
                    $bracket--
                    if ($bracket -eq 0) {
                        # param() closed, exiting
                        $state = -1
                    }
                }
                elseif ($token.Type -eq 'Operator' -and $token.Content -eq '[') {
                    $bracket += 2 #count square brackets
                }
                elseif ($token.Type -eq 'Operator' -and $token.Content -eq ']') {
                    $bracket -= 2 #count square brackets
                }
                elseif ($token.Type -eq 'GroupStart' -and ($token.Content -eq '{' -or $token.Content -eq '@{')) {
                    $bracket += 2 #count curly brackets
                }
                elseif ($token.Type -eq 'GroupEnd' -and $token.Content -eq '}') {
                    $bracket -= 2 #count curly brackets
                }
                elseif ($token.Type -eq 'Operator' -and $token.Content -eq ',' -and ($bracket -eq 1)) {
                    $awaitVariable = $true # await variable name after comma without extra brackets
                }
                elseif ($token.Type -eq 'Variable' -and ($bracket -eq 1) -and $awaitVariable)
                {
                    $awaitVariable = $false
                    $token.Content
                }
            }
        }
        if ($state -eq -1) { break }
    }
}