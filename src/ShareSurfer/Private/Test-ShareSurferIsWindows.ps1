function Test-ShareSurferIsWindows {
    [System.Environment]::OSVersion.Platform -eq 'Win32NT'
}
