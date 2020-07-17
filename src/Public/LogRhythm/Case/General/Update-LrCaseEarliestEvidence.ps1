using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrCaseEarliestEvidence {
    <#
    .SYNOPSIS
        Update the earliest evidence timestamp of an existing case using a custom timestamp
    .DESCRIPTION
        The Update-LrCaseEarliestEvidence cmdlet updates an existing case's earliest evidence based on a timestamp.

        Case Status must not be closed.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
        Note: You can bypass the need to provide a Credential by setting
        the preference variable $LrtConfig.LogRhythm.ApiKey
        with a valid Api Token.
    .PARAMETER Id
        Unique identifier for the case, either as an RFC 4122 formatted string, or as a number.
    .PARAMETER Timestamp
        Timestamp in DateTime format
    .PARAMETER Quiet
        Indicates that this cmdlet suppresses all output.
    .INPUTS
        [System.Object]     ->  Id
        [System.Datetime]   ->  Timestamp
    .OUTPUTS
        Optional summary output to validate Case Update status.
    .EXAMPLE
        PS C:\> Update-LrCaseEarliestEvidence -Id 8699 -Timestamp %TIME -Summary
        ---
        Updated Case: 8699 Earliest Evidence to Date: 2019-12-19T08:58:40Z
    .EXAMPLE
        PS C:\> Update-LrCaseEarliestEvidence -Id 2 -Timestamp "6/5/2020 13:46:49" -PassThru
        --- 
        created          : @{date=2020-06-06T13:46:49.4964154Z; originalDate=2020-06-06T13:46:49.4964154Z; customDate=; note=}
        completed        : @{date=; originalDate=; customDate=; note=}
        incident         : @{date=; originalDate=; customDate=; note=}
        mitigated        : @{date=; originalDate=; customDate=; note=}
        resolved         : @{date=; originalDate=; customDate=; note=}
        earliestEvidence : @{date=2020-06-05T17:46:49Z; originalDate=; customDate=2020-06-05T17:46:49Z; note=LogRhythm Tools: Update EarliestEvidence Timestamp}
    .EXAMPLE
        PS C:\> Update-LrCaseEarliestEvidence -Id "Case 2" -Timestamp "6/5/2020 13:46:47" -Summary
        ---
        Updated Case: Case 2 Earliest Evidence to Date: 2020-06-05T17:46:47Z
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey,


        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [object] $Id,


        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [datetime] $Timestamp,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 4)]
        [switch] $Summary
    )


    Begin {
        $Me = $MyInvocation.MyCommand.Name
        
        $BaseUrl = $LrtConfig.LogRhythm.CaseBaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        $ProcessedCount = 0
    }


    Process {
        # Get Case Id
        # Test CaseID Format
        $IdFormat = Test-LrCaseIdFormat $Id
        if ($IdFormat.IsGuid -eq $True) {
            # Lookup case by GUID
            try {
                $Case = Get-LrCaseById -Id $Id
            } catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
            # Set CaseNum
            $CaseNumber = $Case.number
        } elseif(($IdFormat.IsGuid -eq $False) -and ($IdFormat.ISValid -eq $true)) {
            # Lookup case by Number
            try {
                $Case = Get-LrCaseById -Id $Id
            } catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
            # Set CaseNum
            $CaseNumber = $Case.number
        } else {
            # Lookup case by Name
            try {
                $Case = Get-LrCases -Name $Id -Exact
            } catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
            # Set CaseNum
            $CaseNumber = $Case.number
        }


        # Set Existing EarliestEvidence Date for comparison
        $EarliestEvidence = Get-LrCaseEarliestEvidence -Id $CaseNumber
        Write-Verbose "[$Me]: Case: $CaseNumber EarliestEvidence: $EarliestEvidence"

        # Set Case Creation Date for comparison.  Earliest Evidence !> CaseCreationDate
        $CaseCreate = (Get-LrCaseById -Id $CaseNumber).dateCreated
        Write-Verbose "[$Me]: Case: $CaseNumber CaseCreateDate: $CaseCreate"

        # Set provided EarliestEvidence Date
        Try {
            $RequestedTimestamp = (Get-Date $Timestamp).ToUniversalTime()
        }
        Catch {
            $Err = Get-RestErrorMessage $_
            throw [Exception] "[$Me] [$($Err.statusCode)]: $($Err.message) $($Err.details)`n$($Err.validationErrors)`n"
        }

        $UpdateEvidence = $false
        $CaseCreateDate = (Get-Date $CaseCreate).ToUniversalTime()
        Write-Verbose "[$Me]: RequestedTimestamp: $RequestedTimestamp CaseCreateDate: $CaseCreateDate"
        if ($RequestedTimestamp -gt $CaseCreateDate) {
            # The AIE Cache logs contain an earlier point of evidence
            $UpdateEvidence = $false
            $Response = "RequestedTimestamp: $RequestedTimestamp is greater than CaseCreateDate: $CaseCreateDate"
        } else {
            if ($null -eq $EarliestEvidence) {
                # No Earliest Evidence found in the case
                $UpdateEvidence = $true
                # Convert NewEarliestEvidence date to proper format
                $NewEarliestEvidence = ($RequestedTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ"))
                Write-Verbose "[$Me]: NewEarliestEvidence: $NewEarliestEvidence"
            } else {
                $EarliestEvidenceDate = (Get-Date $EarliestEvidence).ToUniversalTime()
                Write-Verbose "[$Me]: RequestedTimestamp: $RequestedTimestamp EarliestEvidenceDate $EarliestEvidenceDate"
                if ($RequestedTimestamp -lt $EarliestEvidenceDate) {
                    # The AIE Cache logs contain an earlier point of evidence
                    $UpdateEvidence = $true
                    # Convert NewEarliestEvidence date to proper format
                    $NewEarliestEvidence = ($RequestedTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ"))
                    Write-Verbose "[$Me]: NewEarliestEvidence: $NewEarliestEvidence"
                } else {
                    $UpdateEvidence = $false
                    $Response = "RequestedTimestamp: $RequestedTimestamp is greater than EarliestEvidenceDate $EarliestEvidenceDate"
                }
            }
        }

        # Case note for API action
        $Note = "LogRhythm Tools: Update EarliestEvidence Timestamp"

        # Request Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Headers.Add("Content-Type","application/json")


        # Request URI
        $Method = $HttpMethod.Put
        $RequestUrl = $BaseUrl + "/cases/$CaseNumber/metrics/"


        # Request Body
        $Body = [PSCustomObject]@{
            earliestEvidence = [PSCustomObject]@{
                customDate = $NewEarliestEvidence
                note = $Note
            }
        } | ConvertTo-Json

        
        # Send Request
        Write-Verbose "[$Me]: request body is:`n$Body"
        if ($UpdateEvidence -eq $true) {
            if ($PSEdition -eq 'Core'){
                try {
                    $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -Body $Body -SkipCertificateCheck
                }
                catch [System.Net.WebException] {
                    $Err = Get-RestErrorMessage $_
                    throw [Exception] "[$Me] [$($Err.statusCode)]: $($Err.message) $($Err.details)`n$($Err.validationErrors)`n"
                }
            } else {
                try {
                    $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -Body $Body
                }
                catch [System.Net.WebException] {
                    $Err = Get-RestErrorMessage $_
                    throw [Exception] "[$Me] [$($Err.statusCode)]: $($Err.message) $($Err.details)`n$($Err.validationErrors)`n"
                }
            }
        } else {
            Write-Verbose "[$Me]: UpdateEvidence = $UpdateEvidence"
            return $null
        }

        $ProcessedCount++

        # Return
        if ($PassThru) {
            return $Response    
        }
    }

    
    End {
        if ($Summary) {
            if ($UpdateEvidence -eq $true) {
                Write-Host "Updated Case: $Id Earliest Evidence to Date: $NewEarliestEvidence"
            } else {
                Write-Host $Response
            }
        }
    }
}