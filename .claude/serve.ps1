# Minimal static-file HTTP server for previewing DTK_Mapa_OM.html
# Uses System.Net.HttpListener so no extra runtime install is needed.
param(
  [int]$Port = 8000,
  [string]$Root = (Split-Path -Parent $PSScriptRoot),
  [string]$DefaultDocument = 'DTK_Mapa_OM.html'
)

$ErrorActionPreference = 'Stop'

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.htm'  = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.mjs'  = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.svg'  = 'image/svg+xml'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif'  = 'image/gif'
  '.webp' = 'image/webp'
  '.ico'  = 'image/x-icon'
  '.woff' = 'font/woff'
  '.woff2'= 'font/woff2'
  '.ttf'  = 'font/ttf'
  '.otf'  = 'font/otf'
  '.txt'  = 'text/plain; charset=utf-8'
  '.map'  = 'application/json'
  '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
  $listener.Start()
} catch {
  Write-Output "Failed to bind $prefix : $($_.Exception.Message)"
  exit 1
}

Write-Output "Serving '$Root' on $prefix (default: $DefaultDocument)"
Write-Output "Press Ctrl+C to stop."

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    try {
      $rel = [uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/','\')
      if ([string]::IsNullOrEmpty($rel)) { $rel = $DefaultDocument }

      # Block path traversal
      $full = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))
      $rootFull = [System.IO.Path]::GetFullPath($Root)
      if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $res.StatusCode = 403
        $body = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
        $res.OutputStream.Write($body, 0, $body.Length)
      }
      elseif (Test-Path -LiteralPath $full -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
        $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $bytes = [System.IO.File]::ReadAllBytes($full)
        $res.ContentType = $ct
        $res.ContentLength64 = $bytes.Length
        $res.Headers.Add('Cache-Control', 'no-store')
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        Write-Output "200 $($req.HttpMethod) /$rel ($($bytes.Length) bytes, $ct)"
      } else {
        $res.StatusCode = 404
        $body = [System.Text.Encoding]::UTF8.GetBytes("404: /$rel not found")
        $res.ContentType = 'text/plain; charset=utf-8'
        $res.ContentLength64 = $body.Length
        $res.OutputStream.Write($body, 0, $body.Length)
        Write-Output "404 $($req.HttpMethod) /$rel"
      }
    } catch {
      try {
        $res.StatusCode = 500
        $body = [System.Text.Encoding]::UTF8.GetBytes("500: $($_.Exception.Message)")
        $res.OutputStream.Write($body, 0, $body.Length)
      } catch {}
      Write-Output "500 $($req.HttpMethod) $($req.Url.AbsolutePath) - $($_.Exception.Message)"
    } finally {
      try { $res.Close() } catch {}
    }
  }
} finally {
  try { $listener.Stop() } catch {}
  try { $listener.Close() } catch {}
}
