param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'public')
)

$ErrorActionPreference = 'Stop'
$data = Get-Content (Join-Path $PSScriptRoot 'src\content.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$template = Get-Content (Join-Path $PSScriptRoot 'src\layout.html') -Raw -Encoding UTF8
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = $data.baseUrl.TrimEnd('/') + '/'

function Encode([string]$value) {
    [System.Net.WebUtility]::HtmlEncode($value)
}

function Write-OutputFile([string]$path, [string]$content) {
    $parent = Split-Path $path -Parent
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    [System.IO.File]::WriteAllText($path, $content, $utf8)
}

function Route-Url([string]$route) {
    $base + $route.TrimStart('/')
}

function Render-Cards($cards) {
    if (-not $cards) { return '' }
    $items = foreach ($card in $cards) {
        '<article class="card"><span class="card-number" aria-hidden="true">' +
        (Encode $card.number) + '</span><h3>' + (Encode $card.title) +
        '</h3><p>' + (Encode $card.text) + '</p><a class="text-link" href="' +
        (Encode (Route-Url $card.route)) + '">' + (Encode $card.label) +
        ' <span aria-hidden="true">&rarr;</span></a></article>'
    }
    '<div class="card-grid">' + ($items -join '') + '</div>'
}

function Render-Blocks($blocks) {
    $items = foreach ($block in $blocks) {
        $body = '<section><h2>' + (Encode $block.heading) + '</h2>'
        foreach ($paragraph in $block.paragraphs) {
            $body += '<p>' + (Encode $paragraph) + '</p>'
        }
        if ($block.list) {
            $body += '<ul>' + (($block.list | ForEach-Object { '<li>' + (Encode $_) + '</li>' }) -join '') + '</ul>'
        }
        if ($block.links) {
            $body += '<ul>'
            foreach ($link in $block.links) {
                $body += '<li><a href="' + (Encode $link.url) + '">' + (Encode $link.label) + '</a></li>'
            }
            $body += '</ul>'
        }
        if ($block.table) {
            $body += '<div class="table-scroll" role="region" tabindex="0" aria-label="' + (Encode $block.table.caption) + '"><table><caption>' + (Encode $block.table.caption) + '</caption><thead><tr>'
            foreach ($heading in $block.table.headers) { $body += '<th scope="col">' + (Encode $heading) + '</th>' }
            $body += '</tr></thead><tbody>'
            foreach ($row in $block.table.rows) {
                $body += '<tr>'
                foreach ($cell in $row) { $body += '<td>' + (Encode $cell) + '</td>' }
                $body += '</tr>'
            }
            $body += '</tbody></table></div>'
        }
        $body += Render-Cards $block.cards
        $body + '</section>'
    }
    $items -join ''
}

function Render-Faqs($faqs) {
    if (-not $faqs) { return '' }
    $items = foreach ($faq in $faqs) {
        '<details><summary>' + (Encode $faq.question) + '</summary><p>' + (Encode $faq.answer) + '</p></details>'
    }
    '<section><h2>Frequently asked questions</h2><div class="faq">' + ($items -join '') + '</div></section>'
}

$navItems = @(
    @{ label = 'Windows'; route = 'windows/' },
    @{ label = 'Doors'; route = 'doors/' },
    @{ label = 'Conservatories'; route = 'conservatories/' },
    @{ label = 'Repairs'; route = 'repairs/' },
    @{ label = 'Areas'; route = 'areas/' },
    @{ label = 'Guides'; route = 'guides/' },
    @{ label = 'Gallery'; route = 'gallery/' },
    @{ label = 'Reviews'; route = 'reviews/' },
    @{ label = 'Contact'; route = 'contact/' }
)

$business = [ordered]@{
    '@type' = 'HomeAndConstructionBusiness'
    '@id' = $base + '#business'
    name = $data.business.name
    legalName = $data.business.name
    url = $data.business.officialUrl
    logo = $base + 'assets/logo.svg'
    description = 'Rainham Windows website design preview. Address, contact details, service areas and additional business credentials await confirmation.'
}

$manifest = @()
foreach ($page in $data.pages) {
    $route = [string]$page.route
    $canonical = Route-Url $route
    $depth = @($route.Trim('/').Split('/') | Where-Object { $_ }).Count
    $root = if ($depth -eq 0) { './' } else { '../' * $depth }
    $nav = foreach ($item in $navItems) {
        $current = if ($route -eq $item.route) { ' aria-current="page"' } else { '' }
        '<a href="' + (Encode ($root + $item.route)) + '"' + $current + '>' + (Encode $item.label) + '</a>'
    }
    $graph = @($business)
    $webpage = [ordered]@{
        '@type' = 'WebPage'
        '@id' = $canonical + '#webpage'
        url = $canonical
        name = $page.title
        description = $page.description
        inLanguage = 'en-GB'
        about = @{ '@id' = $base + '#business' }
    }
    $graph += $webpage
    if ($page.kind -eq 'service') {
        $graph += [ordered]@{
            '@type' = 'Service'
            '@id' = $canonical + '#service'
            serviceType = $page.serviceType
            name = $page.h1
            provider = @{ '@id' = $base + '#business' }
            description = $page.intro
            url = $canonical
        }
    }
    $breadcrumb = ''
    if ($route) {
        $crumbs = @(@{ label = 'Home'; route = '' })
        if ($page.parent) { $crumbs += $page.parent }
        $crumbs += @{ label = $page.label; route = $route }
        $crumbItems = @()
        $crumbHtml = @()
        for ($i = 0; $i -lt $crumbs.Count; $i++) {
            $crumb = $crumbs[$i]
            $crumbItems += @{ '@type' = 'ListItem'; position = $i + 1; name = $crumb.label; item = (Route-Url $crumb.route) }
            if ($i -eq $crumbs.Count - 1) {
                $crumbHtml += '<li aria-current="page">' + (Encode $crumb.label) + '</li>'
            } else {
                $crumbHtml += '<li><a href="' + (Encode (Route-Url $crumb.route)) + '">' + (Encode $crumb.label) + '</a></li>'
            }
        }
        $graph += @{ '@type' = 'BreadcrumbList'; '@id' = $canonical + '#breadcrumbs'; itemListElement = $crumbItems }
        $breadcrumb = '<nav aria-label="Breadcrumb"><ol class="breadcrumb">' + ($crumbHtml -join '') + '</ol></nav>'
    }
    if ($page.faqs) {
        $questions = foreach ($faq in $page.faqs) {
            @{ '@type' = 'Question'; name = $faq.question; acceptedAnswer = @{ '@type' = 'Answer'; text = $faq.answer } }
        }
        $graph += @{ '@type' = 'FAQPage'; '@id' = $canonical + '#faq'; mainEntity = @($questions) }
    }
    $schema = @{ '@context' = 'https://schema.org'; '@graph' = $graph } | ConvertTo-Json -Depth 30 -Compress
    $schema = $schema.Replace('<', '\u003c')

    $notice = if ($page.notice) { '<div class="confirmation"><p>' + (Encode $page.notice) + '</p></div>' } else { '' }
    if ($page.kind -eq 'home') {
        $content = '<section class="hero"><div class="wrap hero-grid"><div><span class="eyebrow">A thoughtful new view of home</span>' +
            '<h1>Double glazing.<br>A <em>better view.</em></h1><p class="lead">' + (Encode $page.intro) + '</p>' +
            '<div class="actions"><a class="button" href="#quote">Plan your project &nearr;</a><a class="text-link" href="windows/">Explore windows &rarr;</a></div>' +
            $notice + '</div><figure class="hero-visual"><img src="assets/anthracite-grey-upvc-windows.webp" width="1080" height="606" alt="Anthracite-grey uPVC casement and bay windows with a glazed porch from the original Rainham Windows portfolio" fetchpriority="high">' +
            '<span class="hero-badge">Real project photographs.<small>Original Rainham Windows portfolio</small></span><figcaption>Anthracite-grey uPVC &middot; Town: {{CONFIRM: anthracite project town}}</figcaption></figure></div></section>' +
            '<div class="highlights"><div class="wrap"><span>Replacement windows</span><span>Doors &amp; bi-fold doors</span><span>Conservatories &amp; porches</span><span>Business details under review</span></div></div>' +
            '<div class="section"><div class="wrap">' + (Render-Blocks $page.blocks) + '</div></div>' +
            '<section class="section"><div class="wrap feature-grid"><figure><img src="assets/rosewood-upvc-windows.webp" width="960" height="960" alt="Rosewood-finish uPVC casement and bay windows on a brick property from the original Rainham Windows portfolio" loading="lazy"><figcaption>Rosewood uPVC &middot; Town: {{CONFIRM: rosewood project town}}</figcaption></figure><div class="feature-copy"><span class="eyebrow">Details that make a difference</span><h2>Picture the finish.<br><em>Plan the details.</em></h2><p>The original portfolio shows anthracite-grey and rosewood uPVC installations. Explore those examples, then ask which products and finishes are currently available.</p><a class="button" href="gallery/">Explore the project gallery &nearr;</a></div></div></section>' +
            '<section class="section tint"><div class="wrap"><span class="eyebrow">A clear starting point</span><h2>Your project, <em>step by step.</em></h2><p>Prepare your requirements, compare the options, and request a written quotation once contact details are verified.</p><div class="steps"><article class="step"><strong>01</strong><h3>Tell us about your home</h3><p>Identify the windows or doors you want to change, your property postcode and any access constraints.</p></article><article class="step"><strong>02</strong><h3>Compare the right details</h3><p>Look at style, material, glazing specification and installation scope, rather than price alone.</p></article><article class="step"><strong>03</strong><h3>Request a clear quotation</h3><p>Ask for product details, inclusions and exclusions in writing. Prices and lead times require confirmation.</p></article></div></div></section>' +
            '<div class="section"><div class="wrap article">' + (Render-Faqs $page.faqs) + '</div></div>'
    } else {
        $updated = if ($page.kind -eq 'guide') { '<p class="small">Updated ' + (Encode $data.updated) + ' &middot; General buying guidance, not a quotation.</p>' } else { '' }
        $content = '<section class="intro"><div class="wrap">' + $breadcrumb + '<span class="eyebrow">' + (Encode $page.eyebrow) +
            '</span><h1>' + (Encode $page.h1) + '</h1><p class="lead">' + (Encode $page.intro) + '</p>' + $updated + $notice + '</div></section>'
        $body = Render-Blocks $page.blocks
        if ($page.kind -eq 'gallery') {
            $body += '<section><h2>Original window-installation photographs</h2><p>These two photographs come from the original Rainham Windows portfolio and are reused with the user-confirmed permission.</p><div class="gallery-grid">'
            foreach ($project in $data.projects) {
                $body += '<figure class="project"><img src="' + (Encode ($root + 'assets/' + $project.file)) + '" width="' +
                    $project.width + '" height="' + $project.height + '" loading="lazy" alt="' + (Encode $project.alt) + '"><figcaption><h3>' +
                    (Encode $project.title) + '</h3><p>' + (Encode $project.description) + '</p><p class="small">Town: ' +
                    (Encode $project.town) + '<br>Product: ' + (Encode $project.product) + '<br>Colour / finish: ' +
                    (Encode $project.finish) + '</p></figcaption></figure>'
            }
            $body += '</div></section>'
        }
        if ($page.kind -eq 'contact') {
            $body += '<section class="nap"><h2>How can I contact Rainham Windows?</h2><p>Contact details need business confirmation before enquiries can be sent.</p><p><strong>' +
                (Encode $data.business.name) + '</strong><br>' + (Encode $data.business.address) + '</p><p>Phone: ' +
                (Encode $data.business.phone) + '<br>Email: ' + (Encode $data.business.email) + '</p><p>Opening hours: {{CONFIRM: opening hours}}</p></section>'
        }
        $body += Render-Faqs $page.faqs
        if ($page.related) {
            $body += '<section><h2>Useful next steps</h2><p>Explore relevant product guidance and local coverage drafts before preparing your enquiry.</p><ul>'
            foreach ($link in $page.related) { $body += '<li><a href="' + (Encode (Route-Url $link.route)) + '">' + (Encode $link.label) + '</a></li>' }
            $body += '</ul></section>'
        }
        $content += '<div class="section"><div class="wrap content-layout"><article class="article">' + $body +
            '</article><aside class="sidebar"><h2>Make an informed choice</h2><p>Check products, coverage and business credentials before choosing an installer.</p><a href="' +
            (Encode ($root + 'guides/double-glazing-cost/')) + '">What affects double-glazing cost?</a><a href="' +
            (Encode ($root + 'gallery/')) + '">See original project photos</a><a href="#quote">Prepare a quote enquiry</a><a href="' +
            (Encode ($root + 'contact/')) + '">View confirmation checklist</a></aside></div></div>'
    }
    $replacements = @{
        '%%TITLE%%' = (Encode $page.title); '%%DESCRIPTION%%' = (Encode $page.description)
        '%%CANONICAL%%' = (Encode $canonical); '%%BASE%%' = (Encode $base); '%%ROOT%%' = $root
        '%%SCHEMA%%' = $schema; '%%NAV%%' = ($nav -join ''); '%%CONTENT%%' = $content
        '%%NAME%%' = (Encode $data.business.name); '%%ADDRESS%%' = (Encode $data.business.address)
        '%%PHONE%%' = (Encode $data.business.phone); '%%EMAIL%%' = (Encode $data.business.email)
    }
    $html = $template
    foreach ($key in $replacements.Keys) { $html = $html.Replace($key, $replacements[$key]) }
    $directory = if ($route) { Join-Path $OutputDirectory $route.Trim('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar) } else { $OutputDirectory }
    Write-OutputFile (Join-Path $directory 'index.html') $html
    $manifest += @{ route = $route; kind = $page.kind; title = $page.title; canonical = $canonical }
}

$assets = Join-Path $OutputDirectory 'assets'
[System.IO.Directory]::CreateDirectory($assets) | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'src\site.css') (Join-Path $assets 'site.css') -Force
Copy-Item (Join-Path $PSScriptRoot 'src\site.js') (Join-Path $assets 'site.js') -Force
Copy-Item (Join-Path $PSScriptRoot 'src\logo.svg') (Join-Path $assets 'logo.svg') -Force
foreach ($project in $data.projects) { Copy-Item (Join-Path $PSScriptRoot ('images\' + $project.file)) (Join-Path $assets $project.file) -Force }
Write-OutputFile (Join-Path $OutputDirectory '.nojekyll') ''
Write-OutputFile (Join-Path $OutputDirectory 'robots.txt') "User-agent: *`nDisallow: /`n"
$sitemapItems = $manifest | ForEach-Object { '<url><loc>' + (Encode $_.canonical) + '</loc></url>' }
Write-OutputFile (Join-Path $OutputDirectory 'sitemap.xml') ('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + ($sitemapItems -join '') + '</urlset>')
$notFound = '<!doctype html><html lang="en-GB"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Page not found | Rainham Windows</title><h1>Page not found</h1><p>This address is not part of the preview.</p><a href="' + (Encode $base) + '">Return to the homepage</a></html>'
Write-OutputFile (Join-Path $OutputDirectory '404.html') $notFound
Write-OutputFile (Join-Path $OutputDirectory 'build-manifest.json') ($manifest | ConvertTo-Json -Depth 10)
$markers = foreach ($entry in $manifest) {
    $directory = if ($entry.route) { Join-Path $OutputDirectory $entry.route.Trim('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar) } else { $OutputDirectory }
    $html = Get-Content (Join-Path $directory 'index.html') -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($html, '\{\{CONFIRM:[^}]+\}\}')) {
        [System.Net.WebUtility]::HtmlDecode($match.Value)
    }
}
Write-OutputFile (Join-Path $OutputDirectory 'confirmation-checklist.txt') (($markers | Sort-Object -Unique) -join "`n")
Write-Host "Built $($data.pages.Count) static pages in $OutputDirectory"
