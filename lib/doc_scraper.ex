defmodule DocScraper do
  def main(args) do
    url = List.first(args) || "https://example.com"
    output_file = args |> List.last() |> Path.expand()
    base_domain = url |> URI.parse() |> Map.get(:host)

    IO.puts "Scraping entire website from #{url}"
    content = scrape_website(url)

    IO.puts "Generating PDF..."
    generate_pdf(content, output_file, base_domain)

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

    content = parse_body(Floki.find(document, "body"))

    links = Floki.find(document, "a")
      |> Floki.attribute("href")
      |> Enum.map(&URI.merge(url, &1))
      |> Enum.map(&to_string/1)

    {content, links}
  end

  defp parse_body(body) do
    {parsed_body, _} = Floki.traverse_and_update(body, [], fn
      {tag, attrs, children}, acc when tag in ["h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "ol", "li"] ->
        updated_children = flatten_and_clean_text(children)
        {{tag, attrs, [updated_children]}, [String.to_atom(tag) | acc]}
      {"a", attrs, children}, acc ->
        updated_children = flatten_and_clean_text(children)
        {{"a", attrs, [updated_children]}, [:a | acc]}
      {tag, _, children}, acc when tag in ["strong", "b", "i", "em", "span", "code"] ->
        {flatten_and_clean_text(children), acc}
      {:comment, _}, acc ->
        {[], acc}  # Ignore comments
      {tag, _, _children}, acc when tag == "script" ->
        {[], acc}  # Remove script tags and their content
      {_tag, _, children}, acc ->
        {flatten_and_clean_text(children), acc}
      text, acc when is_binary(text) ->
        {String.trim(text), acc}
      other, acc ->
        {other, acc}  # Catch-all for any other node types
    end)

    parsed_body
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp flatten_and_clean_text(nodes) do
    {cleaned_nodes, _} = Floki.traverse_and_update(nodes, [], fn
      {_tag, _attrs, children}, acc -> {children, acc}
      {:comment, _}, acc -> {[], acc}  # Ignore comments
      text, acc when is_binary(text) -> {String.trim(text), acc}
      other, acc -> {other, acc}
    end)

    cleaned_nodes
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> String.split()
    |> Enum.join(" ")
  end

  defp generate_pdf(content, output_file, base_domain) do
    toc = generate_table_of_contents(content)

    html_content = Enum.map(content, fn %{url: url, content: page_content} ->
      """
      <section>
        <h2 id="#{url_to_id(url)}"><a href="#{url}">#{url}</a></h2>
        <div class="content">
          #{format_content(page_content)}
        </div>
      </section>
      """
    end)
    |> Enum.join("\n\n")

    full_html = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>#{base_domain}</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
          }
          h1, h2, h3, h4, h5, h6 {
            color: #2c3e50;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
          }
          .toc {
            background-color: #f8f9fa;
            padding: 20px;
            margin-bottom: 30px;
            border-radius: 5px;
          }
          .toc ul {
            list-style-type: none;
            padding-left: 20px;
          }
          .content {
            margin-bottom: 30px;
          }
          pre {
            background-color: #f4f4f4;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
          }
          code {
            font-family: Consolas, Monaco, 'Andale Mono', monospace;
            background-color: #f4f4f4;
            padding: 2px 4px;
            border-radius: 3px;
          }
          ul, ol {
            padding-left: 30px;
          }
          @page {
            @top-right {
              content: "#{base_domain}";
            }
            @bottom-right {
              content: counter(page);
            }
          }
        </style>
      </head>
      <body>
        <h1>#{base_domain}</h1>
        <div class="toc">
          <h2>Table of Contents</h2>
          #{toc}
        </div>
        #{html_content}
      </body>
    </html>
    """

    # case PdfGenerator.generate(full_html, output_path: output_file, shell_params: ["--enable-local-file-access"]) do
    #   {:ok, filename} ->
    #     IO.puts "PDF successfully generated at: #{filename}"
    #   {:error, reason} ->
    #     IO.puts "Error generating PDF: #{inspect(reason)}"
    # end

    html_file = Path.rootname(output_file) <> ".html"
    File.write!(html_file, full_html)

    case System.cmd("wkhtmltopdf", [
      "--enable-local-file-access",
      "--margin-top", "25",
      "--margin-bottom", "25",
      "--margin-left", "25",
      "--margin-right", "25",
      html_file,
      output_file
    ]) do
      {_, 0} ->
        IO.puts "PDF successfully generated at: #{output_file}"
      {error, _} ->
        IO.puts "Error generating PDF: #{error}"
    end
  end

  defp generate_table_of_contents(content) do
    content
    |> Enum.map(fn %{url: url, content: _page_content} ->
      # page_title = extract_title(page_content)
      "<li><a href=\"##{url_to_id(url)}\">#{url}</a></li>"
    end)
    |> Enum.join("\n")
    |> (fn items -> "<ul>#{items}</ul>" end).()
  end

  # defp extract_title([first | _]) do
  #   first
  # end

  defp url_to_id(url) do
    url
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.downcase()
  end

  defp format_content(content) do
    content
    |> Enum.map(fn line ->
      cond do
        String.starts_with?(line, "# ") -> "<h1>#{String.trim_leading(line, "# ")}</h1>"
        String.starts_with?(line, "## ") -> "<h2>#{String.trim_leading(line, "## ")}</h2>"
        String.starts_with?(line, "### ") -> "<h3>#{String.trim_leading(line, "### ")}</h3>"
        String.starts_with?(line, "#### ") -> "<h4>#{String.trim_leading(line, "#### ")}</h4>"
        String.starts_with?(line, "- ") -> "<li>#{String.trim_leading(line, "- ")}</li>"
        true -> "<p>#{line}</p>"
      end
    end)
    |> Enum.join("\n")
  end
end
