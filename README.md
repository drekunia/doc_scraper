# DocScraper | Web Documentation Scraper and PDF Generator

## Introduction

This Elixir-based CLI application scrapes an entire technical documentation website and exports the content into a single PDF file. It's designed to help developers and technical writers collect and compile documentation from web-based sources into a portable format for offline use or archival purposes.

## Features

- Crawls and scrapes an entire website starting from a given URL
- Extracts text content from web pages
- Generates a single PDF file containing all scraped content
- Provides a simple command-line interface

## Prerequisites

Before you begin, ensure you have the following installed:

- Elixir (version 1.11 or later)
- Erlang (version 22 or later)
- wkhtmltopdf (for PDF generation)

## Setup

1. Clone this repository:

```bash
git clone https://github.com/drekunia/doc_scraper.git
cd doc_scraper
```

2. Install dependencies:

```bash
mix deps.get
```

3. Compile the project:

```bash
mix compile
```

4. Build the escript:

```bash
mix escript.build
```

## Usage

Run the scraper using the following command:

```bash
./doc_scraper [URL] [OUTPUT_FILE]
```

For example:

```bash
./doc_scraper https://docs.example.com/ example_docs.pdf
```

If no arguments are provided, it will default to scraping "<https://example.com>" and output to "output.pdf" in the current directory.

## Potential Improvements

1. Implement rate limiting to be more respectful to the scraped websites.
2. Add support for `robots.txt` to ensure ethical scraping.
3. Improve error handling and logging.
4. Add support for JavaScript-rendered content using a headless browser.
5. Implement a progress bar or more detailed progress reporting.
6. Add options for selective scraping (e.g., specific sections of a website).
7. Improve PDF formatting and add a table of contents.
8. Add support for authentication to scrape protected content.
9. Implement multithreading for faster scraping of large websites.
10. Add unit and integration tests.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

Please ensure you have permission to scrape and reproduce content from websites. This tool is intended for personal use or use with websites you own or have explicit permission to scrape. Always review and comply with a website's terms of service and `robots.txt` file.

## Troubleshooting

If you encounter issues with PDF generation:

1. Ensure `wkhtmltopdf` is properly installed and accessible in your system's PATH.
2. Check that you have write permissions in the directory where you're trying to save the PDF.
3. If you're still having trouble, try generating an HTML file first, then manually convert it to PDF using `wkhtmltopdf`.

## Contact

If you have any questions or feedback, please open an issue in this repository.
