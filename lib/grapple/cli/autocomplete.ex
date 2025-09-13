defmodule Grapple.CLI.Autocomplete do
  @moduledoc """
  Autocomplete functionality for the Grapple CLI shell.
  Provides command suggestions and tab completion.
  """

  @commands [
    "CREATE NODE",
    "CREATE EDGE", 
    "MATCH",
    "TRAVERSE",
    "PATH",
    "VISUALIZE",
    "SHOW GRAPH",
    "FIND NODES",
    "FIND EDGES",
    "JOIN",
    "CLUSTER INFO",
    "NODES",
    "help",
    "quit",
    "exit"
  ]

  @command_patterns %{
    "CREATE NODE" => "{prop: value}",
    "CREATE EDGE" => "(from)-[label]->(to)",
    "MATCH" => "(n)-[r]->(m)",
    "TRAVERSE" => "<node_id> [depth]",
    "PATH" => "<from> <to>",
    "VISUALIZE" => "<node_id> [depth]",
    "SHOW GRAPH" => "",
    "FIND NODES" => "<property> <value>",
    "FIND EDGES" => "<label>",
    "JOIN" => "<node@host>",
    "CLUSTER INFO" => "",
    "NODES" => "",
    "help" => "",
    "quit" => "",
    "exit" => ""
  }

  def get_completions(input) do
    input = String.trim(input)
    
    if String.length(input) == 0 do
      @commands
    else
      @commands
      |> Enum.filter(&String.starts_with?(String.upcase(&1), String.upcase(input)))
      |> case do
        [] -> suggest_similar_commands(input)
        matches -> matches
      end
    end
  end

  def get_command_pattern(command) do
    @command_patterns[command] || ""
  end

  def complete_command(input) do
    completions = get_completions(input)
    
    case completions do
      [] ->
        {:no_match, input, []}
        
      [single_match] ->
        if String.upcase(single_match) == String.upcase(input) do
          {:exact_match, input, get_command_pattern(single_match)}
        else
          {:single_match, single_match, get_command_pattern(single_match)}
        end
        
      multiple_matches ->
        common_prefix = find_common_prefix(multiple_matches, String.upcase(input))
        {:multiple_matches, common_prefix, multiple_matches}
    end
  end

  def suggest_similar_commands(input) do
    input_upper = String.upcase(input)
    
    @commands
    |> Enum.map(fn cmd ->
      {cmd, string_similarity(input_upper, String.upcase(cmd))}
    end)
    |> Enum.filter(fn {_cmd, similarity} -> similarity > 0.3 end)
    |> Enum.sort_by(fn {_cmd, similarity} -> -similarity end)
    |> Enum.take(3)
    |> Enum.map(fn {cmd, _similarity} -> cmd end)
  end

  def format_suggestions(completions) when is_list(completions) do
    case length(completions) do
      0 ->
        "No matching commands found."
        
      1 ->
        command = List.first(completions)
        pattern = get_command_pattern(command)
        if pattern != "" do
          "#{command} #{pattern}"
        else
          command
        end
        
      _ ->
        "Available commands:\n" <>
        (completions
         |> Enum.map(fn cmd ->
           pattern = get_command_pattern(cmd)
           if pattern != "" do
             "  #{cmd} #{pattern}"
           else
             "  #{cmd}"
           end
         end)
         |> Enum.join("\n"))
    end
  end

  def handle_tab_completion(current_input) do
    case complete_command(current_input) do
      {:exact_match, input, pattern} ->
        if pattern != "" do
          IO.puts("\nUsage: #{input} #{pattern}")
          {:completed, input}
        else
          {:completed, input}
        end
        
      {:single_match, completion, pattern} ->
        if pattern != "" do
          IO.puts("\nUsage: #{completion} #{pattern}")
        end
        {:completed, completion}
        
      {:multiple_matches, common_prefix, matches} ->
        IO.puts("\n" <> format_suggestions(matches))
        {:partial, common_prefix}
        
      {:no_match, input, suggestions} ->
        if length(suggestions) > 0 do
          IO.puts("\nDid you mean:")
          IO.puts(format_suggestions(suggestions))
        else
          IO.puts("\nNo matching commands found. Type 'help' for available commands.")
        end
        {:no_completion, input}
    end
  end

  defp find_common_prefix(strings, current_input) do
    strings
    |> Enum.map(&String.upcase/1)
    |> Enum.reduce(fn str, acc ->
      common_prefix_between(acc, str)
    end)
    |> case do
      prefix when byte_size(prefix) > byte_size(current_input) ->
        prefix
      _ ->
        current_input
    end
  end

  defp common_prefix_between(str1, str2) do
    str1
    |> String.graphemes()
    |> Enum.zip(String.graphemes(str2))
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> Enum.map(fn {a, _} -> a end)
    |> Enum.join()
  end

  defp string_similarity(str1, str2) do
    # Simple Jaccard similarity for command suggestions
    set1 = str1 |> String.graphemes() |> MapSet.new()
    set2 = str2 |> String.graphemes() |> MapSet.new()
    
    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()
    
    if union_size == 0 do
      0.0
    else
      intersection_size / union_size
    end
  end

  def validate_command_syntax(command) do
    command_upper = String.upcase(command)
    
    cond do
      String.starts_with?(command_upper, "CREATE NODE") ->
        validate_create_node_syntax(command)
        
      String.starts_with?(command_upper, "CREATE EDGE") ->
        validate_create_edge_syntax(command)
        
      String.starts_with?(command_upper, "TRAVERSE") ->
        validate_traverse_syntax(command)
        
      String.starts_with?(command_upper, "PATH") ->
        validate_path_syntax(command)
        
      String.starts_with?(command_upper, "JOIN") ->
        validate_join_syntax(command)
        
      true ->
        {:valid, command}
    end
  end

  defp validate_create_node_syntax(command) do
    case Regex.run(~r/CREATE NODE\s*(\{.*\})?/i, command) do
      [_full] -> {:valid, command}
      [_full, _props] -> {:valid, command}
      nil -> {:invalid, "CREATE NODE syntax: CREATE NODE {prop: value}"}
    end
  end

  defp validate_create_edge_syntax(command) do
    case Regex.run(~r/CREATE EDGE\s*\([^)]*\)-\[[^\]]*\]->\([^)]*\)/i, command) do
      [_full] -> {:valid, command}
      nil -> {:invalid, "CREATE EDGE syntax: CREATE EDGE (from)-[label]->(to)"}
    end
  end

  defp validate_traverse_syntax(command) do
    case Regex.run(~r/TRAVERSE\s+(\d+)(\s+\d+)?/i, command) do
      [_full, _node] -> {:valid, command}
      [_full, _node, _depth] -> {:valid, command}
      nil -> {:invalid, "TRAVERSE syntax: TRAVERSE <node_id> [depth]"}
    end
  end

  defp validate_path_syntax(command) do
    case Regex.run(~r/PATH\s+(\d+)\s+(\d+)/i, command) do
      [_full, _from, _to] -> {:valid, command}
      nil -> {:invalid, "PATH syntax: PATH <from_node_id> <to_node_id>"}
    end
  end

  defp validate_join_syntax(command) do
    case Regex.run(~r/JOIN\s+(\S+)/i, command) do
      [_full, _node] -> {:valid, command}
      nil -> {:invalid, "JOIN syntax: JOIN <node@host>"}
    end
  end
end