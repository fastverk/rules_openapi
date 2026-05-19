"""Providers exposed by rules_openapi.

Same shape as rules_jsonschema's `JsonschemaCodegenToolchainInfo` —
the plugin contract is identical (stdin/argv/stdout), the only
difference is the schema content shipped on stdin (OpenAPI document
rather than a JSON Schema).
"""

OpenapiCodegenToolchainInfo = provider(
    doc = "An OpenAPI → code codegen tool.",
    fields = {
        "binary": "File: the codegen executable. Invoked with " +
                  "`--schema-name=NAME --rule-name=NAME` plus per-plugin flags " +
                  "the calling rule passes through.",
    },
)
