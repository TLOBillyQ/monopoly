param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs
)

$script:forward_target = Join-Path $PSScriptRoot "..\..\tools\ops\deploy.ps1"

& $script:forward_target @RemainingArgs
exit $LASTEXITCODE
