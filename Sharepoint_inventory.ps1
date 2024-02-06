# Parameters.
$SiteURL = "https://xxx.sharepoint.com/sites/xxx"
$CSVFile = Join-Path -Path $OutputFolder -ChildPath ("SiteInventory_" + (Split-Path -Leaf $SiteURL) + ".csv")
 
# Connect PnP Online
Connect-PnPOnline -Url $SiteURL -Interactive
 
# Delete the Output report file if exists.
If (Test-Path $CSVFile) { Remove-Item $CSVFile }
 
Function Get-VersioningAnalysis([Microsoft.SharePoint.Client.Web]$Web)
{
    # Connect to the Subsite.
    Connect-PnPOnline -Url $Web.Url -Interactive
 
    # Get All Document Libraries from the Web - Exclude Hidden and certain lists.
    $ExcludedLists = @("Form Templates", "Preservation Hold Library", "Site Assets", "Pages", "Site Pages", "Images", "Site Collection Documents", "Site Collection Images", "Style Library")
    $Lists = Get-PnPList | Where-Object { $_.Hidden -eq $False -and $_.Title -notin $ExcludedLists -and $_.BaseType -eq "DocumentLibrary" -and $_.ItemCount -gt 0 }
 
    # Iterate through all document libraries.
    ForEach ($List in $Lists)
    {
        # Get library information.
        $LibraryInfo = Get-PnPList -Identity $List.Id -Includes RootFolder
        $LibrarySize = [Math]::Round(($LibraryInfo.RootFolder.TotalSize / 1KB), 2)
 
        # Output library information.
        Write-Host "Library Information:"
        Write-Host " - Library Name: $($LibraryInfo.Title)"
        Write-Host " - Library URL: $($LibraryInfo.RootFolder.ServerRelativeUrl)"
        Write-Host " - Library Size (KB): $LibrarySize"
 
        $global:counter = 0
        $Files = Get-PnPListItem -List $List -PageSize 2000 -Fields File_x0020_Size, FileRef -ScriptBlock { Param($items) $global:counter += $items.Count; Write-Progress -PercentComplete ($global:Counter / ($List.ItemCount) * 100) -Activity "Getting Files of '$($List.Title)'" -Status "Processing Files $global:Counter to $($List.ItemCount)";}  | Where {$_.FileSystemObjectType -eq "File"}
 
        $VersionHistoryData = @()
        $Files | ForEach-Object {
            Write-Host "Getting Versioning Data of the File:"$_.FieldValues.FileRef
 
            # Get File Size and version Size.
            $FileSizeinKB = [Math]::Round(($_.FieldValues.File_x0020_Size / 1KB), 2)
            $File = Get-PnPProperty -ClientObject $_ -Property File
            $Versions = Get-PnPProperty -ClientObject $File -Property Versions
            $VersionSize = $Versions | Measure-Object -Property Size -Sum | Select-Object -expand Sum
            $VersionSizeinKB = [Math]::Round(($VersionSize / 1KB), 2)
            $TotalFileSizeKB = [Math]::Round(($FileSizeinKB + $VersionSizeinKB), 2)
 
            # Extract Version History data.
            $VersionHistoryData += New-Object PSObject -Property ([Ordered]@{
                "Site Name" = $Web.Title
                "Site URL" = $Web.URL
                "Library Name" = $List.Title
                "Library URL" = $LibraryInfo.RootFolder.ServerRelativeUrl
                "Library Size (KB)" = $LibrarySize
                "File Name" = $_.FieldValues.FileLeafRef
                "File URL" = $_.FieldValues.FileRef
                "Versions" = $Versions.Count
                "File Size (KB)" = $FileSizeinKB
                "Version Size (KB)" = $VersionSizeinKB
                "Total File Size (KB)" = $TotalFileSizeKB
            })
        }
        $VersionHistoryData | Export-Csv -Path $CSVFile -NoTypeInformation -Append
    }
}
 
# Get all subsites in a SharePoint Online site.
Get-PnPSubWeb -IncludeRootWeb | ForEach-Object {
    # Call the function to get version size.
    Write-Host -f Cyan "Getting Version History Data for "$_.URL
    Get-VersioningAnalysis $_
}