using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrCaseOwner {
    <#
    .SYNOPSIS
        Update the assigned owner of a case.
    .DESCRIPTION
        The Update-LrCaseOwner cmdlet updates the case owner on an existing case.
    .PARAMETER Id
        Unique identifier for the case, either as an RFC 4122 formatted string, or as a number.
    .PARAMETER Owner
        Numeric person identifier or person name.  Nme should match the person record explicitly.

        [Int32] (Number) or [System.String] (Name)
        Specifies a LogRhythm case owner by providing one of the following property values:
          + Person Number (as Int32), e.g. 17
          + Person Name (as System.String), e.g. "Hart, Eric"
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
        Note: You can bypass the need to provide a Credential by setting
        the preference variable $LrtConfig.LogRhythm.ApiKey
        with a valid Api Token.
    .INPUTS
        [System.Object]     ->  Id
        [System.String]    ->  Owner
    .OUTPUTS
        PSCustomObject representing the modified LogRhythm Case.
    .EXAMPLE
        PS C:\> Update-LrCaseOwner -Id 5 -Owner "Hart, Eric"
    .EXAMPLE
        PS C:\> Update-LrCaseOwner -Id 5 -Owner 17
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools     
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNull()]
        [object] $Id,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNull()]
        [String] $Owner,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )


    Begin {
        $Me = $MyInvocation.MyCommand.Name
        
        $BaseUrl = $LrtConfig.LogRhythm.CaseBaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        # Enable self-signed certificates and Tls1.2
        Enable-TrustAllCertsPolicy

        # Request Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Headers.Add("Content-Type","application/json")


        # Request URI
        $Method = $HttpMethod.Put

        # https://docs.microsoft.com/en-us/dotnet/api/system.int32.tryparse
        $_int = 0
    }


    Process {
        # Establish General Error object Output
        $ErrorObject = [PSCustomObject]@{
            Code                  =   $null
            Error                 =   $false
            Type                  =   $null
            Note                  =   $null
            ResponseUrl           =   $null
            Case                  =   $Id
        }
        Write-Verbose "[$Me]: Case Id: $Id"

        # Test CaseID Format
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }                                                      

        $RequestUrl = $BaseUrl + "/cases/$CaseNumber/actions/addCollaborators/"
        Write-Verbose "[$Me]: RequestUrl: $RequestUrl"
        #endregion

        [int32] $ValidUserID
        if ([int]::TryParse($Owner, [ref]$_int)) {
            Write-Verbose "[$Me]: Owner parses as integer."
            $UserStatus = Get-LrUserNumber -User $Number
            if ($UserStatus) {
                $ValidUserId = $UserStatus
            }
        } else {
            Write-Verbose "[$Me]: Owner processed as string."
            $UserStatus = Get-LrUserNumber -User $Name
            if ($UserStatus) {
                $ValidUserId = $UserStatus
            }
        }

        Write-Verbose "ValidUserId: $ValidUserId"
        # Create request body with people numbers
        if (!($ValidUserId -Is [System.Array])) {
            # only one tag, use simple json
            Write-Verbose "Here"
            $Body = "{ `"numbers`": [$ValidUserId] }"
        } else {
            # multiple values, create an object
            $Body = ([PSCustomObject]@{ numbers = $ValidUserId }) | ConvertTo-Json
        }
        #endregion



        #region: Make Request                                                            
        Write-Verbose "[$Me]: request body is:`n$Body"

        # Make Request
        if ($PSEdition -eq 'Core'){
            try {
                $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -Body $Body -SkipCertificateCheck
            }
            catch {
                $Err = Get-RestErrorMessage $_
                $ErrorObject.Code = $Err.statusCode
                $ErrorObject.Type = "WebException"
                $ErrorObject.Note = $Err.message
                $ErrorObject.ResponseUrl = $RequestUrl
                $ErrorObject.Error = $true
                return $ErrorObject
            }
        } else {
            try {
                $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -Body $Body
            }
            catch [System.Net.WebException] {
                $Err = Get-RestErrorMessage $_
                $ErrorObject.Code = $Err.statusCode
                $ErrorObject.Type = "WebException"
                $ErrorObject.Note = $Err.message
                $ErrorObject.ResponseUrl = $RequestUrl
                $ErrorObject.Error = $true
                return $ErrorObject
            }
        }
        
        return $Response
    }


    End { }
}