param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'public')
)

$ErrorActionPreference = 'Stop'
$data = Get-Content (Join-Path $PSScriptRoot 'src\content.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$base = $data.baseUrl.TrimEnd('/') + '/'
$failures = New-Object System.Collections.Generic.List[string]
$counts = @()

function Check([bool]$condition, [string]$message) {
    if (-not $condition) { $failures.Add($message) }
}

function Check-SchemaValues($value, [string]$path) {
    if ($value -is [string]) {
        Check (-not [string]::IsNullOrWhiteSpace($value)) "$path has an empty schema value"
        Check (-not $value.Contains('{{CONFIRM:')) "$path has an unconfirmed schema value"
    } elseif ($null -eq $value) {
        $failures.Add("$path has a null schema value")
    } elseif ($value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $value.PSObject.Properties) { Check-SchemaValues $property.Value "$path.$($property.Name)" }
    } elseif ($value -is [System.Collections.IEnumerable]) {
        foreach ($item in $value) { Check-SchemaValues $item $path }
    }
}

$knownRoutes = @{}
foreach ($entry in $data.pages) { $knownRoutes[$base + $entry.route] = $true }
Check ($data.pages.Count -eq $knownRoutes.Count) 'Duplicate page routes'
$locationParagraphs = @{}
foreach ($entry in $data.pages) {
    $route = $entry.route
    $directory = if ($route) { Join-Path $OutputDirectory $route.Trim('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar) } else { $OutputDirectory }
    $html = Get-Content (Join-Path $directory 'index.html') -Raw -Encoding UTF8
    Check (([regex]::Matches($html, '<h1(?:\s|>)')).Count -eq 1) "$route must have exactly one H1"
    Check ($html.Contains('lang="en-GB"')) "$route has no British English language declaration"
    Check ($entry.title.Length -le 60) "$route title exceeds 60 characters"
    Check ($entry.description.Length -le 155) "$route description exceeds 155 characters"
    Check ($html.Contains('rel="canonical" href="' + $base + $route + '"')) "$route has an incorrect canonical"
    foreach ($meta in @('og:title', 'og:description', 'og:image', 'og:url', 'twitter:card', 'twitter:title')) {
        Check ($html.Contains('"' + $meta + '"')) "$route is missing $meta"
    }
    Check ($html.Contains('content="noindex, nofollow"')) "$route must remain noindex"
    Check ($html.Contains('rel="icon"')) "$route must include a favicon"
    Check ($html.Contains('id="quote-form"')) "$route has no quotation form"
    Check ($html.Contains('does not send')) "$route does not disclose the preview form behaviour"
    Check ($html.Contains([System.Net.WebUtility]::HtmlEncode($data.business.phone))) "$route has inconsistent phone information"
    Check ($html.Contains([System.Net.WebUtility]::HtmlEncode($data.business.address))) "$route has inconsistent address information"
    Check ($html.Contains([System.Net.WebUtility]::HtmlEncode($data.business.name))) "$route has inconsistent business name"
    Check (-not ($html -match '%%[A-Z]+%%')) "$route has unresolved template tokens"

    $prose = @($entry.intro)
    foreach ($block in $entry.blocks) { $prose += $block.paragraphs }
    foreach ($faq in $entry.faqs) { $prose += $faq.answer }
    $wordCount = ([regex]::Matches(($prose -join ' '), '\b[\p{L}\p{N}]+(?:-[\p{L}\p{N}]+)*\b')).Count
    $counts += "$route [$($entry.kind)] $wordCount prose words"
    if ($entry.kind -eq 'service') {
        Check ($wordCount -ge 400) "$route needs at least 400 useful prose words, got $wordCount"
        Check (@($entry.related | Where-Object { $_.route -like 'areas/*' }).Count -ge 3) "$route needs three area links"
        Check (@($entry.related | Where-Object { $_.route -like 'guides/*' }).Count -ge 1) "$route needs a guide link"
        Check (@($entry.related | Where-Object { $_.route -notlike 'areas/*' -and $_.route -notlike 'guides/*' }).Count -ge 1) "$route needs a related-service link"
    }
    if ($entry.kind -eq 'area') {
        Check ($wordCount -ge 300) "$route needs at least 300 useful prose words, got $wordCount"
        Check (@($entry.related | Where-Object { $_.route -like 'areas/*' }).Count -ge 2) "$route needs two neighbouring area links"
        Check ($entry.notice -like '*CONFIRM:*') "$route must clearly disclose unconfirmed coverage"
        foreach ($block in $entry.blocks) {
            foreach ($paragraph in $block.paragraphs) {
                if ($locationParagraphs.ContainsKey($paragraph)) {
                    $failures.Add("$route duplicates a paragraph from $($locationParagraphs[$paragraph])")
                }
                $locationParagraphs[$paragraph] = $route
            }
        }
    }
    foreach ($match in [regex]::Matches($html, '<a\b[^>]*href="([^"]+)"')) {
        $href = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        $uri = New-Object System.Uri([System.Uri]($base + $route), $href)
        if ($uri.AbsoluteUri.StartsWith($base)) {
            $path = $uri.GetLeftPart([System.UriPartial]::Path)
            Check ($knownRoutes.ContainsKey($path)) "$route links to unknown page $href"
            if ($uri.Fragment) {
                Check ($html.Contains('id="' + $uri.Fragment.TrimStart('#') + '"')) "$route has a broken fragment $href"
            }
        }
    }
    foreach ($match in [regex]::Matches($html, '<img\b[^>]*>')) {
        $tag = $match.Value
        Check ($tag -match 'alt="[^"]+"') "$route has missing image alt text"
        Check ($tag -match 'width="\d+"' -and $tag -match 'height="\d+"') "$route has missing image dimensions"
        Check ($tag -match '\.webp"') "$route uses a non-WebP content image"
        $src = [regex]::Match($tag, 'src="([^"]+)"').Groups[1].Value
        $uri = New-Object System.Uri([System.Uri]($base + $route), $src)
        $relative = $uri.AbsolutePath.Substring(([System.Uri]$base).AbsolutePath.Length)
        Check (Test-Path (Join-Path $OutputDirectory $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))) "$route has a missing image $src"
    }
    $schemaText = [regex]::Match($html, '<script type="application/ld\+json">([\s\S]*?)</script>').Groups[1].Value
    $schema = $schemaText | ConvertFrom-Json
    Check-SchemaValues $schema $route
    $types = @($schema.'@graph' | ForEach-Object { $_.'@type' })
    Check ($types -contains 'HomeAndConstructionBusiness') "$route has no business schema"
    Check ($types -notcontains 'AggregateRating' -and $types -notcontains 'Review') "$route must not invent review schema"
    if ($route) { Check ($types -contains 'BreadcrumbList') "$route has no breadcrumb schema" }
    if ($entry.kind -eq 'service') { Check ($types -contains 'Service') "$route has no Service schema" }
    if ($entry.kind -ne 'service') { Check ($types -notcontains 'Service') "$route has an unapproved service claim in schema" }
    if ($entry.faqs) {
        $faqSchema = $schema.'@graph' | Where-Object { $_.'@type' -eq 'FAQPage' }
        Check (@($faqSchema.mainEntity).Count -eq @($entry.faqs).Count) "$route has mismatched FAQ counts"
        foreach ($faq in $entry.faqs) {
            $question = @($faqSchema.mainEntity | Where-Object { $_.name -eq $faq.question })
            Check ($question.Count -eq 1 -and $question[0].acceptedAnswer.text -eq $faq.answer) "$route has a mismatched FAQ answer"
            Check ($html.Contains('<summary>' + [System.Net.WebUtility]::HtmlEncode($faq.question) + '</summary>')) "$route FAQ question is not visible"
            Check ($html.Contains('<p>' + [System.Net.WebUtility]::HtmlEncode($faq.answer) + '</p>')) "$route FAQ answer is not visible"
        }
    }
}
Check ((Get-Content (Join-Path $OutputDirectory 'robots.txt') -Raw).Contains('Disallow: /')) 'Preview robots must discourage crawling'
[xml]$sitemap = Get-Content (Join-Path $OutputDirectory 'sitemap.xml') -Raw
Check (@($sitemap.urlset.url).Count -eq $data.pages.Count) 'Sitemap must contain every generated page'
foreach ($url in $sitemap.urlset.url) { Check ($knownRoutes.ContainsKey([string]$url.loc)) "Sitemap has unknown URL $($url.loc)" }
foreach ($legacy in @('gallery/', 'contact/', 'legal-notice/')) { Check ($knownRoutes.ContainsKey($base + $legacy)) "Missing preserved URL $legacy" }
if ($failures.Count) { throw ($failures -join "`n") }
Write-Host "PASS: $($data.pages.Count) pages; prose thresholds, links, metadata, schema, image attributes and preview safeguards."
$counts | ForEach-Object { Write-Host $_ }
