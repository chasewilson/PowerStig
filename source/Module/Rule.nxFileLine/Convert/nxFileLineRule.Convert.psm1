# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
using module .\..\..\Common\Common.psm1
using module .\..\..\Rule\Rule.psm1
using module .\..\nxFileLineRule.psm1

$exclude = @($MyInvocation.MyCommand.Name,'Template.*.txt')
$supportFileList = Get-ChildItem -Path $PSScriptRoot -Exclude $exclude
foreach ($supportFile in $supportFileList)
{
    Write-Verbose "Loading $($supportFile.FullName)"
    . $supportFile.FullName
}

<#
    .SYNOPSIS
        Convert the contents of an xccdf check-content and/or fixtext element
        into a Linux package object.
    .DESCRIPTION
        The nxFileLineRuleConvert class is used to extract the Linux file contents
        modification from the check-content of the xccdf. Once a STIG rule is
        identified as a nxFileLine rule, it is passed to the nxFileLineRuleConvert
        class for parsing and validation.
#>
class nxFileLineRuleConvert : nxFileLineRule
{
    <#
        .SYNOPSIS
            Empty constructor for SplitFactory.
    #>
    nxFileLineRuleConvert ()
    {
    }

    <#
        .SYNOPSIS
            Converts a xccdf STIG rule element into a nxFileLineRule.
        .PARAMETER XccdfRule
            The STIG rule to convert.
    #>
    nxFileLineRuleConvert ([xml.xmlelement] $XccdfRule) : base ($XccdfRule, $true)
    {
        $rawString = $this.SplitCheckContent
        $this.SetFilePath($rawString)
        if ($this.IsHardCodedOrganizationValueTestString())
        {
            $OrganizationValueTestString = $this.GetHardCodedOrganizationValueTestString()
            $this.set_OrganizationValueTestString($OrganizationValueTestString)
            $this.SetOrganizationValueRequired()
        }
        else
        {
            $this.SetContainsLine($rawString)
            $this.SetDoesNotContainPattern()
            if ($this.TestStringForRange($rawString))
            {
                $this.SetOrganizationValueRequired()
                $this.SetOrganizationValueTestString($rawString)
                $this.ContainsLine = [string]::Empty
            }
        }

        if ($this.conversionstatus -eq 'pass')
        {
            $this.SetDuplicateRule()
            $this.SetDscResource()
        }

        if ($null -ne $this.DuplicateOf)
        {
            $this.ClearOrgSettings()
        }
    }

    <#
        .SYNOPSIS
            Extracts the line to be modified from the check-content and sets the value.
        .DESCRIPTION
            Gets the line to be modified from the xccdf content and sets the value. If
            the name that is returned is not valid, the parser status is set to fail.
    #>
    [void] SetContainsLine ([string[]] $CheckContent)
    {
        $containsLine = Get-nxFileLineContainsLine -CheckContent $CheckContent

        if (-not $this.SetStatus($containsLine))
        {
            $this.set_ContainsLine($containsLine)
        }
    }

    <#
        .SYNOPSIS
            Extracts the file path from the check-content and sets the value.
        .DESCRIPTION
            Gets the file path from the xccdf content and sets the value. If
            the path that is returned is not valid, the parser status is set to fail.
    #>
    [void] SetFilePath ([string] $CheckContent)
    {
        $filePath = Get-nxFileLineFilePath -CheckContent $CheckContent

        if (-not $this.SetStatus($filePath))
        {
            $this.set_FilePath($filePath)
        }
    }

    <#
        .SYNOPSIS
            Extracts the DoesNotContainPattern from the check-content and sets the value.
        .DESCRIPTION
            Gets the DoesNotContainPattern from the xccdf content and sets the value. If
            the DoesNotContainPattern that is returned is not valid, the parser status
            is set to fail.
    #>
    [void] SetDoesNotContainPattern ()
    {
        $doesNotContainPattern = Get-nxFileLineDoesNotContainPattern

        if (-not $this.SetStatus($doesNotContainPattern))
        {
            $this.set_DoesNotContainPattern($doesNotContainPattern)
        }
    }

    [void] SetOrganizationValueTestString ([string[]] $CheckContent)
    {
        $result = $CheckContent -match '\s*If.*(?:greater|less|and\/or\s*other|higher).*this is a finding'
        $formattedResult = 'that the following statement is true when leveraging the correct nxFileLine ContainsLine format: "{0}" ' -f $result
        if ($null -ne $result)
        {
            $this.set_OrganizationValueTestString($formattedResult)
        }
    }

    [void] ClearOrgSettings ()
    {
        $this.OrganizationValueRequired = $false
        $this.OrganizationValueTestString = [string]::Empty
    }

    [bool] TestStringForRange ([string] $CheckContent)
    {
        if ($CheckContent -match '\s*If.*(?:greater|less|and\/or\s*other|higher).*this is a finding')
        {
            return $true
        }
        return $false
    }

    static [bool] Match ([string] $CheckContent)
    {
        if ($CheckContent -Match 'If.*"\w*".*commented out.*this is a finding|If.*"\w*".*is missing from.*file.*this is a finding')
        {
            return $true
        }

        return $false
    }

    <#
        .SYNOPSIS
            Tests if a rule contains multiple checks
        .DESCRIPTION
            Search the rule text to determine if multiple ContainLines are defined
        .PARAMETER CheckContent
            The rule text from the check-content element in the xccdf
    #>
    static [bool] HasMultipleRules ([string] $CheckContent)
    {
        return Test-nxFileLineMultipleEntries -CheckContent ([Rule]::SplitCheckContent($CheckContent))
    }

    <#
        .SYNOPSIS
            Splits a rule into multiple checks
        .DESCRIPTION
            Once a rule has been found to have multiple checks, the rule needs
            to be split. Each split rule id is appended with a dot and letter to
            keep reporting per the ID consistent. An example would be is V-1000
            contained 2 checks, then SplitMultipleRules would return 2 objects
            with rule ids V-1000.a and V-1000.b
        .PARAMETER CheckContent
            The rule text from the check-content element in the xccdf
    #>
    static [string[]] SplitMultipleRules ([string] $CheckContent)
    {
        return (Split-nxFileLineMultipleEntries -CheckContent ([Rule]::SplitCheckContent($CheckContent)))
    }

    hidden [void] SetDscResource ()
    {
        if ($null -eq $this.DuplicateOf)
        {
            $this.DscResource = 'nxFileLine'
        }
        else
        {
            $this.DscResource = 'None'
        }
    }
}
