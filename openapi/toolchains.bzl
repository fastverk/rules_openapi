"""Toolchain rules for rules_openapi codegen.

`openapi_codegen_toolchain` wraps a single codegen executable as a
Bazel toolchain. Toolchain types are split per (language, use_case)
pair — Rust clients, Go clients, Rust servers, etc. — so a consumer
can swap one plugin without affecting the rest.

Default toolchains are registered in the per-language directories
(`//rust:BUILD.bazel`, …). To swap an implementation, declare your
own `openapi_codegen_toolchain` and `register_toolchains(...)` it
ahead of rules_openapi's default in your `MODULE.bazel`.
"""

load(":providers.bzl", "OpenapiCodegenToolchainInfo")

def _openapi_codegen_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        codegen_info = OpenapiCodegenToolchainInfo(
            binary = ctx.executable.binary,
        ),
    )]

openapi_codegen_toolchain = rule(
    implementation = _openapi_codegen_toolchain_impl,
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The codegen executable. Must accept `--schema-name=NAME " +
                  "--rule-name=NAME` plus any per-plugin flags the calling " +
                  "rule passes through.",
        ),
    },
    doc = "Declare an OpenAPI → code codegen executable as a Bazel toolchain.",
)
