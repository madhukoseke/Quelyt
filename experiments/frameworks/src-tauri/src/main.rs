// Disposable framework comparison. Only fixed synthetic fixtures are reachable.
use std::{io::{Read, Write}, process::{Child, Command, Stdio}, sync::{Arc, Mutex}, time::{Duration, Instant}, path::PathBuf};
use serde_json::{json, Value};
use tauri::Manager;
#[derive(Default)]
struct Worker(Arc<Mutex<Option<Child>>>);
fn root() -> PathBuf { PathBuf::from(env!("CARGO_MANIFEST_DIR")).ancestors().nth(3).unwrap().to_path_buf() }
#[tauri::command]
async fn query(state: tauri::State<'_, Worker>, sql: String, format: String) -> Result<Value, String> {
    if !["csv", "parquet"].contains(&format.as_str()) || sql.len() > 32000 { return Err("Invalid fixture/query".into()); }
    let shared = state.0.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let base = root();
        let mut guard = shared.lock().map_err(|_| "worker lock")?;
        if guard.is_some() { return Err("Already running".into()); }
        let mut child = Command::new(base.join(".venv/bin/python"))
            .args(["-I", "-B"]).arg(base.join("src/quelyt/worker.py"))
            .env_clear().env("PATH", "/usr/bin:/bin")
            .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null())
            .spawn().map_err(|e| e.to_string())?;
        let input = json!({"path":base.join(format!("experiments/discovery/data/sales.{}", format)), "sql":sql, "timeout_seconds":15});
        child.stdin.take().unwrap().write_all(input.to_string().as_bytes()).map_err(|e| e.to_string())?;
        let mut out = child.stdout.take().unwrap();
        *guard = Some(child); drop(guard);
        let reader = std::thread::spawn(move || { let mut data = Vec::new(); let _ = (&mut out).take(2*1024*1024+1).read_to_end(&mut data); data });
        let start = Instant::now();
        loop {
            let mut guard = shared.lock().map_err(|_| "worker lock")?;
            let c = guard.as_mut().ok_or("Worker missing")?;
            if start.elapsed() > Duration::from_secs(30) { let _ = c.kill(); }
            if c.try_wait().map_err(|e| e.to_string())?.is_some() { break; }
            drop(guard); std::thread::sleep(Duration::from_millis(10));
        }
        let data = reader.join().map_err(|_| "reader panic")?;
        *shared.lock().map_err(|_| "worker lock")? = None;
        if data.len()>2*1024*1024 {return Err("Output budget exceeded".into());}
        serde_json::from_slice(&data).map_err(|_| "Cancelled or worker exited".into())
    }).await.map_err(|e| e.to_string())?
}
#[tauri::command]
fn cancel(state: tauri::State<'_, Worker>) { if let Some(c)=state.0.lock().unwrap().as_mut(){ let _=c.kill(); } }
#[tauri::command]
fn record(metrics: Value) -> Result<(), String> {
    std::fs::write(root().join("experiments/frameworks/tauri-results.json"), serde_json::to_string_pretty(&metrics).unwrap_or_else(|_| metrics.to_string())).map_err(|e|e.to_string())
}
#[tauri::command]
fn ready() { println!("QUELYT_READY"); let _=std::io::stdout().flush(); }
#[tauri::command]
fn auto_compare() -> bool { std::env::var("QUELYT_COMPARE").ok().as_deref() == Some("1") }
#[tauri::command]
fn quit() { std::process::exit(0); }
fn main() {
    tauri::Builder::default().manage(Worker::default())
        .invoke_handler(tauri::generate_handler![query,cancel,record,ready,auto_compare,quit])
        .on_window_event(|window,event| {if let tauri::WindowEvent::Destroyed=event {let state=window.state::<Worker>();if let Some(c)=state.0.lock().unwrap().as_mut(){let _=c.kill();};}})
        .run(tauri::generate_context!()).expect("Tauri experiment failed");
}
