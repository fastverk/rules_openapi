//! contract_test_driver: exercises the rules_openapi plugin contract
//! against an arbitrary plugin binary. Same scenarios as
//! rules_jsonschema's driver, OpenAPI fixtures.
//!
//! Usage: `contract_test_driver <plugin-binary>`

use std::io::Write;
use std::process::{Command, ExitStatus, Stdio};

fn main() {
    let plugin = std::env::args().nth(1).expect("usage: contract_test_driver <plugin-path>");

    let scenarios: &[(&str, fn(&str) -> Result<(), String>)] = &[
        ("valid_minimal", scenario_valid_minimal),
        ("malformed_input", scenario_malformed_input),
        ("unknown_flag", scenario_unknown_flag),
        ("determinism", scenario_determinism),
    ];

    let mut failures = Vec::new();
    for (name, run) in scenarios {
        match run(&plugin) {
            Ok(()) => println!("PASS: {name}"),
            Err(e) => {
                println!("FAIL: {name}: {e}");
                failures.push(*name);
            }
        }
    }

    if !failures.is_empty() {
        eprintln!(
            "\ncontract_test: {} scenario(s) failed: {}",
            failures.len(),
            failures.join(", "),
        );
        std::process::exit(1);
    }
    println!("\nall {} scenarios passed", scenarios.len());
}

struct InvokeResult {
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    status: ExitStatus,
}

fn invoke(plugin: &str, args: &[&str], stdin_bytes: &[u8]) -> std::io::Result<InvokeResult> {
    let mut child = Command::new(plugin)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin.write_all(stdin_bytes)?;
    }
    let out = child.wait_with_output()?;
    Ok(InvokeResult {
        stdout: out.stdout,
        stderr: out.stderr,
        status: out.status,
    })
}

// Minimal-valid OpenAPI 3.0 document: top-level required keys present,
// one trivial GET path so codegen has something to emit. Reused across
// scenarios that need a successful invocation.
const MINIMAL_OPENAPI: &str = r#"{
  "openapi": "3.0.0",
  "info": {"title": "Test", "version": "1.0.0"},
  "paths": {
    "/ping": {
      "get": {
        "operationId": "ping",
        "responses": {
          "200": {"description": "ok"}
        }
      }
    }
  }
}"#;

fn scenario_valid_minimal(plugin: &str) -> Result<(), String> {
    let r = invoke(
        plugin,
        &["--schema-name=test.json", "--rule-name=test"],
        MINIMAL_OPENAPI.as_bytes(),
    )
    .map_err(|e| format!("spawn failed: {e}"))?;

    if !r.status.success() {
        return Err(format!(
            "expected exit 0, got {:?}; stderr was: {}",
            r.status,
            String::from_utf8_lossy(&r.stderr),
        ));
    }
    if r.stdout.is_empty() {
        return Err("plugin produced empty stdout on a valid input".into());
    }
    Ok(())
}

fn scenario_malformed_input(plugin: &str) -> Result<(), String> {
    let r = invoke(
        plugin,
        &["--schema-name=test.json", "--rule-name=test"],
        b"this is not valid yaml or json {{ ::: ",
    )
    .map_err(|e| format!("spawn failed: {e}"))?;

    if r.status.success() {
        return Err("plugin exited 0 on garbage input; contract says non-zero".into());
    }
    if !r.stdout.is_empty() {
        return Err(format!(
            "stdout must be empty on error; got {} bytes:\n{}",
            r.stdout.len(),
            String::from_utf8_lossy(&r.stdout),
        ));
    }
    if r.stderr.is_empty() {
        return Err("plugin failed silently; stderr should explain why".into());
    }
    Ok(())
}

fn scenario_unknown_flag(plugin: &str) -> Result<(), String> {
    let r = invoke(
        plugin,
        &[
            "--schema-name=test.json",
            "--rule-name=test",
            "--this-flag-does-not-exist=value",
        ],
        MINIMAL_OPENAPI.as_bytes(),
    )
    .map_err(|e| format!("spawn failed: {e}"))?;

    if r.status.success() {
        return Err(
            "plugin accepted an unknown flag; contract says reject unknown flags".into(),
        );
    }
    Ok(())
}

fn scenario_determinism(plugin: &str) -> Result<(), String> {
    let args = ["--schema-name=det.json", "--rule-name=det"];
    let r1 = invoke(plugin, &args, MINIMAL_OPENAPI.as_bytes())
        .map_err(|e| format!("spawn #1: {e}"))?;
    let r2 = invoke(plugin, &args, MINIMAL_OPENAPI.as_bytes())
        .map_err(|e| format!("spawn #2: {e}"))?;

    if !r1.status.success() {
        return Err(format!(
            "setup invocation failed: {}",
            String::from_utf8_lossy(&r1.stderr),
        ));
    }
    if r1.stdout != r2.stdout {
        return Err(format!(
            "plugin output differs between identical invocations\n--- run 1 ---\n{}\n--- run 2 ---\n{}",
            String::from_utf8_lossy(&r1.stdout),
            String::from_utf8_lossy(&r2.stdout),
        ));
    }
    Ok(())
}
