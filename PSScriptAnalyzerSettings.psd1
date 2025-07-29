# PSScriptAnalyzer Settings for ProcessManager Project
@{
    # Include default rules
    IncludeDefaultRules = $true
    
    # Custom rule configuration
    Rules = @{
        # Naming conventions
        PSUseApprovedVerbs = @{
            Enable = $true
        }
        PSUseSingularNouns = @{
            Enable = $true
        }
        PSReservedCmdletChar = @{
            Enable = $true
        }
        PSReservedParams = @{
            Enable = $true
        }
        
        # Best practices
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
        PSUsePSCredentialType = @{
            Enable = $true
        }
        PSUseBOMForUnicodeEncodedFile = @{
            Enable = $true
        }
        
        # Security
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }
        PSAvoidUsingUsernameAndPasswordParams = @{
            Enable = $true
        }
        
        # Performance and reliability
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
        PSUseOutputTypeCorrectly = @{
            Enable = $true
        }
        PSAvoidGlobalVars = @{
            Enable = $true
        }
        PSUseCmdletCorrectly = @{
            Enable = $true
        }
        
        # Code style
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
            CheckParameter = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize = 4
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing = @{
            Enable = $true
        }
    }
    
    # Exclude specific rules if needed
    ExcludeRules = @(
        # Uncomment if you need to use Write-Host for UI
        # 'PSAvoidUsingWriteHost'
        
        # Uncomment if you use Invoke-Expression intentionally
        # 'PSAvoidUsingInvokeExpression'
    )
    
    # Include/Exclude specific files or paths
    IncludeRules = @()
    
    # Severity levels to include
    Severity = @('Error', 'Warning', 'Information')
    
    # Custom rules (if you have any)
    CustomRulePath = @()
}