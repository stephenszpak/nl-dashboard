defmodule DashboardGenWeb.SeoController do
  use DashboardGenWeb, :controller

  def index(conn, _params) do
    base_url = url(~p"/") |> String.trim_trailing("/")
    canonical = url(~p"/seo")

    ld = %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "url" => base_url,
      "name" => "DashboardGen",
      "description" =>
        "AI-powered analytics dashboard for wealth and asset management: insights, sentiment, and competitive monitoring.",
      "publisher" => %{"@type" => "Organization", "name" => "DashboardGen"}
    }

    assigns = [
      page_title: "AI Analytics Dashboard for Wealth & Asset Management | DashboardGen",
      meta_description:
        "Track market insights, sentiment, competitor activity, and conversations in one AI-powered analytics dashboard.",
      canonical_url: canonical,
      og_title: "DashboardGen — AI Analytics for Wealth & Asset Management",
      og_description:
        "Turn noise into insight: sentiment trends, competitor intelligence, and automated reporting.",
      og_url: canonical,
      ld_json: Jason.encode!(ld)
    ]

    render(conn, DashboardGenWeb.SeoHTML, :index, assigns)
  end

  def sitemap(conn, _params) do
    today = Date.utc_today() |> Date.to_iso8601()
    urls = [
      url(~p"/seo"),
      url(~p"/register")
    ]

    entries =
      Enum.map(urls, fn loc ->
        """
        <url>
          <loc>#{loc}</loc>
          <lastmod>#{today}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.8</priority>
        </url>
        """
      end)
      |> Enum.join("\n")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{entries}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end
end
