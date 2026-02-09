#!/usr/bin/env python3
"""
Convert Markdown documentation to professional HTML
"""

import re
import os
from pathlib import Path

# HTML template
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - Sponge Documentation</title>
    <link rel="stylesheet" href="{css_path}styles.css">
</head>
<body>
    <header class="header">
        <div class="header-content">
            <div class="logo">
                <div class="logo-icon">S</div>
                <span>Sponge Docs</span>
            </div>
            <nav class="nav">
                <a href="{root_path}index.html">Home</a>
                <a href="{root_path}LAUNCH_CHECKLIST.html">Checklist</a>
                <a href="{root_path}app-store/technical-requirements.html">App Store</a>
                <a href="{root_path}marketing/marketing-strategy.html">Marketing</a>
            </nav>
        </div>
    </header>

    <div class="container">
        <div class="content-card fade-in">
            <div id="toc"></div>
            {content}
        </div>
    </div>

    <footer class="footer">
        <p><a href="{root_path}index.html">← Back to Documentation Home</a></p>
        <p style="margin-top: 0.5rem;">Sponge Launch Documentation • February 2026</p>
    </footer>

    <script src="{js_path}scripts.js"></script>
</body>
</html>
"""

def convert_md_to_html(md_content):
    """Convert markdown to HTML with basic formatting"""
    html = md_content

    # Headers
    html = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)
    html = re.sub(r'^## (.+)$', r'<h2 id="\1">\1</h2>', html, flags=re.MULTILINE)
    html = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
    html = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', html, flags=re.MULTILINE)

    # Make IDs URL-friendly
    def make_id(match):
        text = match.group(1)
        id_text = re.sub(r'[^\w\s-]', '', text.lower()).replace(' ', '-')
        return f'<h2 id="{id_text}">{text}</h2>'
    html = re.sub(r'<h2 id="([^"]+)">([^<]+)</h2>', make_id, html)

    # Code blocks
    html = re.sub(r'```(\w+)?\n(.*?)```', r'<pre><code>\2</code></pre>', html, flags=re.DOTALL)

    # Inline code
    html = re.sub(r'`([^`]+)`', r'<code>\1</code>', html)

    # Bold
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)

    # Italic
    html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)

    # Links
    html = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', html)

    # Unordered lists
    lines = html.split('\n')
    in_list = False
    result = []

    for i, line in enumerate(lines):
        # Checklist items
        if re.match(r'^- \[ \]', line):
            if not in_list:
                result.append('<ul class="checklist">')
                in_list = True
            item = re.sub(r'^- \[ \] (.+)$', r'<li><input type="checkbox" id="item-\1"><label for="item-\1">\1</label></li>', line)
            result.append(item)
        elif re.match(r'^- \[x\]', line):
            if not in_list:
                result.append('<ul class="checklist">')
                in_list = True
            item = re.sub(r'^- \[x\] (.+)$', r'<li><input type="checkbox" id="item-\1" checked><label for="item-\1">\1</label></li>', line)
            result.append(item)
        # Regular list items
        elif re.match(r'^- (.+)$', line):
            if not in_list:
                result.append('<ul>')
                in_list = True
            item = re.sub(r'^- (.+)$', r'<li>\1</li>', line)
            result.append(item)
        # Ordered lists
        elif re.match(r'^\d+\. (.+)$', line):
            if not in_list:
                result.append('<ol>')
                in_list = 'ol'
            item = re.sub(r'^\d+\. (.+)$', r'<li>\1</li>', line)
            result.append(item)
        else:
            if in_list:
                result.append('</ol>' if in_list == 'ol' else '</ul>')
                in_list = False
            result.append(line)

    if in_list:
        result.append('</ol>' if in_list == 'ol' else '</ul>')

    html = '\n'.join(result)

    # Paragraphs
    html = re.sub(r'\n\n+', r'\n</p>\n<p>\n', html)
    html = '<p>' + html + '</p>'

    # Clean up empty paragraphs
    html = re.sub(r'<p>\s*</p>', '', html)
    html = re.sub(r'<p>(\s*<h[1-6])', r'\1', html)
    html = re.sub(r'(</h[1-6]>)\s*</p>', r'\1', html)
    html = re.sub(r'<p>(\s*<pre)', r'\1', html)
    html = re.sub(r'(</pre>)\s*</p>', r'\1', html)
    html = re.sub(r'<p>(\s*<ul)', r'\1', html)
    html = re.sub(r'(</ul>)\s*</p>', r'\1', html)
    html = re.sub(r'<p>(\s*<ol)', r'\1', html)
    html = re.sub(r'(</ol>)\s*</p>', r'\1', html)

    # Status badges
    html = re.sub(r'✅', '<span class="badge badge-success">✅</span>', html)
    html = re.sub(r'❌', '<span class="badge badge-danger">❌</span>', html)
    html = re.sub(r'⚠️', '<span class="badge badge-warning">⚠️</span>', html)
    html = re.sub(r'🔄', '<span class="badge badge-info">🔄</span>', html)

    # Tables
    def convert_table(text):
        lines = [l.strip() for l in text.split('\n') if l.strip()]
        if len(lines) < 2:
            return text

        # Parse header
        headers = [h.strip() for h in lines[0].split('|') if h.strip()]

        # Skip separator line
        # Parse rows
        rows = []
        for line in lines[2:]:
            cells = [c.strip() for c in line.split('|') if c.strip()]
            if cells:
                rows.append(cells)

        # Build HTML table
        table_html = '<table>\n<thead>\n<tr>\n'
        for h in headers:
            table_html += f'<th>{h}</th>\n'
        table_html += '</tr>\n</thead>\n<tbody>\n'

        for row in rows:
            table_html += '<tr>\n'
            for cell in row:
                table_html += f'<td>{cell}</td>\n'
            table_html += '</tr>\n'

        table_html += '</tbody>\n</table>'
        return table_html

    # Find and convert tables
    table_pattern = re.compile(r'\n(\|.+\|\n)+', re.MULTILINE)
    html = table_pattern.sub(lambda m: '\n' + convert_table(m.group(0)) + '\n', html)

    return html

def process_file(md_path, output_base):
    """Process a single markdown file"""
    print(f"Processing: {md_path}")

    # Read markdown
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()

    # Convert to HTML
    html_content = convert_md_to_html(md_content)

    # Extract title from first heading
    title_match = re.search(r'<h1>(.+?)</h1>', html_content)
    title = title_match.group(1) if title_match else Path(md_path).stem

    # Determine output path and relative paths for CSS/JS
    md_path_obj = Path(md_path)
    relative = md_path_obj.relative_to(Path('/Users/danielwait/envclaudecode'))

    # Determine subfolder structure
    if 'submission/app-store' in str(md_path):
        output_path = output_base / 'app-store' / (md_path_obj.stem + '.html')
        css_path = '../'
        js_path = '../'
        root_path = '../'
    elif 'submission/beta-testing' in str(md_path):
        output_path = output_base / 'beta-testing' / (md_path_obj.stem + '.html')
        css_path = '../'
        js_path = '../'
        root_path = '../'
    elif 'submission/marketing' in str(md_path):
        output_path = output_base / 'marketing' / (md_path_obj.stem + '.html')
        css_path = '../'
        js_path = '../'
        root_path = '../'
    elif 'submission/implementation' in str(md_path):
        output_path = output_base / 'implementation' / (md_path_obj.stem + '.html')
        css_path = '../'
        js_path = '../'
        root_path = '../'
    elif 'submission' in str(md_path) and md_path_obj.name == 'README.md':
        output_path = output_base / 'reference' / 'submission-README.html'
        css_path = '../'
        js_path = '../'
        root_path = '../'
    elif 'Sponge/ai' in str(md_path):
        output_path = output_base / 'reference' / (md_path_obj.stem + '.html')
        css_path = '../'
        js_path = '../'
        root_path = '../'
    else:
        # Root level files
        output_path = output_base / (md_path_obj.stem + '.html')
        css_path = ''
        js_path = ''
        root_path = ''

    # Create output directory
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Generate HTML
    html = HTML_TEMPLATE.format(
        title=title,
        content=html_content,
        css_path=css_path,
        js_path=js_path,
        root_path=root_path
    )

    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html)

    print(f"  → Created: {output_path}")

def main():
    base_dir = Path('/Users/danielwait/envclaudecode')
    output_dir = base_dir / 'html-docs'

    # Files to convert
    files = [
        base_dir / 'README.md',
        base_dir / 'CHANGELOG.md',
        base_dir / 'CLAUDE.md',
        base_dir / 'IMPLEMENTATION_SUMMARY.md',
        base_dir / 'LAUNCH_CHECKLIST.md',
        base_dir / 'DELIVERY_REPORT.md',
        base_dir / 'submission' / 'README.md',
        base_dir / 'submission' / 'app-store' / 'technical-requirements.md',
        base_dir / 'submission' / 'app-store' / 'app-store-listing.md',
        base_dir / 'submission' / 'app-store' / 'submission-checklist.md',
        base_dir / 'submission' / 'beta-testing' / 'testflight-setup.md',
        base_dir / 'submission' / 'beta-testing' / 'beta-testing-plan.md',
        base_dir / 'submission' / 'implementation' / 'distribution-readiness-analysis.md',
        base_dir / 'submission' / 'implementation' / 'monetization-options.md',
        base_dir / 'submission' / 'marketing' / 'marketing-strategy.md',
        base_dir / 'Sponge' / 'ai' / 'APP_OVERVIEW.md',
    ]

    print("Converting markdown files to HTML...")
    print("=" * 60)

    for md_file in files:
        if md_file.exists():
            process_file(md_file, output_dir)
        else:
            print(f"Warning: File not found: {md_file}")

    print("=" * 60)
    print("✅ Conversion complete!")
    print(f"\nOpen html-docs/index.html to view the documentation site.")

if __name__ == '__main__':
    main()
