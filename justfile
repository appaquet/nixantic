
# Run nix flake checks
check:
    nix flake check --show-trace

# Format all nix files in the repository
fmt:
    git ls-files -z --cached --others --exclude-standard -- '*.nix' | xargs -0 -r nixfmt

# Render the examples fragment set to ./result for inspection
examples:
    nix build .#examples
