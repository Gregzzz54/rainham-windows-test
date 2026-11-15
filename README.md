# Rainham Windows concept website

A 24-page, responsive static design preview. All page copy and FAQs are generated into HTML; JavaScript only handles the menu and local enquiry preparation.

## Preview

Run in PowerShell from this directory:

```powershell
.\build.ps1
.\test.ps1
.\preview.ps1
```

Open http://localhost:8787/. Stop the preview with Ctrl+C. Alternatively, open `public/index.html` after building; absolute content links point to the deployed preview.

PowerShell 5.1 or PowerShell 7 is sufficient. There are no npm packages or runtime framework dependencies.

Edit `src/content.json` for content, `src/layout.html` for shared markup, and `src/site.css` / `src/site.js` for presentation and interactions. `public/` is generated and ignored by Git.

## Images and search content

The user confirmed ownership of, or permission to reuse, the original website photographs before publication. WebP versions are used on every generated page; the source JPEGs remain for provenance. Both photographs are hosted with the site, and system fonts avoid external font requests.

- `images/anthracite-grey-upvc-windows.jpg`: [original project photograph](https://cdn.website-editor.net/e467c9242eb74bc19de6b4874f8d3bab/dms3rep/multi/background/IMG_6615.JPG), cropped to remove the black border.
- `images/rosewood-upvc-windows.jpg`: [original project photograph](https://le-cdn.website-editor.net/e467c9242eb74bc19de6b4874f8d3bab/dms3rep/multi/opt/18AC51D8-A463-49EB-8919-96203DA1735F-960w.jpg).

The site includes six service pages, seven genuinely distinct area drafts, three guides, gallery, reviews, contact, legal notice and navigation hubs. Repairs and additional product ranges are explicitly unconfirmed, not advertised as available.

SEO/GEO foundations include bounded titles and descriptions, canonical/social tags, answer-first HTML, business and confirmed-service schema, matching FAQ schema, breadcrumbs, internal links, descriptive project captions and an XML sitemap. Unknown address, phone, coordinates, hours and profile URLs are omitted from schema instead of inserting placeholders as facts. No reviews, prices or credentials are invented.

The proposed Essex/Rainham base and towns from the supplied brief remain visibly unconfirmed. Page titles are draft keyword targets, not verification that the business operates in those locations. Additional keyword-map products must be confirmed before service pages are created. Guide facts link to independent Energy Saving Trust and Planning Portal guidance.

The build generates `public/confirmation-checklist.txt`, listing every outstanding marker. See `.github/copilot-instructions.md` for the persistent content rules.

The enquiry form is deliberately not a live lead form: it prepares a message in memory, does not send a request, does not use browser storage and reports that nothing was sent. It needs verified contacts and an approved secure backend before launch.

The preview remains `noindex`: this is a foundation for an approved production launch, not a claim that the test website will rank.

## GitHub Pages

`.github/workflows/pages.yml` builds and validates the site on pushes to `main`, then deploys `public/` using GitHub Pages Actions. The repository Pages build type must be `workflow`, not a legacy branch-root deployment.

The preview URL is https://gregzzz54.github.io/rainham-windows-test/.

This is a public preview, not the official business website. `noindex` and `robots.txt` discourage indexing but do not restrict public access.

## Before launch

- Get approval for the design and confirm every business, service, and contact detail.
- Replace preview notices and `noindex` only after production approval. Update the generated crawler policy to allow the approved search/AI bots and reference the sitemap.
- Change `baseUrl` in `src/content.json` to the approved production URL. Verify canonical, social-image and sitemap URLs after building.
- Check structured business details and local service-area claims against the business's verified information.
- Connect any quote or contact form to a secure, monitored service before offering one.
- Verify `/gallery/`, `/contact/` and `/legal-notice/` and the host's slash redirects. Do not replace existing URLs with JavaScript redirects.
- Run Lighthouse on the deployed build; mobile 90+ is a target, not an unmeasured performance claim.
