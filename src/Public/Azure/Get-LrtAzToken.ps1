using namespace System
using namespace System.Net
using namespace System.Collections.Generic
using namespace System.Security.Authentication
using namespace System.Web

Function Get-LrtAzToken {
    <#
    .SYNOPSIS
        Get an access token to access a Microsoft Defender ATP protected resource.
    .DESCRIPTION
        The Get-LrtAzToken cmdlet returns an access token for Microsoft Azure protected resources.
        The access token returned by this cmdlet is a an object containing the token itself, expiry
        information, and a URL to the resource endpoint.

        LogRhythm.Tools's implementation of Microsoft Azure utilizes the Azure Active Directory (v1.0)
        endpoint to request access tokens, via OAuth2.

        Because the LogRhythm.Tools module does not act on behalf of users, dynamic / incremental
        consent considerations are not necessary. Additionally, the Microsoft Identity Platform endpoint
        doesn't support all Azure AD scenarios and features at this time.

        For more information on AAD and Identity Protection, see:
        https://docs.microsoft.com/en-us/azure/active-directory/develop/azure-ad-endpoint-comparison
    .PARAMETER ResourceName
        The name of the resource for which to obtain a token. This can either be "AzureAD" or "DefenderATP",
        which are the two supported Azure resourced in LogRhythm.Tools
    .INPUTS
        [System.String] => $ResourceName
    .OUTPUTS
        [System.Object] representing an Azure resource access token.

        Object Properties
        -----------------
        token_type      = "Bearer"
        expires_in      = Expiry timespan
        ext_expires_in  = Expiry timespan
        expires_on      = Expiry timestamp
        not_before      = Creation timestamp
        resource        = Resource URL
        access_token    = Bearer Token String
    .EXAMPLE
        PS C:\> $AccessToken = Get-LrtAzToken

    .EXAMPLE
        PS C:\> $Credential = Import-CliXml -Path c:\secret.xml
        PS C:\> $Token = Get-LrtAzToken -Credential $Credential -OAuth2Url "http://..."

        Description
        -----------
        Deserialize an encrypted PSCredential and returns an access token to $Token.
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [ValidateSet('AzureAD','DefenderATP')]
        [string] $ResourceName,


        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNull()]
        [pscredential] $Credential

    )


    # [ResourceUri]:
    # In Azure, the term resource refers to an entity managed by Azure. The ResourceUri 
    # parameter is a Uri which will provide access to the desired resource, for example:
    # https://graph.microsoft.com provides access to Microsoft Graph.
    # By default, this value is retrieved from the LogRhythm.Tools configuration file generated by Setup.ps1

    # [OAuth2Url]:
	# Url to the OAuth2 token issuing endpoint that provides an access token for a resource.
    # By default, this value is retrieved from the LogRhythm.Tools configuration file generated by Setup.ps1
    
    # [Credential]:
	# A PSCredential for an Azure Application Client containing the Client Id and Client Secret
	# in the UserName and Password properties, respectively.
    # By default, this value is retrieved from the LogRhythm.Tools configuration file generated by Setup.ps1

    Begin { 
        $Me = $MyInvocation.MyCommand.Name 

        # Get Proper Credential
        if (! $Credential) {
            # Error message to use in case we can't match a key.
            $Err = "Valid key not found, please specify either 'AzureAD' or DefenderATP', "
            $Err += "and ensure a valid key has been set in LogRhythm.Tools configuration."
            switch ($ResourceName) {
                "AzureAd" { $Credential = $LrtConfig.AzureAD.ApiKey }
                "DefenderATP" { $Credential = $LrtConfig.DefenderATP.ApiKey }
                Default { throw [ArgumentException] $Err }
            }
        }
    }


    Process {
        # Get ResourceUri & OAuth2Url based on $ResourceName
        $ResourceUri = ""
        switch ($ResourceName) {
            "AzureAd" {
                $ResourceUri = $LrtConfig.AzureAD.Resource
                $OAuth2Url = $LrtConfig.AzureAD.OAuth2Url
            }
            "DefenderATP" { 
                $ResourceUri = $LrtConfig.DefenderATP.Resource
                $OAuth2Url = $LrtConfig.DefenderATP.OAuth2Url
            }
        }


        # Credentials
        $CliendId = $Credential.UserName
        $ClientSecret = $Credential.GetNetworkCredential().Password

        # UrlEncode Parameters
        $ClientSecret = [HttpUtility]::UrlEncode($ClientSecret)
        $ResourceUri = [HttpUtility]::UrlEncode($ResourceUri)


        # Body
        $Body = "resource=$ResourceUri&"
        $Body += "client_id=$CliendId&"
        $Body += "client_secret=$ClientSecret&"
        $Body += "grant_type=client_credentials"

        # Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $ClientSecret")
        $Headers.Add("Content-Type",$HttpContentType.FormUrl)


        # Request
        try {
            $Token = Invoke-RestMethod `
                -Uri $OAuth2Url `
                -Headers $Headers `
                -Method $HttpMethod.Post `
                -Body $Body
        }
        catch [WebException] {
            $Err = Get-RestErrorMessage $_
            throw [Exception] "[$Me] [$($Err.error)]: $($Err.error_description)`n"
        }

        return $Token
    }


    End { }
}