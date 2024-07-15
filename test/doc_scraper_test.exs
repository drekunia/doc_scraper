defmodule DocScraperTest do
  use ExUnit.Case
  doctest DocScraper

  test "greets the world" do
    assert DocScraper.hello() == :world
  end
end
