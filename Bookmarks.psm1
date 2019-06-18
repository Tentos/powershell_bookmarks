enum BookmarkType {
    Unknown
    File
    Directory
}

class Bookmark {
    [ValidateNotNullOrEmpty()][string] $Description;
    [ValidateNotNullOrEmpty()][System.IO.FileSystemInfo] $Location;

    Bookmark([string] $Description, [System.IO.FileSystemInfo] $Location) {
        $this.Description = $Description;
        $this.Location = $Location;
    }

    Bookmark([string] $Description, [string] $LocationAsString) {
        if (-not $LocationAsString) {
            throw "Location is missing in constructor of class 'Bookmark'";
        }

        $this.Description = $Description;
        if (Test-Path $LocationAsString) {
            try {
                $this.Location = Get-Item $LocationAsString;
            }
            catch [System.Management.Automation.SetValueInvocationException] {
                throw "Given location '$LocationAsString' is not a file system path"
            }
        }
        else {
            try {
                $this.Location = [System.IO.FileInfo]::new($LocationAsString);
            }
            catch [System.NotSupportedException] {
                throw "Given location '$LocationAsString' is not a file system path"
            }
        }
    }

    static [Bookmark] reserialize([PSObject] $deserializedBookmark) {
        if ($deserializedBookmark.ToString() -eq [Bookmark].ToString()) {
            return [Bookmark]::new($deserializedBookmark.Description, $deserializedBookmark.Location.ToString())
        }
        throw "Given deserialized PSObject is not of type 'Bookmark', but of type '$($deserializedBookmark.ToString())'";
    }
}

$DecideBookmarkMode = {
    If (Test-Path $this.Location) {
        $itemType = (Get-Item $this.Location).GetType().Name;
        switch ($itemType) {
            "FileInfo" { return "-f-" }
            "DirectoryInfo" { return "d--" }
            Default {throw "Unknown bookmark type '$itemType'"}
        }
    }
    else {
        return "--u";
    }
}

$DecideBookmarkType = {
    param($returnForFile, $returnForDirectory, $returnForUnknown)
    If (Test-Path $this.Location) {
        $itemType = (Get-Item $this.Location).GetType().Name;
        switch ($itemType) {
            "FileInfo" { return [BookmarkType]::File }
            "DirectoryInfo" { return [BookmarkType]::Directory }
            Default {throw "Unknown bookmark type '$itemType'"}
        }
    }
    else {
        return [BookmarkType]::Unknown;
    }
}


Update-TypeData -TypeName Bookmark -MemberType ScriptProperty -MemberName Mode -Value $DecideBookmarkMode -Force;
Update-TypeData -TypeName Bookmark -MemberType ScriptProperty -MemberName Type -Value $DecideBookmarkType -Force;
Update-TypeData -TypeName Bookmark -SerializationDepth 0 -Force;
Update-TypeData -TypeName Bookmark -SerializationMethod SpecificProperties -PropertySerializationSet Description, Location -Force;
Update-TypeData -TypeName Bookmark -DefaultDisplayPropertySet Mode, Description, Location -Force;

$Script:Bookmarks = [System.Collections.Generic.List[Bookmark]]::new();
$Script:BookmarksFilename = "psbookmarks.xml";
$Script:directorySeparator = [System.IO.Path]::DirectorySeparatorChar;
$Global:old_prompt = Get-Content "Function:\prompt";

function prompt {
    $bookmarksWithCurrentLocation = Get-Bookmark | Where-Object {$_.Location.FullName.TrimEnd($Script:directorySeparator) -eq (Get-Location).Path.TrimEnd($Script:directorySeparator)};
    if ($bookmarksWithCurrentLocation.Length -ge 1) {
        $firstCurrentLocationBookmark = $bookmarksWithCurrentLocation | Select-Object -Index 0;
        $prefix = "[$($firstCurrentLocationBookmark.Description)] ";
    }
    $oldPromptText = Invoke-Command -ScriptBlock $Global:old_prompt;
    Write-Host -Object $prefix -NoNewline -ForegroundColor Cyan;
    return $oldPromptText;
}

function New-Bookmark {
    Param(
        [Parameter(Mandatory = $true)][String]$Description,
        [Parameter()][string]$Location = $(Get-Location)
    )
    $Script:Bookmarks.Add([Bookmark]::new($Description, $Location)) | Out-Null;
}

function Get-Bookmark([string] $DescriptionLike) {
    return ($Script:Bookmarks | Where-Object -Property Description -Like "*$DescriptionLike*");
}

function Get-BookmarkExactDescription([string] $Description) {
    return ($Script:Bookmarks | Where-Object -Property Description -EQ $Description);
}

function Invoke-Bookmark([string] $DescriptionLike) {
    $foundBookmarks = Get-BookmarkExactDescription $DescriptionLike;
    if ($foundBookmarks.Length -eq 0) {
        $foundBookmarks = Get-Bookmark -DescriptionLike $DescriptionLike;
    }
    if ($foundBookmarks.Length -eq 0) {
        throw "No matching bookmark found for description '${descriptionLike}'"
    }
    elseif ($foundBookmarks.Length -ge 2) {
        throw "Description '$DescriptionLike' is ambiguous. Possible matching bookmarks: $($foundBookmarks.description)"
    }

    $bookmarkLocation = $foundBookmarks.Location;
    switch ($foundBookmarks.Type) {
        Directory { Set-Location $bookmarkLocation; }
        File { Invoke-Item $bookmarkLocation; }
        Unknown { throw [System.Management.Automation.ItemNotFoundException] "Location '$bookmarkLocation' of bookmark does not exist"; }
        Default { throw "Bookmark Type '$($foundBookmarks.Type)' not supported." }
    }
}

function Remove-Bookmark([string] $Description) {
    $foundBookmarks = Get-BookmarkExactDescription $Description;
    if ($foundBookmarks.Length -ge 2) {
        $foundBookmarks = $foundBookmarks.Item(0);
    }
    $Script:Bookmarks.Remove($foundBookmarks) | Out-Null;
}

function Export-Bookmarks() {
    $BookmarksFolder = Get-ExportBookmarksFolder;
    if (-not (Test-Path $BookmarksFolder)) {
        New-Item -ItemType Directory -Path $BookmarksFolder;
    }
    $BookmarksFilePath = Join-Path $BookmarksFolder $Script:BookmarksFilename;

    Export-Clixml -Path $BookmarksFilePath -InputObject $Script:Bookmarks -Encoding UTF8 -Depth 1;
}

function Import-Bookmarks() {
    $Script:Bookmarks.Clear();

    $BookmarksFilePath = Join-Path (Get-ExportBookmarksFolder) $Script:BookmarksFilename;
    if (-not (Test-Path $BookmarksFilePath)) {
        throw "The file '$BookmarksFilePath' with exported bookmarks does not exist. Please export bookmarks before importing."
    }

    $importedBookmarks = Import-Clixml -Path $BookmarksFilePath;
    foreach ($item in $importedBookmarks) {
        $Script:Bookmarks.Add([Bookmark]::reserialize($item));
    }
}

function Get-ExportBookmarksFolder() {
    return Join-Path -Path $env:APPDATA -ChildPath "PSBookmarks" 
}

function Add-Marks([string] $text) {
    if ($text.Contains(" ")) {
        return "`'$text`'";
    }
    return $text;
}

[scriptblock] $defaultCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    Get-Bookmark -descriptionLike "$wordToComplete" |
        ForEach-Object {
        [System.Management.Automation.CompletionResult]::new((Add-Marks $_.description), $_.description, 'ParameterValue', $_.description)
    }
};

Register-ArgumentCompleter -CommandName Invoke-Bookmark -ParameterName descriptionLike -ScriptBlock $defaultCompleter
Register-ArgumentCompleter -CommandName Get-Bookmark -ParameterName descriptionLike -ScriptBlock $defaultCompleter
Register-ArgumentCompleter -CommandName Remove-Bookmark -ParameterName description -ScriptBlock $defaultCompleter

New-Alias -Name nb -Value New-Bookmark;
New-Alias -Name gb -Value Get-Bookmark;
New-Alias -Name ib -Value Invoke-Bookmark;
New-Alias -Name rb -Value Remove-Bookmark;
New-Alias -Name ebs -Value Export-Bookmarks;
New-Alias -Name ibs -Value Import-Bookmarks;

Export-ModuleMember -Function New-Bookmark;
Export-ModuleMember -Function Get-Bookmark;
Export-ModuleMember -Function Invoke-Bookmark;
Export-ModuleMember -Function Remove-Bookmark;
Export-ModuleMember -Function Export-Bookmarks;
Export-ModuleMember -Function Import-Bookmarks;
Export-ModuleMember -Function prompt;

Export-ModuleMember -Alias *;