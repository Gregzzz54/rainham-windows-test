param(
    [int]$Port = 8787,
    [string]$Directory = (Join-Path $PSScriptRoot 'public')
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($Directory).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
if (-not (Test-Path (Join-Path $root 'index.html'))) { throw 'Run build.ps1 before starting the preview.' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
    '.js' = 'application/javascript; charset=utf-8'; '.webp' = 'image/webp'
    '.svg' = 'image/svg+xml'; '.txt' = 'text/plain; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'; '.xml' = 'application/xml; charset=utf-8'
}
Write-Host "Preview ready at http://localhost:$Port/"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        try {
            if ($context.Request.HttpMethod -notin @('GET', 'HEAD')) {
                $response.StatusCode = 405
                $response.Headers.Add('Allow', 'GET, HEAD')
                continue
            }
            $relative = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart('/')
            if ($relative.StartsWith('rainham-windows-test/')) { $relative = $relative.Substring('rainham-windows-test/'.Length) }
            $file = [System.IO.Path]::GetFullPath((Join-Path $root $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
            if (-not ($file + [System.IO.Path]::DirectorySeparatorChar).StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $response.StatusCode = 403
                continue
            }
            if (Test-Path $file -PathType Container) { $file = Join-Path $file 'index.html' }
            if (-not (Test-Path $file -PathType Leaf)) {
                $response.StatusCode = 404
                $file = Join-Path $root '404.html'
            }
            $extension = [System.IO.Path]::GetExtension($file)
            $response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $response.ContentLength64 = $bytes.Length
            if ($context.Request.HttpMethod -eq 'GET') { $response.OutputStream.Write($bytes, 0, $bytes.Length) }
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Close()
}
