defmodule Grapple.Search.TextAnalyzer do
  @moduledoc """
  Text analysis utilities for full-text search.
  Provides tokenization, stemming, and text normalization capabilities.
  """

  @doc """
  Analyzes text and returns a list of normalized tokens.

  ## Options

    * `:lowercase` - Convert tokens to lowercase (default: true)
    * `:remove_punctuation` - Remove punctuation from tokens (default: true)
    * `:min_length` - Minimum token length to include (default: 2)
    * `:stemming` - Apply basic stemming (default: false)
    * `:stop_words` - Remove common stop words (default: false)

  ## Examples

      iex> Grapple.Search.TextAnalyzer.analyze("Hello World!")
      ["hello", "world"]

      iex> Grapple.Search.TextAnalyzer.analyze("The quick brown fox", stop_words: true)
      ["quick", "brown", "fox"]
  """
  def analyze(text, opts \\ []) when is_binary(text) do
    opts = normalize_options(opts)

    text
    |> tokenize()
    |> apply_lowercase(opts[:lowercase])
    |> apply_punctuation_removal(opts[:remove_punctuation])
    |> apply_min_length_filter(opts[:min_length])
    |> apply_stop_words_filter(opts[:stop_words])
    |> apply_stemming(opts[:stemming])
  end

  @doc """
  Tokenizes text into words based on whitespace and common delimiters.
  """
  def tokenize(text) when is_binary(text) do
    # Split on whitespace, hyphens, underscores, and common punctuation
    text
    |> String.split(~r/[\s\-_,;:\.!\?\(\)\[\]\{\}]+/, trim: true)
  end

  @doc """
  Applies basic stemming to reduce words to their root form.
  This is a simple implementation for English words.
  """
  def stem(word) when is_binary(word) do
    word
    |> remove_suffix("ing")
    |> remove_suffix("ed")
    |> remove_suffix("s")
    |> remove_suffix("es")
    |> remove_suffix("ly")
    |> remove_suffix("er")
    |> remove_suffix("est")
  end

  @doc """
  Checks if a word is a common stop word.
  """
  def stop_word?(word) when is_binary(word) do
    word_lower = String.downcase(word)
    MapSet.member?(stop_words_set(), word_lower)
  end

  @doc """
  Calculates Levenshtein distance between two strings for fuzzy matching.
  """
  def levenshtein_distance(string1, string2) do
    calculate_levenshtein(
      String.graphemes(string1),
      String.graphemes(string2)
    )
  end

  # Private functions

  defp normalize_options(opts) do
    defaults = [
      lowercase: true,
      remove_punctuation: true,
      min_length: 2,
      stemming: false,
      stop_words: false
    ]

    Keyword.merge(defaults, opts)
  end

  defp apply_lowercase(tokens, true), do: Enum.map(tokens, &String.downcase/1)
  defp apply_lowercase(tokens, false), do: tokens

  defp apply_punctuation_removal(tokens, true) do
    Enum.map(tokens, fn token ->
      String.replace(token, ~r/[^\w]/, "")
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp apply_punctuation_removal(tokens, false), do: tokens

  defp apply_min_length_filter(tokens, min_length) do
    Enum.filter(tokens, fn token -> String.length(token) >= min_length end)
  end

  defp apply_stop_words_filter(tokens, false), do: tokens

  defp apply_stop_words_filter(tokens, true) do
    Enum.reject(tokens, &stop_word?/1)
  end

  defp apply_stemming(tokens, false), do: tokens
  defp apply_stemming(tokens, true), do: Enum.map(tokens, &stem/1)

  defp remove_suffix(word, suffix) do
    word_length = String.length(word)
    suffix_length = String.length(suffix)

    # Ensure the resulting word would be at least 3 characters
    # and the word actually ends with the suffix
    if String.ends_with?(word, suffix) and word_length > suffix_length and
         word_length - suffix_length >= 3 do
      String.slice(word, 0, word_length - suffix_length)
    else
      word
    end
  end

  defp stop_words_set do
    MapSet.new([
      "a",
      "an",
      "and",
      "are",
      "as",
      "at",
      "be",
      "but",
      "by",
      "for",
      "if",
      "in",
      "into",
      "is",
      "it",
      "no",
      "not",
      "of",
      "on",
      "or",
      "such",
      "that",
      "the",
      "their",
      "then",
      "there",
      "these",
      "they",
      "this",
      "to",
      "was",
      "will",
      "with"
    ])
  end

  # Levenshtein distance calculation using dynamic programming
  defp calculate_levenshtein([], string2), do: length(string2)
  defp calculate_levenshtein(string1, []), do: length(string1)

  defp calculate_levenshtein(string1, string2) do
    len1 = length(string1)
    len2 = length(string2)

    # Initialize first row
    initial_row = Map.new(0..len2, fn j -> {j, j} end)
    initial_matrix = %{0 => initial_row}

    # Fill the matrix
    matrix =
      Enum.reduce(1..len1, initial_matrix, fn i, acc_matrix ->
        prev_row = Map.get(acc_matrix, i - 1)

        row =
          Enum.reduce(0..len2, %{}, fn j, acc_row ->
            value =
              cond do
                j == 0 ->
                  i

                true ->
                  char1 = Enum.at(string1, i - 1)
                  char2 = Enum.at(string2, j - 1)

                  cost = if char1 == char2, do: 0, else: 1

                  deletion = Map.get(prev_row, j, 999_999) + 1
                  insertion = Map.get(acc_row, j - 1, 999_999) + 1
                  substitution = Map.get(prev_row, j - 1, 999_999) + cost

                  min(deletion, min(insertion, substitution))
              end

            Map.put(acc_row, j, value)
          end)

        Map.put(acc_matrix, i, row)
      end)

    matrix
    |> Map.get(len1)
    |> Map.get(len2)
  end
end
