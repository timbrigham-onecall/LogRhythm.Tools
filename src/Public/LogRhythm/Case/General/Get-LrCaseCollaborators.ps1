using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrCaseCollaborators {
    <#
    .SYNOPSIS
        Returns the summary of all collaborators and current assigned owner for a given case.
    .DESCRIPTION
        The Get-LrCaseCollaborators cmdlet returns the LogRhythm Case collaborators specified by the ID parameter.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
        Note: You can bypass the need to provide a Credential by setting
        the preference variable $LrtConfig.LogRhythm.ApiKey
        with a valid Api Token.
    .PARAMETER Id
        Unique identifier for the case, either as an RFC 4122 formatted string, or as a number.
    .INPUTS
        System.Object -> Id
    .OUTPUTS
        PSCustomObject representing the (new|modified) LogRhythm object.
    .EXAMPLE
        PS C:\> Get-LrCaseCollaborators -Id 1785


    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true, 
            ValueFromPipelineByPropertyName = $true, 
            Position = 0
        )]
        [ValidateNotNull()]
        [object] $Id,


        [Parameter(Mandatory = $false, Position = 1)]
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

        # Request URI
        $Method = $HttpMethod.Get

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
            Value                 =   $Id
        }

        # Test CaseID Format
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }
        
        $RequestUrl = $BaseUrl + "/cases/$Id/collaborators/"

        if ($PSEdition -eq 'Core'){
            try {
                $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method -SkipCertificateCheck
            }
            catch {
                $Err = Get-RestErrorMessage $_
                $ErrorObject.Error = $true
                $ErrorObject.Type = "System.Net.WebException"
                $ErrorObject.Code = $($Err.statusCode)
                $ErrorObject.Note = $($Err.message)
                return $ErrorObject
            }
        } else {
            try {
                $Response = Invoke-RestMethod $RequestUrl -Headers $Headers -Method $Method
            }
            catch [System.Net.WebException] {
                $Err = Get-RestErrorMessage $_
                $ErrorObject.Error = $true
                switch ($Err.statusCode) {
                    "404" {
                        $ErrorObject.Type = "KeyNotFoundException"
                        $ErrorObject.Code = 404
                        $ErrorObject.Note = "Value not found, or you do not have permission to view it."
                     }
                     "401" {
                        $ErrorObject.Type = "UnauthorizedAccessException"
                        $ErrorObject.Code = 401
                        $ErrorObject.Note = "Credential '$($Credential.UserName)' is unauthorized to access 'lr-case-api'"
                     }
                    Default {
                        $ErrorObject.Type = "System.Net.WebException"
                        $ErrorObject.Note = $Err.message
                    }
                }
                return $ErrorObject
            }
        }

        return $Response
    }


    End { }
}