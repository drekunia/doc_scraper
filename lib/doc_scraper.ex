defmodule DocScraper do
  def main(args) do
    url = List.first(args) || "https://example.com/docs"
    output_file = List.last(args) || "output.pdf"

    IO.puts("Scraping documentation from #{url}")
    content = scrape_documentation(url)

    IO.puts("Generating PDF...")
    generate_pdf(content, output_file)

    IO.puts("PDF generated: #{output_file}")
  end

  defp scrape_documentation(url) do
    {_, content} = crawl(url, MapSet.new([url]), [])
    content
  end

  defp crawl(url, visited, content) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {new_content, links} = parse_content(body, url)
        updated_content = content ++ [new_content]

        new_links =
          links
          |> Enum.filter(fn link -> String.starts_with?(link, url) end)
          |> Enum.reject(fn link -> MapSet.member?(visited, link) end)

        Enum.reduce(new_links, {visited, updated_content}, fn link, {visited_acc, content_acc} ->
          if MapSet.member?(visited_acc, link) do
            {visited_acc, content_acc}
          else
            crawl(link, MapSet.put(visited_acc, link), content_acc)
          end
        end)

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Error: Received status code #{status_code} for #{url}")
        {visited, content}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Error: #{reason} for #{url}")
        {visited, content}
    end
  end

  defp parse_content(html, url) do
    {:ok, document} = Floki.parse_document(html)

    content =
      Floki.find(document, "p, h1, h2, h3, h4, h5, h6")
      |> Floki.text()

    links =
      Floki.find(document, "a")
      |> Floki.attribute("href")
      |> Enum.map(&URI.merge(url, &1))
      |> Enum.map(&to_string/1)

    {content, links}
  end

  defp generate_pdf(content, output_file) do
    PdfGenerator.generate(Enum.join(content, "\n\n"), output_path: output_file)
  end
end
