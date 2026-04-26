#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESOURCE_DIR="$ROOT_DIR/swift/Sources/ObsidianClipper/Resources"
OUT_FILE="$RESOURCE_DIR/obsidian-clipper-extractor.js"
TMP_DIR="$ROOT_DIR/swift/.defuddle-resource-build"
ENTRY_FILE="$TMP_DIR/obsidian-clipper-swift-entry.ts"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if [[ "${OBSIDIAN_CLIPPER_SKIP_NPM_INSTALL:-0}" != "1" ]]; then
  if [[ -f package-lock.json ]]; then
    npm ci
  else
    npm install
  fi
fi

cat > "$ENTRY_FILE" <<'EOF'
import Defuddle from 'defuddle';
import { createMarkdownContent } from 'defuddle/full';

function metaTags(doc: Document) {
  return Array.from(doc.querySelectorAll('meta')).map((meta) => ({
    name: meta.getAttribute('name'),
    property: meta.getAttribute('property'),
    content: meta.getAttribute('content')
  })).filter((meta) => meta.content);
}

function metaValue(tags: any[], key: string, kind: 'name' | 'property') {
  const match = tags.find((tag) => (tag[kind] || '').toLowerCase() === key.toLowerCase());
  return match ? match.content : null;
}

function absoluteURL(value: string | null) {
  if (!value) return null;
  try {
    return new URL(value, document.baseURI || document.URL).href;
  } catch {
    return value;
  }
}

function blockFromElement(element: Element, index: number) {
  const tag = element.tagName.toLowerCase();
  const id = 'block-' + index;
  const text = (element.textContent || '').trim();
  if (!text && tag !== 'img') return null;
  if (/^h[1-6]$/.test(tag)) {
    return { id, kind: 'heading', level: Number(tag.slice(1)), text, html: (element as HTMLElement).outerHTML, items: [] };
  }
  if (tag === 'p') return { id, kind: 'paragraph', text, html: (element as HTMLElement).outerHTML, items: [] };
  if (tag === 'blockquote') return { id, kind: 'quote', text, html: (element as HTMLElement).outerHTML, items: [] };
  if (tag === 'pre') {
    const code = element.querySelector('code') || element;
    const className = code.getAttribute('class') || '';
    const language = className.split(/\s+/).find((item) => item.startsWith('language-') || item.startsWith('lang-'));
    return {
      id,
      kind: 'code',
      text: (code.textContent || '').trim(),
      html: (element as HTMLElement).outerHTML,
      items: [],
      language: language ? language.replace(/^language-/, '').replace(/^lang-/, '') : null
    };
  }
  if (tag === 'ul' || tag === 'ol') {
    const items = Array.from(element.querySelectorAll(':scope > li')).map((item) => (item.textContent || '').trim()).filter(Boolean);
    return { id, kind: 'list', text: items.join('\n'), html: (element as HTMLElement).outerHTML, items, ordered: tag === 'ol' };
  }
  if (tag === 'img') {
    const src = element.getAttribute('src');
    if (!src) return null;
    const url = absoluteURL(src);
    return { id, kind: 'image', text: element.getAttribute('alt') || src, html: (element as HTMLElement).outerHTML, items: [], url, alt: element.getAttribute('alt') };
  }
  if (tag === 'table') return { id, kind: 'table', text, html: (element as HTMLElement).outerHTML, items: [] };
  return null;
}

function blocksFromHTML(html: string, maxBlockCount: number) {
  const template = document.createElement('template');
  template.innerHTML = html || '';
  const elements = Array.from(template.content.querySelectorAll('h1,h2,h3,h4,h5,h6,p,pre,blockquote,ul,ol,img,table'));
  const blocks: any[] = [];
  for (const element of elements) {
    const block = blockFromElement(element, blocks.length + 1);
    if (!block) continue;
    blocks.push(block);
    if (blocks.length >= maxBlockCount) break;
  }
  if (blocks.length === 0) {
    const text = (template.content.textContent || '').replace(/\s+/g, ' ').trim();
    if (text) blocks.push({ id: 'block-1', kind: 'paragraph', text, html, items: [] });
  }
  return blocks;
}

function selectionHTML() {
  const selection = window.getSelection && window.getSelection();
  if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return null;
  const container = document.createElement('div');
  for (let index = 0; index < selection.rangeCount; index++) {
    container.appendChild(selection.getRangeAt(index).cloneContents());
  }
  return container.innerHTML;
}

(window as any).__ObsidianClipperSwift = {
  extractCurrentPage(options: any = {}) {
    const tags = metaTags(document);
    const defuddle = new Defuddle(document, { url: document.URL });
    const result = defuddle.parse();
    const contentHTML = result.content || '';
    const markdown = createMarkdownContent(contentHTML, document.URL);
    const blocks = blocksFromHTML(contentHTML, options.maxBlockCount || 400);
    return {
      url: document.URL || window.location.href,
      baseURL: document.baseURI || null,
      title: result.title || document.title || metaValue(tags, 'og:title', 'property'),
      author: result.author || metaValue(tags, 'author', 'name'),
      description: result.description || metaValue(tags, 'description', 'name') || metaValue(tags, 'og:description', 'property'),
      site: result.site || metaValue(tags, 'og:site_name', 'property'),
      published: result.published || metaValue(tags, 'article:published_time', 'property') || metaValue(tags, 'date', 'name'),
      language: result.language || document.documentElement.getAttribute('lang'),
      contentHTML,
      markdown,
      fullHTML: options.includeFullHTML ? document.documentElement.outerHTML : null,
      selectedHTML: options.includeSelection === false ? null : selectionHTML(),
      wordCount: result.wordCount || 0,
      imageURL: absoluteURL(result.image || metaValue(tags, 'og:image', 'property')),
      faviconURL: absoluteURL(result.favicon || null),
      schemaOrgJSON: result.schemaOrgData ? JSON.stringify(result.schemaOrgData) : null,
      metaTags: result.metaTags || tags,
      blocks,
      capturedAt: new Date().toISOString(),
      diagnostics: {
        engine: 'defuddle-wkwebview',
        inputHTMLCharacters: document.documentElement ? document.documentElement.outerHTML.length : 0,
        contentHTMLCharacters: contentHTML.length,
        markdownCharacters: markdown.length,
        blockCount: blocks.length,
        truncated: false,
        warnings: []
      }
    };
  }
};
EOF

npx esbuild "$ENTRY_FILE" \
  --bundle \
  --platform=browser \
  --format=iife \
  --target=es2020 \
  --banner:js="/* Bundled Defuddle bridge for ObsidianClipper Swift. Includes Defuddle (MIT). */" \
  --outfile="$OUT_FILE" \
  --log-level=warning

echo "Updated $OUT_FILE"
