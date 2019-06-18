if (Test-Path Variable:\old_prompt) {
    Set-Content -Path "Function:\prompt" -Value $global:old_prompt;
}
Remove-Module Bookmarks -ErrorAction SilentlyContinue;
Import-Module .\Bookmarks.psm1 -Force

InModuleScope Bookmarks {
    function New-FolderInTestDrive([string] $folderName) {
        return New-Item -ItemType Directory -Path TestDrive:\ -Name $folderName;
    }

    function New-FileInTestDrive([string] $fileName) {
        return New-Item -ItemType File -Path TestDrive:\ -Name "${fileName}.txt";
    }
    Describe "Get-Bookmark" {
        $Bookmarks.Clear()

        $folderAlpha = New-FolderInTestDrive "folderAlpha";
        $fileAlphaA = New-FileInTestDrive "fileAlphaA";
        $folderBeta = New-FolderInTestDrive "folderBeta";
        $folderGamma = New-FolderInTestDrive "folderGamma";

        New-Bookmark -description "Alpha" -location $folderAlpha;    
        New-Bookmark -description "AlphaA" -location $fileAlphaA;    
        New-Bookmark -description "Beta" -location $folderBeta;    
        New-Bookmark -description "Gamma" -location $folderGamma;
    
        It "returns the bookmarks" {
            Get-Bookmark | Should -Not -BeNullOrEmpty;
            (Get-Bookmark).Length | Should -Be 4;
        }

        It "returns a bookmark for given matching description" {
            $foundTestbookmarks = Get-Bookmark -DescriptionLike Bet;
            $foundTestBookmarks.Length | Should -Be 1;
            $foundTestBookmarks.location | Should -BeLike $folderBeta;
            $foundTestBookmarks.description | Should -Be "Beta";
            $foundTestBookmarks.Mode | Should -Be "d--"
            $foundTestBookmarks.Type | Should -Be Directory
        }

        It "returns all bookmarks for given matching description if there are several" {
            $foundTestBookmarks = Get-Bookmark -descriptionLike "Alph";

            $foundTestBookmarks.Length | Should -Be 2;

            $foundTestBookmarks.Item(0).description | Should -BeExactly "Alpha";
            $foundTestBookmarks.Item(1).description | Should -BeExactly "AlphaA";

            $foundTestBookmarks.Item(0).location | Should -BeLike $folderAlpha;
            $foundTestBookmarks.Item(1).location | Should -BeLike $fileAlphaA;

            $foundTestBookmarks.Item(0).Type | Should -Be Directory;
            $foundTestBookmarks.Item(1).Type | Should -Be File;
            
            $foundTestBookmarks.Item(0).Mode | Should -Be "d--";
            $foundTestBookmarks.Item(1).Mode | Should -Be "-f-";
        }
    }

    Describe "Get-BookmarkExactDescription" {
        $Bookmarks.Clear()

        $folderAlpha = New-FolderInTestDrive "folderAlpha";
        $folderBeta = New-FolderInTestDrive "folderBeta";
        $fileBetaB = New-FileInTestDrive "fileBetaB";

        New-Bookmark "Alpha" -location $folderAlpha;
        New-Bookmark "Beta" -location $folderBeta;
        New-Bookmark "Beta" -location $fileBetaB;
        
        It "does not return the bookmark if the description is not equal" {
            Get-BookmarkExactDescription "Alph" | Should -BeNullOrEmpty;
        }

        It "returns the bookmark if the description is equal" {
            (Get-BookmarkExactDescription "Alpha").Length | Should -Be 1;
        }

        It "returns several bookmarks if several have this exact description" {
            $foundTestBookmarks = Get-BookmarkExactDescription "Beta";

            $foundTestBookmarks.Length | Should -Be 2;

            $foundTestBookmarks.Item(0).description | Should -BeExactly "Beta";
            $foundTestBookmarks.Item(1).description | Should -BeExactly "Beta";

            $foundTestBookmarks.Item(0).location | Should -BeLike $folderBeta;
            $foundTestBookmarks.Item(1).location | Should -BeLike $fileBetaB;

            $foundTestBookmarks.Item(0).Type | Should -Be Directory;
            $foundTestBookmarks.Item(1).Type | Should -Be File;
            
            $foundTestBookmarks.Item(0).Mode | Should -Be "d--";
            $foundTestBookmarks.Item(1).Mode | Should -Be "-f-";
        }
    }
}