# Social Network Example

This example demonstrates building a complete social network graph using Grapple's features.

## Scenario

We'll model a social network with:
- Users with profiles
- Friendship connections
- Posts and comments
- Like relationships
- Group memberships

## Implementation

### Step 1: Create Users

```elixir
# Start the system
{:ok, _} = Grapple.start()

# Create users with rich profiles
users = [
  %{name: "Alice Johnson", age: 28, city: "San Francisco", job: "Engineer"},
  %{name: "Bob Smith", age: 32, city: "New York", job: "Designer"},
  %{name: "Charlie Brown", age: 25, city: "Austin", job: "Student"},
  %{name: "Diana Prince", age: 30, city: "Seattle", job: "Manager"}
]

user_ids = Enum.map(users, fn user ->
  {:ok, id} = Grapple.create_node(user)
  id
end)
```

### Step 2: Build Social Connections

```elixir
# Create friendships with connection strength
[alice, bob, charlie, diana] = user_ids

# Alice's connections
{:ok, _} = Grapple.create_edge(alice, bob, "friends", %{since: "2020", strength: "close"})
{:ok, _} = Grapple.create_edge(alice, charlie, "friends", %{since: "2021", strength: "casual"})

# Bob's connections  
{:ok, _} = Grapple.create_edge(bob, diana, "friends", %{since: "2019", strength: "close"})

# Charlie's connections
{:ok, _} = Grapple.create_edge(charlie, diana, "friends", %{since: "2022", strength: "new"})
```

### Step 3: Add Content

```elixir
# Create posts
{:ok, post1} = Grapple.create_node(%{
  type: "post",
  content: "Beautiful sunset today!",
  timestamp: DateTime.utc_now(),
  author: alice
})

{:ok, post2} = Grapple.create_node(%{
  type: "post", 
  content: "Working on a new design project",
  timestamp: DateTime.utc_now(),
  author: bob
})

# Link posts to authors
{:ok, _} = Grapple.create_edge(alice, post1, "authored")
{:ok, _} = Grapple.create_edge(bob, post2, "authored")

# Add likes
{:ok, _} = Grapple.create_edge(bob, post1, "liked", %{timestamp: DateTime.utc_now()})
{:ok, _} = Grapple.create_edge(charlie, post1, "liked", %{timestamp: DateTime.utc_now()})
```

### Step 4: Create Groups

```elixir
# Create interest groups
{:ok, tech_group} = Grapple.create_node(%{
  type: "group",
  name: "Tech Enthusiasts",
  description: "Discussing latest technology trends"
})

{:ok, design_group} = Grapple.create_node(%{
  type: "group", 
  name: "Design Collective",
  description: "Sharing design inspiration and feedback"
})

# Add group memberships
{:ok, _} = Grapple.create_edge(alice, tech_group, "member", %{role: "admin"})
{:ok, _} = Grapple.create_edge(bob, tech_group, "member", %{role: "member"})
{:ok, _} = Grapple.create_edge(bob, design_group, "member", %{role: "admin"})
{:ok, _} = Grapple.create_edge(diana, design_group, "member", %{role: "member"})
```

## Advanced Queries

### Find Mutual Friends

```elixir
defmodule SocialQueries do
  def mutual_friends(user1_id, user2_id) do
    user1_friends = Grapple.get_neighbors(user1_id, edge_type: "friends")
    user2_friends = Grapple.get_neighbors(user2_id, edge_type: "friends")
    
    # Find intersection
    mutual = MapSet.intersection(
      MapSet.new(user1_friends),
      MapSet.new(user2_friends)
    )
    
    MapSet.to_list(mutual)
  end
  
  def friend_recommendations(user_id) do
    # Friends of friends who aren't already friends
    friends = Grapple.get_neighbors(user_id, edge_type: "friends")
    
    friends_of_friends = friends
    |> Enum.flat_map(&Grapple.get_neighbors(&1, edge_type: "friends"))
    |> Enum.uniq()
    |> Enum.reject(&(&1 == user_id or &1 in friends))
    
    friends_of_friends
  end
  
  def popular_posts(limit \\ 10) do
    # Find posts with most likes
    Grapple.query("""
      MATCH (u)-[:liked]->(p {type: "post"})
      RETURN p, count(u) as likes
      ORDER BY likes DESC
      LIMIT #{limit}
    """)
  end
end
```

### Usage Examples

```elixir
# Find mutual friends between Alice and Bob
mutual = SocialQueries.mutual_friends(alice, bob)

# Get friend recommendations for Charlie
recommendations = SocialQueries.friend_recommendations(charlie)

# Find most popular posts
popular = SocialQueries.popular_posts(5)

# Analyze social circles
alice_network = Grapple.traverse(alice, depth: 2, edge_types: ["friends"])
```

## Visualization

```elixir
# Visualize the entire social network
Grapple.visualize()

# Focus on specific user's network
Grapple.visualize(center: alice, depth: 2)

# Show only friendships
Grapple.visualize(edge_types: ["friends"])
```

## Performance Analysis

```elixir
# Benchmark friend finding
{time, _result} = :timer.tc(fn ->
  Grapple.get_neighbors(alice, edge_type: "friends")
end)

IO.puts("Friend lookup took #{time} microseconds")

# Check memory usage
stats = Grapple.stats()
IO.inspect(stats)
```

## CLI Exploration

```bash
# Start interactive mode
mix run -e "Grapple.CLI.Shell.start()"

# Explore the social network
grapple> list_nodes type:"user"
grapple> neighbors 1 friends
grapple> path 1 4
grapple> visualize center:1 depth:2
grapple> stats
```

## Extensions

Ideas for extending this example:

1. **Messaging System**: Add private messages between users
2. **Event Planning**: Create events with attendee relationships  
3. **Content Sharing**: Model shares, reposts, and viral content
4. **Influence Analysis**: Calculate user influence scores
5. **Community Detection**: Find tight-knit friend groups
6. **Recommendation Engine**: Suggest friends, posts, groups
7. **Activity Feeds**: Generate personalized content feeds
8. **Privacy Controls**: Model friendship visibility settings

This example demonstrates Grapple's flexibility for modeling complex social relationships and running sophisticated graph analytics.