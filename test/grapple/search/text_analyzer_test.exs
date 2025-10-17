defmodule Grapple.Search.TextAnalyzerTest do
  use ExUnit.Case, async: true
  alias Grapple.Search.TextAnalyzer

  describe "analyze/2" do
    test "tokenizes and normalizes simple text" do
      result = TextAnalyzer.analyze("Hello World")
      assert result == ["hello", "world"]
    end

    test "handles punctuation removal" do
      result = TextAnalyzer.analyze("Hello, World! How are you?")
      assert result == ["hello", "world", "how", "are", "you"]
    end

    test "handles multiple spaces and delimiters" do
      result = TextAnalyzer.analyze("hello   world-test_value")
      assert result == ["hello", "world", "test", "value"]
    end

    test "respects min_length option" do
      result = TextAnalyzer.analyze("a bb ccc dddd", min_length: 3)
      assert result == ["ccc", "dddd"]
    end

    test "disables lowercase when requested" do
      result = TextAnalyzer.analyze("Hello World", lowercase: false)
      assert result == ["Hello", "World"]
    end

    test "removes stop words when requested" do
      result = TextAnalyzer.analyze("the quick brown fox", stop_words: true)
      assert result == ["quick", "brown", "fox"]
    end

    test "applies stemming when requested" do
      result = TextAnalyzer.analyze("running jumped happily", stemming: true)
      assert result == ["runn", "jump", "happi"]
    end

    test "handles empty strings" do
      result = TextAnalyzer.analyze("")
      assert result == []
    end

    test "handles strings with only punctuation" do
      result = TextAnalyzer.analyze("!@#$%^&*()")
      assert result == []
    end
  end

  describe "tokenize/1" do
    test "splits on whitespace" do
      result = TextAnalyzer.tokenize("hello world test")
      assert result == ["hello", "world", "test"]
    end

    test "splits on hyphens and underscores" do
      result = TextAnalyzer.tokenize("hello-world_test")
      assert result == ["hello", "world", "test"]
    end

    test "handles multiple delimiters" do
      result = TextAnalyzer.tokenize("hello, world; test: value")
      assert result == ["hello", "world", "test", "value"]
    end
  end

  describe "stem/1" do
    test "removes ing suffix" do
      assert TextAnalyzer.stem("running") == "runn"
      assert TextAnalyzer.stem("jumping") == "jump"
    end

    test "removes ed suffix" do
      assert TextAnalyzer.stem("jumped") == "jump"
      assert TextAnalyzer.stem("walked") == "walk"
    end

    test "removes s suffix" do
      assert TextAnalyzer.stem("cats") == "cat"
      assert TextAnalyzer.stem("dogs") == "dog"
    end

    test "removes ly suffix" do
      assert TextAnalyzer.stem("quickly") == "quick"
      assert TextAnalyzer.stem("happily") == "happi"
    end

    test "preserves short words" do
      assert TextAnalyzer.stem("is") == "is"
      assert TextAnalyzer.stem("go") == "go"
    end

    test "handles words without known suffixes" do
      assert TextAnalyzer.stem("hello") == "hello"
      assert TextAnalyzer.stem("world") == "world"
    end
  end

  describe "stop_word?/1" do
    test "identifies common stop words" do
      assert TextAnalyzer.stop_word?("the")
      assert TextAnalyzer.stop_word?("and")
      assert TextAnalyzer.stop_word?("or")
      assert TextAnalyzer.stop_word?("is")
    end

    test "handles case insensitive matching" do
      assert TextAnalyzer.stop_word?("THE")
      assert TextAnalyzer.stop_word?("And")
      assert TextAnalyzer.stop_word?("OR")
    end

    test "returns false for non-stop words" do
      refute TextAnalyzer.stop_word?("hello")
      refute TextAnalyzer.stop_word?("world")
      refute TextAnalyzer.stop_word?("graph")
    end
  end

  describe "levenshtein_distance/2" do
    test "calculates distance for identical strings" do
      assert TextAnalyzer.levenshtein_distance("hello", "hello") == 0
    end

    test "calculates distance for single character difference" do
      assert TextAnalyzer.levenshtein_distance("hello", "hallo") == 1
      assert TextAnalyzer.levenshtein_distance("cat", "bat") == 1
    end

    test "calculates distance for insertions" do
      assert TextAnalyzer.levenshtein_distance("cat", "cats") == 1
      assert TextAnalyzer.levenshtein_distance("hello", "hellos") == 1
    end

    test "calculates distance for deletions" do
      assert TextAnalyzer.levenshtein_distance("cats", "cat") == 1
      assert TextAnalyzer.levenshtein_distance("hello", "hell") == 1
    end

    test "calculates distance for multiple changes" do
      assert TextAnalyzer.levenshtein_distance("kitten", "sitting") == 3
      assert TextAnalyzer.levenshtein_distance("saturday", "sunday") == 3
    end

    test "handles empty strings" do
      assert TextAnalyzer.levenshtein_distance("", "hello") == 5
      assert TextAnalyzer.levenshtein_distance("hello", "") == 5
      assert TextAnalyzer.levenshtein_distance("", "") == 0
    end
  end
end
