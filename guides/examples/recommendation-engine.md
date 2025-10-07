# Building a Recommendation Engine with Grapple

This guide demonstrates how to build a product recommendation system using Grapple's graph database capabilities.

## Overview

We'll build a recommendation engine that:
- Tracks user purchases and ratings
- Finds similar users based on purchase history
- Recommends products based on collaborative filtering
- Handles real-time recommendations efficiently

## Data Model

Our graph will contain:
- **User nodes**: Represent customers
- **Product nodes**: Represent items for sale
- **Purchased edges**: User → Product (with rating, timestamp)
- **Similar edges**: User → User (with similarity score)

## Setup

```elixir
# Start Grapple
{:ok, _} = Application.ensure_all_started(:grapple)

# Import helper functions
alias Grapple, as: G
```

## Step 1: Creating the Data

### Create Users

```elixir
defmodule RecommendationEngine do
  alias Grapple

  def create_sample_data do
    # Create users
    {:ok, alice} = Grapple.create_node(%{
      type: "user",
      name: "Alice",
      age_group: "25-34",
      location: "San Francisco"
    })

    {:ok, bob} = Grapple.create_node(%{
      type: "user",
      name: "Bob",
      age_group: "25-34",
      location: "San Francisco"
    })

    {:ok, carol} = Grapple.create_node(%{
      type: "user",
      name: "Carol",
      age_group: "35-44",
      location: "New York"
    })

    {:ok, david} = Grapple.create_node(%{
      type: "user",
      name: "David",
      age_group: "25-34",
      location: "Seattle"
    })

    # Create products
    {:ok, laptop} = Grapple.create_node(%{
      type: "product",
      name: "Laptop Pro 15",
      category: "Electronics",
      price: 1299.99
    })

    {:ok, mouse} = Grapple.create_node(%{
      type: "product",
      name: "Wireless Mouse",
      category: "Electronics",
      price: 29.99
    })

    {:ok, keyboard} = Grapple.create_node(%{
      type: "product",
      name: "Mechanical Keyboard",
      category: "Electronics",
      price: 89.99
    })

    {:ok, headphones} = Grapple.create_node(%{
      type: "product",
      name: "Noise Cancelling Headphones",
      category: "Electronics",
      price: 199.99
    })

    {:ok, backpack} = Grapple.create_node(%{
      type: "product",
      name: "Laptop Backpack",
      category: "Accessories",
      price: 49.99
    })

    # Create purchase relationships with ratings
    Grapple.create_edge(alice, laptop, "purchased", %{
      rating: 5,
      timestamp: ~U[2024-01-15 10:30:00Z]
    })

    Grapple.create_edge(alice, mouse, "purchased", %{
      rating: 4,
      timestamp: ~U[2024-01-16 14:20:00Z]
    })

    Grapple.create_edge(alice, keyboard, "purchased", %{
      rating: 5,
      timestamp: ~U[2024-01-20 09:15:00Z]
    })

    Grapple.create_edge(bob, laptop, "purchased", %{
      rating: 5,
      timestamp: ~U[2024-01-10 11:00:00Z]
    })

    Grapple.create_edge(bob, keyboard, "purchased", %{
      rating: 4,
      timestamp: ~U[2024-01-12 16:30:00Z]
    })

    Grapple.create_edge(bob, headphones, "purchased", %{
      rating: 5,
      timestamp: ~U[2024-01-25 13:45:00Z]
    })

    Grapple.create_edge(carol, headphones, "purchased", %{
      rating: 4,
      timestamp: ~U[2024-01-18 10:00:00Z]
    })

    Grapple.create_edge(carol, backpack, "purchased", %{
      rating: 5,
      timestamp: ~U[2024-01-22 15:30:00Z]
    })

    Grapple.create_edge(david, laptop, "purchased", %{
      rating: 4,
      timestamp: ~U[2024-01-14 12:00:00Z]
    })

    Grapple.create_edge(david, mouse, "purchased", %{
      rating: 3,
      timestamp: ~U[2024-01-16 09:30:00Z]
    })

    {:ok, %{
      users: [alice, bob, carol, david],
      products: [laptop, mouse, keyboard, headphones, backpack]
    }}
  end
end
```

## Step 2: Finding Similar Users

```elixir
defmodule RecommendationEngine do
  # ... previous code ...

  @doc """
  Calculate similarity between two users based on common purchases.
  Uses Jaccard similarity coefficient.
  """
  def calculate_user_similarity(user1_id, user2_id) do
    # Get products purchased by each user
    {:ok, user1_products} = get_user_purchases(user1_id)
    {:ok, user2_products} = get_user_purchases(user2_id)

    # Calculate Jaccard similarity
    intersection = MapSet.intersection(user1_products, user2_products)
    union = MapSet.union(user1_products, user2_products)

    if MapSet.size(union) == 0 do
      0.0
    else
      MapSet.size(intersection) / MapSet.size(union)
    end
  end

  @doc """
  Get all products purchased by a user.
  """
  def get_user_purchases(user_id) do
    {:ok, neighbors} = Grapple.traverse(user_id, :out, 1)

    products =
      neighbors
      |> Enum.filter(fn node -> node.properties.type == "product" end)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:ok, products}
  end

  @doc """
  Find users similar to the given user.
  Returns list of {user_id, similarity_score} tuples.
  """
  def find_similar_users(user_id, min_similarity \\ 0.1) do
    # Get all users
    {:ok, all_users} = Grapple.find_nodes_by_property(:type, "user")

    all_users
    |> Enum.filter(&(&1.id != user_id))
    |> Enum.map(fn user ->
      similarity = calculate_user_similarity(user_id, user.id)
      {user, similarity}
    end)
    |> Enum.filter(fn {_user, sim} -> sim >= min_similarity end)
    |> Enum.sort_by(fn {_user, sim} -> sim end, :desc)
  end
end
```

## Step 3: Generating Recommendations

```elixir
defmodule RecommendationEngine do
  # ... previous code ...

  @doc """
  Recommend products for a user based on collaborative filtering.
  """
  def recommend_products(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    min_similarity = Keyword.get(opts, :min_similarity, 0.1)

    # Get user's purchase history
    {:ok, user_purchases} = get_user_purchases(user_id)

    # Find similar users
    similar_users = find_similar_users(user_id, min_similarity)

    # Get products purchased by similar users
    recommendations =
      similar_users
      |> Enum.flat_map(fn {similar_user, similarity} ->
        {:ok, their_purchases} = get_user_purchases(similar_user.id)

        their_purchases
        |> MapSet.difference(user_purchases)  # Exclude already purchased
        |> MapSet.to_list()
        |> Enum.map(fn product_id ->
          {product_id, similarity}
        end)
      end)
      |> aggregate_scores()
      |> Enum.take(limit)
      |> Enum.map(fn {product_id, score} ->
        {:ok, product} = Grapple.get_node(product_id)
        {product, score}
      end)

    {:ok, recommendations}
  end

  @doc """
  Aggregate recommendation scores for products.
  """
  defp aggregate_scores(product_scores) do
    product_scores
    |> Enum.group_by(fn {product_id, _score} -> product_id end)
    |> Enum.map(fn {product_id, scores} ->
      total_score =
        scores
        |> Enum.map(fn {_id, score} -> score end)
        |> Enum.sum()

      {product_id, total_score}
    end)
    |> Enum.sort_by(fn {_id, score} -> score end, :desc)
  end
end
```

## Step 4: Rating-Based Recommendations

```elixir
defmodule RecommendationEngine do
  # ... previous code ...

  @doc """
  Get weighted recommendations considering purchase ratings.
  """
  def recommend_with_ratings(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Get similar users with their similarity scores
    similar_users = find_similar_users(user_id, 0.1)

    # Get user's existing purchases
    {:ok, user_purchases} = get_user_purchases(user_id)

    # Calculate weighted scores
    recommendations =
      similar_users
      |> Enum.flat_map(fn {similar_user, similarity} ->
        # Get their purchases with ratings
        {:ok, edges} = Grapple.find_edges_by_label("purchased")

        edges
        |> Enum.filter(fn edge ->
          edge.from == similar_user.id and
          not MapSet.member?(user_purchases, edge.to)
        end)
        |> Enum.map(fn edge ->
          rating = edge.properties.rating || 3
          score = similarity * rating
          {edge.to, score}
        end)
      end)
      |> aggregate_scores()
      |> Enum.take(limit)
      |> Enum.map(fn {product_id, score} ->
        {:ok, product} = Grapple.get_node(product_id)
        {product, Float.round(score, 2)}
      end)

    {:ok, recommendations}
  end
end
```

## Step 5: Category-Based Recommendations

```elixir
defmodule RecommendationEngine do
  # ... previous code ...

  @doc """
  Recommend products from categories the user likes.
  """
  def recommend_by_category(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    # Get user's purchase history
    {:ok, user_neighbors} = Grapple.traverse(user_id, :out, 1)

    # Find favorite categories
    favorite_categories =
      user_neighbors
      |> Enum.filter(&(&1.properties.type == "product"))
      |> Enum.frequencies_by(& &1.properties.category)
      |> Enum.sort_by(fn {_cat, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {cat, _count} -> cat end)

    # Get user's existing purchases
    {:ok, user_purchases} = get_user_purchases(user_id)

    # Find products in favorite categories
    {:ok, all_products} = Grapple.find_nodes_by_property(:type, "product")

    recommendations =
      all_products
      |> Enum.filter(fn product ->
        product.properties.category in favorite_categories and
        not MapSet.member?(user_purchases, product.id)
      end)
      |> Enum.take(limit)

    {:ok, recommendations}
  end
end
```

## Usage Example

```elixir
# Create sample data
{:ok, data} = RecommendationEngine.create_sample_data()
[alice, bob, carol, david] = data.users

# Find similar users to Alice
similar_to_alice = RecommendationEngine.find_similar_users(alice)
IO.inspect(similar_to_alice, label: "Users similar to Alice")

# Get basic recommendations for Alice
{:ok, recommendations} = RecommendationEngine.recommend_products(alice)
IO.puts("\nRecommendations for Alice:")
Enum.each(recommendations, fn {product, score} ->
  IO.puts("  #{product.properties.name} (score: #{Float.round(score, 2)})")
end)

# Get rating-weighted recommendations
{:ok, weighted_recs} = RecommendationEngine.recommend_with_ratings(alice)
IO.puts("\nWeighted Recommendations for Alice:")
Enum.each(weighted_recs, fn {product, score} ->
  IO.puts("  #{product.properties.name} (score: #{score})")
end)

# Get category-based recommendations
{:ok, category_recs} = RecommendationEngine.recommend_by_category(alice)
IO.puts("\nCategory-Based Recommendations for Alice:")
Enum.each(category_recs, fn product ->
  IO.puts("  #{product.properties.name} (#{product.properties.category})")
end)
```

## Performance Optimization

For large-scale recommendation systems, consider:

### 1. Pre-compute Similar Users

```elixir
defmodule RecommendationEngine do
  @doc """
  Pre-compute and cache user similarities.
  Run periodically (e.g., nightly batch job).
  """
  def precompute_similarities do
    {:ok, all_users} = Grapple.find_nodes_by_property(:type, "user")

    for user1 <- all_users,
        user2 <- all_users,
        user1.id < user2.id do
      similarity = calculate_user_similarity(user1.id, user2.id)

      if similarity > 0.1 do
        # Store similarity as an edge
        Grapple.create_edge(user1.id, user2.id, "similar", %{
          score: similarity,
          computed_at: DateTime.utc_now()
        })
      end
    end
  end
end
```

### 2. Use Performance Monitoring

```elixir
# Profile recommendation performance
{:ok, session} = Grapple.Performance.Profiler.start_session()

RecommendationEngine.recommend_products(alice)

{:ok, report} = Grapple.Performance.Profiler.generate_report(session)
IO.inspect(report.duration_ms, label: "Recommendation time (ms)")
```

### 3. Implement Caching

```elixir
defmodule RecommendationEngine.Cache do
  use GenServer

  # Cache recommendations for 1 hour
  @cache_ttl 3600

  def get_cached_recommendations(user_id) do
    case :ets.lookup(:recommendation_cache, user_id) do
      [{^user_id, recommendations, timestamp}] ->
        if System.system_time(:second) - timestamp < @cache_ttl do
          {:ok, recommendations}
        else
          :miss
        end

      [] ->
        :miss
    end
  end

  def cache_recommendations(user_id, recommendations) do
    :ets.insert(:recommendation_cache, {
      user_id,
      recommendations,
      System.system_time(:second)
    })
  end
end
```

## Advanced Features

### Real-time Recommendations

Update recommendations immediately after purchases:

```elixir
defmodule RecommendationEngine do
  @doc """
  Record a purchase and invalidate caches.
  """
  def record_purchase(user_id, product_id, rating) do
    # Create purchase edge
    {:ok, _edge} = Grapple.create_edge(user_id, product_id, "purchased", %{
      rating: rating,
      timestamp: DateTime.utc_now()
    })

    # Invalidate user's recommendation cache
    :ets.delete(:recommendation_cache, user_id)

    # Optionally: Update similar user recommendations
    similar_users = find_similar_users(user_id)
    Enum.each(similar_users, fn {user, _score} ->
      :ets.delete(:recommendation_cache, user.id)
    end)

    :ok
  end
end
```

## Conclusion

This example demonstrates:
- ✅ Modeling users and products as a graph
- ✅ Calculating user similarity
- ✅ Collaborative filtering recommendations
- ✅ Rating-based recommendations
- ✅ Category-based recommendations
- ✅ Performance optimization strategies

For production use, consider:
- Implementing proper error handling
- Adding metrics and monitoring
- Scaling with distributed mode
- A/B testing different recommendation strategies
- Handling cold-start problems (new users/products)

## Next Steps

- Explore [Social Network Example](social-network.md)
- Learn about [Performance Optimization](../advanced/performance.md)
- Set up [Distributed Mode](../../README_DISTRIBUTED.md)
