defmodule DocScraper do
  def main(args) do
    url = List.first(args) || "https://example.com"
    output_file = args |> List.last() |> Path.expand()

    IO.puts "Scraping entire website from #{url}"
    content = scrape_website(url)

    IO.puts "Generating PDF..."
    generate_pdf(content, output_file)

    IO.puts "PDF generation complete. Check: #{output_file}"
  end

  defp scrape_website(url) do
    {_, content} = crawl(url, MapSet.new([url]), [])
    content
  end

  defp crawl(url, visited, content) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {new_content, links} = parse_content(body, url)
        updated_content = content ++ [%{url: url, content: new_content}]
        new_links = links
          |> Enum.filter(fn link -> String.starts_with?(link, url) end)
          |> Enum.reject(fn link -> MapSet.member?(visited, link) end)

        Enum.reduce(new_links, {visited, updated_content}, fn link, {visited_acc, content_acc} ->
          if MapSet.member?(visited_acc, link) do
            {visited_acc, content_acc}
          else
            IO.puts "Crawling: #{link}"
            crawl(link, MapSet.put(visited_acc, link), content_acc)
          end
        end)
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts "Error: Received status code #{status_code} for #{url}"
        {visited, content}
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Error: #{reason} for #{url}"
        {visited, content}
    end
  end

  defp parse_content(html, url) do
    {:ok, document} = Floki.parse_document(html)

    content = Floki.find(document, "body")
      |> Floki.text()

    links = Floki.find(document, "a")
      |> Floki.attribute("href")
      |> Enum.map(&URI.merge(url, &1))
      |> Enum.map(&to_string/1)

    {content, links}
  end

  defp generate_pdf(content, output_file) do
    html_content = Enum.map(content, fn %{url: url, content: page_content} ->
      """
      <h1>#{url}</h1>
      <hr>
      <pre>#{page_content}</pre>
      <hr>
      """
    end)
    |> Enum.join("\n\n")

    full_html = """
    <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; }
          pre { white-space: pre-wrap; word-wrap: break-word; }
        </style>
      </head>
      <body>
        #{html_content}
      </body>
    </html>
    """

    # case PdfGenerator.generate(full_html, output_path: output_file) do
    #   {:ok, filename} ->
    #     IO.puts "PDF successfully generated at: #{filename}"
    #   {:error, reason} ->
    #     IO.puts "Error generating PDF: #{inspect(reason)}"
    # end

    html_file = Path.rootname(output_file) <> ".html"
    File.write!(html_file, full_html)

    case System.cmd("wkhtmltopdf", [html_file, output_file]) do
      {_, 0} ->
        IO.puts "PDF successfully generated at: #{output_file}"
      {error, _} ->
        IO.puts "Error generating PDF: #{error}"
    end

    # Optionally, remove the temporary HTML file
    File.rm(html_file)
  end
end
