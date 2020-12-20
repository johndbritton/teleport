<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>{{ site.github.project_title }}</title>
    <link>{{ site.url }}{{ site.baseurl }}{{ page.url }}</link>
    <description>{{ site.github.project_tagline }}</description>
    <language>en</language>
    {% for release in site.github.releases %}
      {% unless release.draft %}
        {% unless release.prerelease and page.stable %}
          {% assign body_parts = release.body | split:'<!--' %}
          {% assign description = body_parts | first %}
          {% if body_parts.size == 2 %}
            {% assign signature = body_parts | last | replace:'-->','' %}
          {% else %}
            {% assign signature = nil %}
          {% endif %}
          <item>
            <title>{{ release.name }}</title>
            <description><![CDATA[{{ description | markdownify }}]]></description>
            <pubDate>{{ release.published_at | date_to_rfc822 }}</pubDate>
            {% for asset in release.assets limit:1 %}
              {% assign version = release.tag_name | remove_first:'v' %}
              <enclosure
                  url="{{ asset.browser_download_url }}"
                  sparkle:version="{{ version }}"
                  {% if signature %}
                    sparkle:edSignature="{{ signature }}"
                  {% endif %}
                  length="{{ asset.size }}"
                  type="application/octet-stream" />
            {% endfor %}
          </item>
        {% endunless %}
      {% endunless %}
    {% endfor %}
  </channel>
</rss>
