$srcPath = "c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly\src"

function Remove-LuaComments {
    param([string]$content)
    
    $lines = $content -split "`n"
    $result = @()
    $i = 0
    
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        $i++
        
        # 检查是否有多行注释开始
        if ($line -match '\-\-\[\[') {
            # 找到多行注释结束
            $commentStart = $i - 1
            $found = $false
            while ($i -lt $lines.Count -and -not $found) {
                if ($lines[$i] -match '\]\]') {
                    $found = $true
                }
                $i++
            }
            # 如果本行既有[[ 又有 ]]，则处理本行
            if ($line -match '\-\-\[\[.*\]\]') {
                $line = $line -replace '\-\-\[\[.*\]\]', ''
                $line = $line -replace '\s+$', ''
                if ($line) {
                    $result += $line
                }
            } elseif ($line -match '\-\-\[\[') {
                # 只有开始，需要等到结束
                $before = $line -replace '\-\-\[\[.*', ''
                $before = $before -replace '\s+$', ''
                if ($before) {
                    $result += $before
                }
            }
        } else {
            # 处理单行注释
            # 先检查是否有--
            if ($line -match '--') {
                # 需要小心处理字符串内的--
                $j = 0
                $inString = $false
                $stringChar = ''
                $outputLine = ''
                
                while ($j -lt $line.Length) {
                    $c = $line[$j]
                    
                    if (($c -eq '"' -or $c -eq "'") -and ($j -eq 0 -or $line[$j-1] -ne '\')) {
                        if (-not $inString) {
                            $inString = $true
                            $stringChar = $c
                            $outputLine += $c
                        } elseif ($c -eq $stringChar) {
                            $inString = $false
                            $outputLine += $c
                        } else {
                            $outputLine += $c
                        }
                    } elseif ($inString) {
                        $outputLine += $c
                    } elseif ($j -lt $line.Length - 1 -and $line[$j] -eq '-' -and $line[$j+1] -eq '-') {
                        # 找到注释，退出循环
                        break
                    } else {
                        $outputLine += $c
                    }
                    $j++
                }
                
                $outputLine = $outputLine -replace '\s+$', ''
                if ($outputLine) {
                    $result += $outputLine
                }
            } else {
                # 无注释，保持不变
                if ($line -ne '' -or ($i -lt $lines.Count -and $lines[$i-1] -ne '')) {
                    $result += $line
                }
            }
        }
    }
    
    return ($result -join "`n")
}

Get-ChildItem -Path $srcPath -Filter "*.lua" -Recurse | ForEach-Object {
    Write-Host "Processing: $($_.FullName)"
    $content = Get-Content -Path $_.FullName -Raw -Encoding UTF8
    $stripped = Remove-LuaComments $content
    Set-Content -Path $_.FullName -Value $stripped -Encoding UTF8 -NoNewline
}

Write-Host "Done!"
