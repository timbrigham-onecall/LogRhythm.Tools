using namespace System.Collections.Generic
<#
    .SYNOPSIS
        Takes the output object generated by Invoke-PIE and produces summary suitable for LogRhythm Case.
    .OUTPUTS
        String containing summary for the e-mail submitted and evaluated.
    .EXAMPLE
        Format-PIECaseSummary -ReportEvidence $ReportEvidence
        ---
        === PIE Analysis Summary ===
        --- Submitted E-mail ---
        Reported On: 11/29/2020 3:02:06 PM
        Reported By: passmossis@outlook.com
        Subject: PhishAlert: Mimecast Test

        --- Evaluated E-mail ---
        Email Parsed Format: eml
        Sent On: 11/18/2020 16:15:23                Received On: 11/18/2020 16:17:10
        Sender: ThreatDNA@optiv.com                 Sender Display Name: ThreatDNA
        Subject: ThreatDNA ThreatBEAT Advisory: November 18, 2020 - CostaRicto Hacker-for-Hire Group

        --- PIE Metadata ---
        PIE Version: 3.7         LogRhythm Tools Version: 1.1.0
        Evaluation ID: 5e0d83c3-5402-4c73-a624-4c3b96e986fd
        Start: 2020-11-30T22485194Z    Stop: 2020-11-30T22495865Z     Duration: 00:01:06.7063393
    .NOTES
        PIE      
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>
function Format-PIECaseSummary {
    [CmdLetBinding()]
    param( 
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [object] $ReportEvidence
    )

    Begin {
    }

    Process {
        $CaseOutput = [list[String]]::new()


        $CaseOutput.Add("=== PIE Analysis Summary ===")

        $CaseOutput.Add("--- Submitted E-mail ---")
        $CaseOutput.Add("Reported On: $($ReportEvidence.ReportSubmission.Date)")
        $CaseOutput.Add("Reported By: $($ReportEvidence.ReportSubmission.Sender)")
        $CaseOutput.Add("Subject: $($ReportEvidence.ReportSubmission.Subject.Original)")
        $CaseOutput.Add("")
        $CaseOutput.Add("--- Evaluated E-mail ---")
        $CaseOutput.Add("Email Parsed Format: $($ReportEvidence.EvaluationResults.ParsedFromFormat)")
        $DateString1 = "Sent On: $($ReportEvidence.EvaluationResults.Date.SentOn)"
        $DateString2 = "Received On: $($ReportEvidence.EvaluationResults.Date.ReceivedOn)"
        $CaseOutput.Add("$DateString1 $($DateString2.PadLeft(46-($DateString1.length)+$($DateString2.length)))")
        $SenderString1 = "Sender: $($ReportEvidence.EvaluationResults.Sender)"
        $SenderString2 = "Sender Display Name: $($ReportEvidence.EvaluationResults.SenderDisplayName)"
        $CaseOutput.Add("$SenderString1 $($SenderString2.PadLeft(43-($SenderString1.length)+$($SenderString2.length)))")
        $Recipients = ($ReportEvidence.EvaluationResults.Recipient | Select-Object -ExpandProperty To) -join ", "
        if ($Recipients) {
            $CaseOutput.Add("Recipients: $Recipients")
        }
        if ($ReportEvidence.EvaluationResults.Recipient.CC) {
            $CCRecipients = ($ReportEvidence.EvaluationResults.Recipient | Select-Object -ExpandProperty CC) -join ", "
            $CaseOutput.Add("CC Recipients: $CCRecipients")
        }
        $CaseOutput.Add("Subject: $($ReportEvidence.EvaluationResults.Subject.Original)")
        $CaseOutput.Add("")
        $CaseOutput.Add("--- PIE Metadata ---")
        $PIEVersion = "PIE Version: $($ReportEvidence.Meta.Version.PIE)"
        $LRTVersion = "LogRhythm Tools Version: $($ReportEvidence.Meta.Version.LRTools)"
        $CaseOutput.Add("$PIEVersion $($LRTVersion.PadLeft(24-($PIEVersion.length)+$($LRTVersion.length)))")
        $CaseOutput.Add("Evaluation ID: $($ReportEvidence.Meta.Guid)")
        $RuntimeMetrics1 = "Start: $($ReportEvidence.Meta.Metrics.Begin)"
        $RuntimeMetrics2 = "Stop: $($ReportEvidence.Meta.Metrics.End)"
        $RuntimeMetrics3 = "Duration: $($ReportEvidence.Meta.Metrics.Duration)"
        $CaseOutput.Add("$RuntimeMetrics1 $($RuntimeMetrics2.PadLeft(30-($RuntimeMetrics1.length)+$($RuntimeMetrics2.length))) $($RuntimeMetrics3.PadLeft(30-($RuntimeMetrics2.length)+$($RuntimeMetrics3.length)))")
        # $CaseOutput.Add("Additional Subjects from sender:")
        # 

        return $CaseOutput | Out-String
    }
}
