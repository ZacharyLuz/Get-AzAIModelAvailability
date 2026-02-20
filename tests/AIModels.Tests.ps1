BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..' 'Get-AzAIModelAvailability.ps1'
    $scriptContent = Get-Content $scriptPath -Raw

    $functions = @('Test-ModelMatchesFilter', 'Group-AIModelsByProvider')
    foreach ($funcName in $functions) {
        $funcBlock = [regex]::Match($scriptContent, "(?ms)(function $funcName \{.+?\n\})")
        if ($funcBlock.Success) {
            Invoke-Expression $funcBlock.Value
        }
    }
}

Describe 'Test-ModelMatchesFilter' {
    Context 'No filter' {
        It 'Returns true when no filter patterns provided' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o' -FilterPatterns @() | Should -Be $true
        }

        It 'Returns true when filter is null' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o' -FilterPatterns $null | Should -Be $true
        }
    }

    Context 'Exact match' {
        It 'Matches exact model name' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o' -FilterPatterns @('gpt-4o') | Should -Be $true
        }

        It 'Does not match different model name' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o' -FilterPatterns @('gpt-4o-mini') | Should -Be $false
        }

        It 'Is case-insensitive' {
            Test-ModelMatchesFilter -ModelName 'GPT-4o' -FilterPatterns @('gpt-4o') | Should -Be $true
        }
    }

    Context 'Wildcard patterns' {
        It 'Matches with trailing wildcard' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o-mini' -FilterPatterns @('gpt-4*') | Should -Be $true
        }

        It 'Matches with leading wildcard' {
            Test-ModelMatchesFilter -ModelName 'text-embedding-3-large' -FilterPatterns @('*embedding*') | Should -Be $true
        }

        It 'Matches with middle wildcard' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o-mini' -FilterPatterns @('gpt-*-mini') | Should -Be $true
        }

        It 'Matches single-char wildcard' {
            Test-ModelMatchesFilter -ModelName 'gpt-4o' -FilterPatterns @('gpt-?o') | Should -Be $true
        }

        It 'Does not match when pattern does not fit' {
            Test-ModelMatchesFilter -ModelName 'claude-sonnet' -FilterPatterns @('gpt-*') | Should -Be $false
        }
    }

    Context 'Multiple patterns' {
        It 'Matches if any pattern matches' {
            Test-ModelMatchesFilter -ModelName 'claude-sonnet-4-5' -FilterPatterns @('gpt-*', 'claude*') | Should -Be $true
        }

        It 'Returns false when no pattern matches' {
            Test-ModelMatchesFilter -ModelName 'Llama-3.3' -FilterPatterns @('gpt-*', 'claude*') | Should -Be $false
        }
    }
}

Describe 'Group-AIModelsByProvider' {
    BeforeAll {
        $mockModels = @(
            [PSCustomObject]@{
                model = [PSCustomObject]@{
                    format          = 'OpenAI'
                    name            = 'gpt-4o'
                    version         = '2024-08-06'
                    lifecycleStatus = 'GenerallyAvailable'
                    maxCapacity     = 150
                    skus            = @(
                        [PSCustomObject]@{ name = 'Standard' },
                        [PSCustomObject]@{ name = 'GlobalStandard' }
                    )
                }
            },
            [PSCustomObject]@{
                model = [PSCustomObject]@{
                    format          = 'OpenAI'
                    name            = 'gpt-4o'
                    version         = '2024-11-20'
                    lifecycleStatus = 'GenerallyAvailable'
                    maxCapacity     = 150
                    skus            = @(
                        [PSCustomObject]@{ name = 'Standard' }
                    )
                }
            },
            [PSCustomObject]@{
                model = [PSCustomObject]@{
                    format          = 'OpenAI'
                    name            = 'gpt-4o-mini'
                    version         = '2024-07-18'
                    lifecycleStatus = 'Preview'
                    maxCapacity     = 100
                    skus            = @(
                        [PSCustomObject]@{ name = 'GlobalStandard' }
                    )
                }
            },
            [PSCustomObject]@{
                model = [PSCustomObject]@{
                    format          = 'Meta'
                    name            = 'Llama-3.3-70B'
                    version         = '1'
                    lifecycleStatus = 'Stable'
                    maxCapacity     = 50
                    skus            = @(
                        [PSCustomObject]@{ name = 'GlobalStandard' }
                    )
                }
            }
        )
    }

    It 'Groups models by provider' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        $result.Count | Should -Be 2
        ($result | Where-Object Provider -eq 'OpenAI') | Should -Not -BeNullOrEmpty
        ($result | Where-Object Provider -eq 'Meta') | Should -Not -BeNullOrEmpty
    }

    It 'Counts total models per provider' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        ($result | Where-Object Provider -eq 'OpenAI').TotalModels | Should -Be 3
        ($result | Where-Object Provider -eq 'Meta').TotalModels | Should -Be 1
    }

    It 'Counts unique model names per provider' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        ($result | Where-Object Provider -eq 'OpenAI').UniqueNames | Should -Be 2
    }

    It 'Counts lifecycle statuses correctly' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        $openai = $result | Where-Object Provider -eq 'OpenAI'
        $openai.GA | Should -Be 2
        $openai.Preview | Should -Be 1
        $openai.Stable | Should -Be 0
    }

    It 'Collects deployment types' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        $openai = $result | Where-Object Provider -eq 'OpenAI'
        $openai.DeployTypes | Should -Match 'Standard'
        $openai.DeployTypes | Should -Match 'GlobalStandard'
    }

    It 'Sets region on each summary' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'westeurope'
        $result | ForEach-Object { $_.Region | Should -Be 'westeurope' }
    }

    It 'Identifies top model by SKU count' {
        $result = Group-AIModelsByProvider -Models $mockModels -Region 'eastus2'
        $openai = $result | Where-Object Provider -eq 'OpenAI'
        $openai.TopModel | Should -Be 'gpt-4o'
    }
}
