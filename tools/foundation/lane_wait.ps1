param([string]$ListPath, [double]$Timeout)
$ErrorActionPreference = 'Stop'
# 父进程阻塞等待全部 lane 完成(#107):对每个 status 完成文件用 .NET
# FileSystemWatcher.WaitForChanged 带超时阻塞,不轮询自旋、不用 sleep 命令、不依赖网络。
# 单次等待以 1s 为上限只为兜住「建 watcher 之前文件已原子发布」的竞态,复查后继续阻塞。
$deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
foreach ($path in [IO.File]::ReadAllLines($ListPath, [Text.Encoding]::UTF8)) {
  if ($path -eq '') { continue }
  $watcher = New-Object IO.FileSystemWatcher ([IO.Path]::GetDirectoryName($path)), ([IO.Path]::GetFileName($path))
  try {
    while (-not [IO.File]::Exists($path)) {
      $left = ($deadline - [DateTime]::UtcNow).TotalMilliseconds
      if ($left -le 0) { exit 124 }
      [void]$watcher.WaitForChanged([IO.WatcherChangeTypes]::All, [int][Math]::Min($left, 1000))
    }
  } finally { $watcher.Dispose() }
}
exit 0
