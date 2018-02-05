#Helper function
Function FindFunction {
    [CmdletBinding()]
    param (
        [string]$ScriptBlock
    )
    #Just in case we have some oddness going on
    $ScriptBlock = $ScriptBlock -replace '`','``'
    # Tokenize the script
    $tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null)

    # First Pass - Grab all tokens between the first param block.
    $functionsearch = $false
    $IsName=$False
    $Counter = 0
    $SpaceCount = 0
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if (!$functionsearch) {
            if ($tokens[$i].Content -eq "function" -AND $tokens[$i].Type -eq 'Keyword') {
                $functionsearch = $true
                $IsName=$False
                $Definition = New-Object System.Text.StringBuilder
                $i++
            }
        }
        if ($functionsearch) {
            If ($i -gt 1 -AND ($tokens[$i].StartLine -eq $tokens[$i-1].EndLine)) {
                $SpaceCount = $tokens[$i].StartColumn - $tokens[$i-1].EndColumn
                $space = ' '*"$($SpaceCount)"
                If ($SpaceCount -gt 0) {
                    If ($SpaceCount -notmatch '^[5|9]$') {
                        Write-Verbose "Adding Space: $($SpaceCount)"
                        [void]$Definition.Append($Space)
                    } ElseIf ($SpaceCount -match '^[5|9]$') {
                        Write-Verbose "Adding NewLine"
                        [void]$Definition.Append("`n")
                    }
                }
            }
            Write-Verbose $tokens[$i].Content
            Switch ($tokens[$i].Type) {
                'NewLine' {
                    Write-Verbose 'Adding NewLine'
                    [void]$Definition.Append("`n")
                }
                'CommandArgument' {
                    If (-NOT $IsName) {
                        $Name = $tokens[$i].Content
                        $IsName = $True
                        $ExpectingStart=$True
                    } Else {
                        [void]$Definition.Append($tokens[$i].Content)
                    }
                }
                'GroupStart' {
                    If ($tokens[$i].Content -eq '{') {
                        $Counter++
                        If ($ExpectingStart) {
                            $ExpectingStart = $False
                        }
                    }
                    [void]$Definition.Append($tokens[$i].Content)
                }
                'GroupEnd' {
                    If ($tokens[$i].Content -eq '}') {
                        $Counter--
                       If ($ExpectingStart) {
                            $ExpectingStart = $False
                       }
                    }
                    [void]$Definition.Append($tokens[$i].Content)
                }
                'Variable' {
                    [void]$Definition.Append("`$$($tokens[$i].Content)")
                }
                'Type' {
                    Switch ($PSVersionTable.PSVersion.Major) {
                        '2' {
                            [void]$Definition.Append("[$($tokens[$i].Content)]")
                        }
                        Default {
                            [void]$Definition.Append($($tokens[$i].Content))
                        }
                    }
                }
                Default {
                    [void]$Definition.Append($tokens[$i].Content)
                }
            }
            if ($Counter -eq 0 -AND -NOT $ExpectingStart) {
                $functionsearch = $false
                #Create the object and display it
                New-Object PSObject -Property @{
                    Name = $Name
                    Body = $Definition.ToString()
                }
            }
        }
    }
}
