# rules_openapi plugin contract

> Authoritative specification for what an OpenAPI codegen plugin
> must do. The contract is identical in shape to
> [rules_jsonschema's plugin contract](https://github.com/fastverk/rules_jsonschema/blob/main/jsonschema/plugin_contract.md);
> the only differences are (a) stdin carries an OpenAPI document
> (JSON or YAML) instead of a JSON Schema, and (b) the per-plugin
> flags reflect OpenAPI-specific knobs (client base URL, server
> bind address, async vs sync, …).

## Process model

```
INPUT
  stdin              the OpenAPI document (raw bytes, JSON or YAML)
  argv               --key=value pairs, repeated

OUTPUT
  stdout             the generated file content (raw bytes)
  stderr             human-readable diagnostics

EXIT
  0                  success — stdout is the generated file
  non-zero           failure — stderr explains why
```

Plugins must not write anything to stdout other than the final
generated file content. Diagnostics go to stderr unconditionally.

## Standard argv flags

| Flag | Meaning |
|---|---|
| `--schema-name=NAME` | Basename of the source spec file, e.g. `petstore.yaml`. For error messages and codegen header comments. |
| `--rule-name=NAME` | Name of the Bazel target invoking the plugin. Useful for picking module / package names. |

A plugin **must accept** these flags. It may treat them as no-ops if
they don't apply.

## Consumer-supplied argv flags

User-facing rules forward additional flags per the rule's role:

| Rule | Forwards |
|---|---|
| `openapi_rust_client` | per-rule `extra_args` only (the default plugin's progenitor backend exposes no first-class knobs today) |
| (future) `openapi_go_client` | `--package=NAME`, … |
| (future) `openapi_rust_server` | `--server-trait=NAME`, … |

Plugins should treat unknown flags as a hard error — silently
ignoring them would make misconfigured options degrade the output
without warning.

## Error reporting

Two failure modes:

1. **Generation error** (the spec is valid OpenAPI but the plugin
   can't handle some construct — unsupported security scheme,
   discriminator shape we don't model, etc.). Plugin writes a
   human-readable message to stderr and exits non-zero.
2. **Plugin bug** (panic, segfault, library exception). Plugin
   process terminates abnormally; Bazel surfaces the non-zero exit
   and stderr.

Both fail the build identically.

## Output stability

Plugins should produce **deterministic output** for the same input:

- Iterate operations / schemas / paths in sorted order (YAML map
  iteration order is undefined; Go's `map`, Rust's `HashMap`, and
  Python's pre-3.7 dicts will burn you).
- Don't embed timestamps, hostnames, or build IDs.
- The full input path isn't stable across consumers — use
  `--schema-name` (basename only) for header comments.

## Multi-file output

A plugin emits **exactly one file's content** on stdout. Multi-file
output kinds (types vs operations, client vs server, sync vs async)
are expressed as separate Bazel rule invocations against separate
plugins. If a future plugin genuinely needs to emit many files at
once, wrap it in a rule that uses `ctx.actions.declare_directory`
and downstream rules consume the tree artifact.

## Conformance testing

The `openapi_plugin_contract_test` rule (in
[`contract_test.bzl`](contract_test.bzl)) runs an in-repo driver
that exercises:

| Scenario | Asserts |
|---|---|
| `valid_minimal` | Plugin exits 0 + writes non-empty stdout for a well-formed minimal spec. |
| `malformed_input` | Plugin exits non-zero, writes to stderr, and **does not write to stdout** on garbage input. |
| `unknown_flag` | Plugin rejects an unknown `--key=value` flag. |
| `determinism` | Two identical invocations produce byte-identical stdout. |

```python
load("@rules_openapi//openapi:contract_test.bzl",
     "openapi_plugin_contract_test")

openapi_plugin_contract_test(
    name = "my_plugin_conforms",
    plugin = "//my:openapi_rust_client_codegen",
)
```

## Versioning

The contract is currently **v1**. Future versions will be declared
here.
