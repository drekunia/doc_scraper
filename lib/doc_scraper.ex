defmodule DocScraper do
  def main(args) do
    url = List.first(args) || "https://example.com"
    output_file = List.last(args) || "output.pdf"

    IO.puts "Scraping entire website from #{url}"
    content = scrape_website(url)

    IO.puts "Generating PDF..."
    generate_pdf(content, output_file)

    absolute_path = Path.expand(output_file)
    IO.puts "PDF generated: #{absolute_path}"
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
    pdf_content = Enum.map(content, fn %{url: url, content: page_content} ->
      """
      #{String.duplicate("=", 80)}
      #{url}
      #{String.duplicate("=", 80)}

      #{page_content}

      #{String.duplicate("-", 80)}
      """
    end)
    |> Enum.join("\n\n")

    PdfGenerator.generate(pdf_content, output_path: output_file)
  end
end
