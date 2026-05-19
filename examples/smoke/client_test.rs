// Compile + import test for the generated keeper client. We don't
// make real HTTP calls — that would need a test server — but
// constructing a Client and referencing generated types fails at
// build time if the codegen pipeline broke.
//
// The "keeper" spec is from progenitor's own integration test
// suite; the types below (EnrolBody, ReportId, …) are what
// progenitor emits for it. If progenitor renames things in a future
// version, this test catches it.

use keeper_client::*;

#[test]
fn client_can_be_constructed() {
    // progenitor's Client::new takes a base URL string; the
    // constructor doesn't open a connection.
    let _client = Client::new("http://127.0.0.1:0");
}

#[test]
fn report_id_struct_round_trips() {
    // ReportId is a composite struct in keeper's spec (host + job +
    // pid + time + uuid). Decode a canonical payload + assert on a
    // representative field. Catches both serde wiring and chrono
    // DateTime parsing.
    let raw = r#"{
      "host": "h",
      "job": "j",
      "pid": 42,
      "time": "2024-01-01T00:00:00Z",
      "uuid": "abc-123"
    }"#;
    let parsed: types::ReportId = serde_json::from_str(raw).expect("decode ReportId");
    assert_eq!(parsed.pid, 42);
    assert_eq!(parsed.host, "h");
}

#[test]
fn enrol_body_decodes_a_minimal_payload() {
    // The shape of EnrolBody is dictated by the keeper spec; this
    // just asserts the type exists and decodes a known-good payload.
    // If progenitor's struct layout changes (field renamed / added),
    // the deny_unknown_fields default catches it.
    let raw = r#"{"host":"box01","key":"shhh"}"#;
    let parsed: types::EnrolBody = serde_json::from_str(raw).expect("decode EnrolBody");
    assert_eq!(parsed.host, "box01");
}
