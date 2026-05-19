"""Module extensions for rules_openapi's examples / tests.

This file ships only fixtures needed by the in-repo smoke test —
consumers don't need it. The pattern is the same one
rules_docker_compose uses for compose-spec: pin upstream by commit
SHA + sha256, fetch via `http_file`, never vendor.

Bumping a fixture is a two-line edit (commit + sha256). Compute the
hash with: `curl -fsSL <url> | shasum -a 256`.

### About the example spec choice

The canonical "petstore" OpenAPI specs (OAI/OpenAPI-Specification's
example + swagger-api/swagger-petstore) exercise progenitor edge
cases (multi-content-type request bodies, distinct success vs.
error response schemas) that the upstream Rust codegen hasn't
implemented as of v0.14. Rather than ship a smoke test that fails
for unrelated reasons, we use one of progenitor's own integration-
test specs — `keeper.json` is small, real, and guaranteed to round-
trip cleanly through the codegen because it's in progenitor's own
test suite.

Real consumers whose OpenAPI specs trigger progenitor limitations
have two clean escape hatches: a preprocessing pass that normalizes
the spec, or registering a different codegen toolchain entirely
(say, wrapping `openapi-generator`).
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

# https://github.com/oxidecomputer/progenitor/blob/<sha>/sample_openapi/keeper.json
# A small, real OpenAPI 3 spec from progenitor's own test suite.
# Pinning to the file's last-modified commit so the smoke test
# doesn't break if upstream rotates the example.
_KEEPER_COMMIT = "e34756583add0ea0438f0184c40c80c613795f73"
_KEEPER_SHA256 = "5513429cb3ae04aeb66a176c8c4ee5491f7a159e24fdd4728c042b3e5cf2834c"

def _impl(_mctx):
    http_file(
        name = "openapi_keeper_example",
        urls = [
            "https://raw.githubusercontent.com/oxidecomputer/progenitor/{}/sample_openapi/keeper.json".format(
                _KEEPER_COMMIT,
            ),
        ],
        sha256 = _KEEPER_SHA256,
        downloaded_file_path = "keeper.json",
    )

openapi_examples_extension = module_extension(implementation = _impl)
