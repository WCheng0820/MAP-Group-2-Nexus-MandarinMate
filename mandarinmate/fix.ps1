
$content = Get-Content lib/screens/main_screen.dart -Raw

# Remove Profile Tab from BottomNavigationBar
$content = $content -replace "(?s)\s*NavigationDestination\(\s*icon: Icon\(Icons.person_rounded\),\s*selectedIcon: Icon\(Icons.person_rounded,\s*color: _StudentColors.red\),\s*label: 'Profile',\s*\),", ""

# Remove _ProfileTab from pages array
$content = $content -replace "const _ProfileTab\(\),", ""

# Delete _ProfileTab class
$content = $content -replace "(?s)class _ProfileTab.*?Future<void> _logout.*?}\s*```\s*}\s*}\s*}", ""

Set-Content -Path lib/screens/main_screen.dart -Value $content

