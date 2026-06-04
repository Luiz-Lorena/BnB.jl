# BnB.jl

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-with-text.svg">
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark-with-text.svg">
    <img alt="JuMP.jl logo." src="assets/logo-with-text-background.svg">
  </picture>
</p>

<p align="center">
  <a href="https://luiz-lorena.github.io/BnB.jl/">
    <img alt="Documentation" src="https://img.shields.io/badge/docs-GitHub%20Pages-blue?style=flat-square">
  </a>
</p>

---

BnB.jl is a lightweight, callback-driven branch-and-bound framework for binary optimization problems in Julia. It lets you plug in your own incumbent, relaxation, pruning, branching, and optimality checks while the package manages the search tree, node state, and solution tracking.

The package is organized around a small core API:

- `BnBData` for user-defined problem data
- `BnBNode` for individual search nodes
- `BnBCore` for the algorithm state
- `solve` as the main entry point

Optional tree visualization is available through `GraphMakie` and `CairoMakie` when `print_tree = true`.

## Installation

Install the package from GitHub with Julia's package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/Luiz-Lorena/BnB.jl")
```