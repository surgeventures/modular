# Modular

**Apply modular programming principles and patterns to build better Elixir apps.**

Modular is a toolbox that helps Elixir developers to apply modular programming principles and
patterns in their projects. It includes checks for defining and enforcing modular programming rules
& conventions as well as utilities for mapping the characteristics of a growing project.

Modular currently offers following tools:

- `Modular.AreaAccess` - ensures that module access is limited to given area's public contract
- `Modular.ContractTests` - ensures that public contracts are always covered with tests
- `Modular.Delegate` - defines thin contracts with call delegation to internal implementations
- `Modular.Mutability` - provides command/query annotations for functions within area contracts
- `Modular.Owner` - provides ownership annotations for area contracts

## Installation

Add `modular` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:modular, "~> 0.1"}
  ]
end
```
