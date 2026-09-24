param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

Set-Location (Join-Path $PSScriptRoot "chatbox")
flutter run @FlutterArgs
