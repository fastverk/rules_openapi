"""OpenAPI plugin conformance test.

`openapi_plugin_contract_test(name, plugin)` runs the rules_openapi
plugin contract scenarios against any plugin executable. Mirrors
rules_jsonschema's `jsonschema_plugin_contract_test` but with
OpenAPI-flavored fixtures (a minimal OpenAPI 3.1 document instead
of a JSON Schema).
"""

def _impl(ctx):
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    plugin_sp = ctx.executable.plugin.short_path
    driver_sp = ctx.executable._driver.short_path

    ctx.actions.write(
        output = runner,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail
RUNFILES_DIR="${{RUNFILES_DIR:-$0.runfiles}}"
WS_NAME="{ws}"

resolve() {{
    local sp="$1"
    if [[ "$sp" == ../* ]]; then
        printf '%s' "$RUNFILES_DIR/${{sp#../}}"
    else
        printf '%s' "$RUNFILES_DIR/$WS_NAME/$sp"
    fi
}}

DRIVER="$(resolve "{driver_sp}")"
PLUGIN="$(resolve "{plugin_sp}")"
exec "$DRIVER" "$PLUGIN"
""".format(
            ws = ctx.workspace_name,
            driver_sp = driver_sp,
            plugin_sp = plugin_sp,
        ),
    )

    runfiles = ctx.runfiles(files = [
        ctx.executable._driver,
        ctx.executable.plugin,
    ])
    return [DefaultInfo(executable = runner, runfiles = runfiles)]

openapi_plugin_contract_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "plugin": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The plugin binary to test.",
        ),
        "_driver": attr.label(
            default = Label("//tools/contract_test:contract_test_driver"),
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Run the rules_openapi plugin contract scenarios against a plugin binary.",
)
