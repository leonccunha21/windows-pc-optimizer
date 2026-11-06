@{
    # Retention is a safety floor: the loader rejects any value below 7 days.
    MinimumAgeDays = 7

    # Allowlisted browser caches. Folders are relative to the user profile and
    # must not contain '..' or absolute paths.
    Browsers = @(
        @{ Id='chrome'; Name='Google Chrome'; Folder='Google\Chrome\User Data'; Process='chrome' }
        @{ Id='edge'; Name='Microsoft Edge'; Folder='Microsoft\Edge\User Data'; Process='msedge' }
        @{ Id='brave'; Name='Brave'; Folder='BraveSoftware\Brave-Browser\User Data'; Process='brave' }
    )
    BrowserCacheFolders = @('Cache\Cache_Data', 'Code Cache', 'GPUCache')

    # Files with these extensions are never cleanup candidates.
    ProtectedExtensions = @(
        '.ps1', '.psm1', '.bat', '.cmd', '.py', '.js', '.ts', '.tsx', '.jsx',
        '.cs', '.cpp', '.h', '.java', '.rs', '.go', '.sln', '.csproj',
        '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.pdf',
        '.jpg', '.jpeg', '.png', '.heic', '.mp4', '.zip', '.7z', '.rar',
        '.sqlite', '.db', '.pst', '.ost'
    )

    # Any path segment matching one of these names is protected.
    ProtectedFolders = @('.git', 'Epic Games', 'EpicGames', 'Fortnite', 'FortniteGame')

    # A directory containing any of these files is treated as a project.
    ProjectMarkers = @('.git', 'package.json', 'pyproject.toml', 'Cargo.toml', 'go.mod', '.optimizer-protect')
}
