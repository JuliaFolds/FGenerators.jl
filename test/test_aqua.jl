module TestAqua

using Aqua
using FGenerators

Aqua.test_all(
    FGenerators;
    project_extras = true,
    stale_deps = true,
    deps_compat = true,
    project_toml_formatting = true,
)

end  # module
