"""Rust user-facing rules for rules_openapi.

`openapi_rust_client` is the Rust client codegen rule:

  1. Resolves the `rust_client_codegen_toolchain_type` toolchain.
  2. Runs the toolchain's binary on the OpenAPI spec (stdin/argv/
     stdout per `//openapi/plugin_contract.md`), producing a `.rs`.
  3. Wraps the `.rs` in a `rust_library` whose deps include
     `progenitor-client`, `reqwest`, `serde`, `serde_json`, and any
     additional crates the consumer threads through.

The default toolchain (registered by MODULE.bazel) points at the
in-repo `openapi_to_rust_client` binary, which wraps `progenitor`
under the hood. Swap by declaring your own `openapi_codegen_toolchain`
and registering it ahead of the default.
"""

load("@rules_rust//rust:defs.bzl", "rust_library")

_TOOLCHAIN = "@rules_openapi//openapi:rust_client_codegen_toolchain_type"

def _rust_client_codegen_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".rs")
    tc = ctx.toolchains[_TOOLCHAIN].codegen_info

    cmd_parts = [
        tc.binary.path,
        "--schema-name={}".format(ctx.file.spec.basename),
        "--rule-name={}".format(ctx.label.name),
    ]
    for arg in ctx.attr.extra_args:
        cmd_parts.append(_shell_quote(arg))
    cmd_parts.extend(["<", ctx.file.spec.path, ">", out.path])

    ctx.actions.run_shell(
        outputs = [out],
        inputs = [ctx.file.spec],
        tools = [tc.binary],
        command = " ".join(cmd_parts),
        mnemonic = "OpenapiRustClient",
        progress_message = "openapi → rust client %s" % ctx.label,
    )
    return [DefaultInfo(files = depset([out]))]

_openapi_rust_client_codegen = rule(
    implementation = _rust_client_codegen_impl,
    attrs = {
        "spec": attr.label(
            allow_single_file = [".yaml", ".yml", ".json"],
            mandatory = True,
            doc = "OpenAPI document (YAML or JSON).",
        ),
        "extra_args": attr.string_list(
            doc = "Extra `--key=value` flags appended to the plugin invocation.",
        ),
    },
    toolchains = [_TOOLCHAIN],
)

def _shell_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"

def openapi_rust_client(
        name,
        spec,
        extra_args = None,
        progenitor_client = None,
        reqwest = None,
        serde = None,
        serde_json = None,
        regress = None,
        visibility = None,
        **rust_library_kwargs):
    """Generate a rust_library of a typed OpenAPI HTTP client.

    The library exports a `Client` struct with one method per
    OpenAPI operation, plus a `types` module containing serde
    structs for `components/schemas`.

    Args:
      name: rust_library target name. Consumers add this to `deps`.
      spec: label of an OpenAPI `.yaml` / `.yml` / `.json` document.
      extra_args: extra `--key=value` flags passed to the plugin.
      progenitor_client: label of the `progenitor_client` runtime
        crate the generated code references. Defaults to
        `@openapi_crates//:progenitor-client`. Consumers using their own
        crates_universe must thread this through (and likewise the
        other runtime-dep attrs below) to avoid the same trait-
        identity mismatch rules_jsonschema documents.
      reqwest: label of `reqwest` (HTTP client the generated code uses).
      serde: label of `serde`.
      serde_json: label of `serde_json`.
      regress: label of `regress` (used by typify-generated types
        nested inside progenitor's output).
      visibility: forwarded to rust_library.
      **rust_library_kwargs: forwarded to rust_library (e.g. extra `deps`).
    """
    gen_name = name + "_rs_gen"
    _openapi_rust_client_codegen(
        name = gen_name,
        spec = spec,
        extra_args = extra_args or [],
    )
    rt_deps = [
        progenitor_client or Label("@openapi_crates//:progenitor-client"),
        reqwest or Label("@openapi_crates//:reqwest"),
        serde or Label("@openapi_crates//:serde"),
        serde_json or Label("@openapi_crates//:serde_json"),
        regress or Label("@openapi_crates//:regress"),
        # progenitor unconditionally references chrono / uuid / bytes
        # in trait impls at module scope, even when the specific
        # spec doesn't use the corresponding formats.
        Label("@openapi_crates//:chrono"),
        Label("@openapi_crates//:uuid"),
        Label("@openapi_crates//:bytes"),
    ]
    extra_deps = rust_library_kwargs.pop("deps", [])
    rust_library(
        name = name,
        srcs = [":" + gen_name],
        edition = "2021",
        deps = rt_deps + extra_deps,
        visibility = visibility,
        **rust_library_kwargs
    )
