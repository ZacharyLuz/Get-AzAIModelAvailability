BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..' 'Get-AzAIModelAvailability.ps1'
    $scriptContent = Get-Content $scriptPath -Raw

    # Extract helper functions for testing
    $functions = @('Get-SafeString', 'Invoke-WithRetry', 'Get-GeoGroup', 'Get-AzureEndpoints')
    foreach ($funcName in $functions) {
        $funcBlock = [regex]::Match($scriptContent, "(?ms)(function $funcName \{.+?\n\})")
        if ($funcBlock.Success) {
            Invoke-Expression $funcBlock.Value
        }
    }
}

Describe 'Get-SafeString' {
    It 'Returns empty string for null' {
        Get-SafeString -Value $null | Should -Be ''
    }

    It 'Returns the string as-is for a plain string' {
        Get-SafeString -Value 'hello' | Should -Be 'hello'
    }

    It 'Unwraps single-element array' {
        Get-SafeString -Value @('hello') | Should -Be 'hello'
    }

    It 'Unwraps nested arrays' {
        Get-SafeString -Value @(@('hello')) | Should -Be 'hello'
    }

    It 'Converts integer to string' {
        Get-SafeString -Value 42 | Should -Be '42'
    }
}

Describe 'Get-GeoGroup' {
    It 'Maps eastus to Americas-US' { Get-GeoGroup -LocationCode 'eastus' | Should -Be 'Americas-US' }
    It 'Maps westeurope to Europe' { Get-GeoGroup -LocationCode 'westeurope' | Should -Be 'Europe' }
    It 'Maps southeastasia to Asia-Pacific' { Get-GeoGroup -LocationCode 'southeastasia' | Should -Be 'Asia-Pacific' }
    It 'Maps australiaeast to Australia' { Get-GeoGroup -LocationCode 'australiaeast' | Should -Be 'Australia' }
    It 'Maps brazilsouth to Americas-LatAm' { Get-GeoGroup -LocationCode 'brazilsouth' | Should -Be 'Americas-LatAm' }
    It 'Maps centralindia to India' { Get-GeoGroup -LocationCode 'centralindia' | Should -Be 'India' }
    It 'Maps uaenorth to Middle East' { Get-GeoGroup -LocationCode 'uaenorth' | Should -Be 'Middle East' }
    It 'Maps southafricanorth to Africa' { Get-GeoGroup -LocationCode 'southafricanorth' | Should -Be 'Africa' }
    It 'Maps unknown region to Other' { Get-GeoGroup -LocationCode 'unknownregion' | Should -Be 'Other' }
    It 'Maps usgovvirginia to Americas-USGov' { Get-GeoGroup -LocationCode 'usgovvirginia' | Should -Be 'Americas-USGov' }
    It 'Maps canadacentral to Americas-Canada' { Get-GeoGroup -LocationCode 'canadacentral' | Should -Be 'Americas-Canada' }
}

Describe 'Get-AzureEndpoints' {
    Context 'Fallback behavior' {
        It 'Returns Commercial endpoints when no environment provided' {
            $endpoints = Get-AzureEndpoints
            $endpoints.EnvironmentName | Should -Be 'AzureCloud'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.azure.com'
        }
    }
}

Describe 'Invoke-WithRetry' {
    Context 'Successful execution' {
        It 'Returns result on first successful call' {
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -MaxRetries 3
            $result | Should -Be 'success'
        }

        It 'Returns array result correctly' {
            $result = Invoke-WithRetry -ScriptBlock { @(1, 2, 3) } -MaxRetries 3
            $result.Count | Should -Be 3
        }

        It 'Returns hashtable result correctly' {
            $result = Invoke-WithRetry -ScriptBlock { @{ key = 'value' } } -MaxRetries 3
            $result.key | Should -Be 'value'
        }
    }

    Context 'Non-retryable errors' {
        It 'Throws immediately for non-retryable errors' {
            { Invoke-WithRetry -ScriptBlock { throw [System.ArgumentException]::new('bad arg') } -MaxRetries 3 } |
            Should -Throw '*bad arg*'
        }
    }

    Context 'Retryable errors (429)' {
        It 'Retries on HTTP 429 and eventually succeeds' {
            $script:attempt429 = 0
            $result = Invoke-WithRetry -MaxRetries 3 -ScriptBlock {
                $script:attempt429++
                if ($script:attempt429 -le 2) { throw "HTTP 429 Too Many Requests" }
                'recovered'
            }
            $result | Should -Be 'recovered'
            $script:attempt429 | Should -BeGreaterThan 2
        }
    }

    Context 'Max retries exhausted' {
        It 'Throws after exhausting all retries' {
            { Invoke-WithRetry -MaxRetries 1 -ScriptBlock { throw "503 Service Unavailable" } } |
            Should -Throw '*503*'
        }
    }

    Context 'Zero retries' {
        It 'Does not retry when MaxRetries is 0' {
            { Invoke-WithRetry -MaxRetries 0 -ScriptBlock { throw "429 throttled" } } |
            Should -Throw '*429*'
        }
    }
}
