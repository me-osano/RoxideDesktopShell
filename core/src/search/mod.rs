use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tantivy::{
    Index, IndexWriter, TantivyDocument,
    collector::TopDocs,
    query::QueryParser,
    schema::*,
};
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

use crate::ipc::AppState;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchResults {
    pub query: String,
    pub hits: Vec<SearchHit>,
    pub total: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SearchHit {
    pub path: String,
    pub name: String,
    pub score: f32,
    pub kind: FileKind,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FileKind {
    File,
    Directory,
    Image,
    Video,
    Audio,
    Document,
    Code,
}

impl FileKind {
    fn from_path(path: &str) -> Self {
        let ext = std::path::Path::new(path)
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();
        match ext.as_str() {
            "jpg" | "jpeg" | "png" | "gif" | "webp" | "svg" => FileKind::Image,
            "mp4" | "mkv" | "avi" | "mov" | "webm" => FileKind::Video,
            "mp3" | "flac" | "ogg" | "wav" | "opus" => FileKind::Audio,
            "pdf" | "doc" | "docx" | "odt" | "md" | "txt" => FileKind::Document,
            "rs" | "py" | "js" | "ts" | "go" | "c" | "cpp" | "nix" | "lua" | "sh" => FileKind::Code,
            "" => FileKind::Directory,
            _ => FileKind::File,
        }
    }
}

fn index_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("roxide/search-index")
}

fn index_roots() -> Vec<PathBuf> {
    let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/home"));
    vec![
        home.join("Documents"),
        home.join("Downloads"),
        home.join("Projects"),
        home.join(".config"),
        home.clone(),
    ]
}

pub async fn query(_state: &AppState, q: &str, limit: usize) -> Result<SearchResults> {
    let index_path = index_dir();
    if !index_path.exists() {
        return Ok(SearchResults { query: q.to_string(), hits: vec![], total: 0 });
    }

    // Run tantivy query on blocking thread pool
    let q = q.to_string();
    let results = tokio::task::spawn_blocking(move || -> Result<SearchResults> {
        let index = Index::open_in_dir(&index_path)?;
        let schema = index.schema();
        let path_field = schema.get_field("path").unwrap();
        let name_field = schema.get_field("name").unwrap();

        let reader = index.reader()?;
        let searcher = reader.searcher();
        let query_parser = QueryParser::for_index(&index, vec![name_field, path_field]);

        // Fuzzy-ish: append wildcard if no special chars
        let query_str = if q.chars().all(|c| c.is_alphanumeric() || c == '_' || c == '-' || c == '.') {
            format!("{}*", q)
        } else {
            q.clone()
        };

        let query = query_parser.parse_query(&query_str).unwrap_or_else(|_| {
            query_parser.parse_query(&q).unwrap()
        });

        let top_docs = searcher.search(&query, &TopDocs::with_limit(limit))?;
        let mut hits = Vec::new();

        for (score, addr) in top_docs {
            let doc: TantivyDocument = searcher.doc(addr)?;
            let path = doc.get_first(path_field)
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let name = doc.get_first(name_field)
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let kind = FileKind::from_path(&path);
            hits.push(SearchHit { path, name, score, kind });
        }

        Ok(SearchResults { query: q, total: hits.len(), hits })
    }).await??;

    Ok(results)
}

/// Background worker — builds index, then watches for changes
pub async fn worker(_state: AppState) {
    info!("search: building index...");

    if let Err(e) = build_index().await {
        warn!("search: index build failed: {e}");
        return;
    }

    info!("search: index ready, starting file watcher");
    watch_loop().await;
}

async fn build_index() -> Result<()> {
    let index_path = index_dir();
    std::fs::create_dir_all(&index_path)?;

    tokio::task::spawn_blocking(move || -> Result<()> {
        let mut schema_builder = Schema::builder();
        schema_builder.add_text_field("name", TEXT | STORED);
        schema_builder.add_text_field("path", TEXT | STORED);
        let schema = schema_builder.build();

        let index = Index::create_in_dir(&index_path, schema.clone())?;
        let mut writer: IndexWriter = index.writer(50_000_000)?; // 50MB buffer

        let name_field = schema.get_field("name").unwrap();
        let path_field = schema.get_field("path").unwrap();

        for root in index_roots() {
            if !root.exists() { continue; }
            index_directory(&mut writer, &root, name_field, path_field, 0, 6)?;
        }

        writer.commit()?;
        Ok(())
    }).await??;

    Ok(())
}

fn index_directory(
    writer: &mut IndexWriter,
    dir: &PathBuf,
    name_field: Field,
    path_field: Field,
    depth: u32,
    max_depth: u32,
) -> Result<()> {
    if depth > max_depth { return Ok(()); }

    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return Ok(()),
    };

    for entry in entries.flatten() {
        let path = entry.path();
        let path_str = path.to_string_lossy().to_string();

        // Skip hidden dirs (but allow hidden files at root level)
        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            if name.starts_with('.') && depth > 1 { continue; }

            let mut doc = TantivyDocument::default();
            doc.add_text(name_field, name);
            doc.add_text(path_field, &path_str);
            writer.add_document(doc)?;

            if path.is_dir() && depth < max_depth {
                index_directory(writer, &path, name_field, path_field, depth + 1, max_depth)?;
            }
        }
    }
    Ok(())
}

async fn watch_loop() {
    let (tx, mut rx) = mpsc::channel(64);

    let mut watcher = match RecommendedWatcher::new(
        move |res| { let _ = tx.blocking_send(res); },
        notify::Config::default(),
    ) {
        Ok(w) => w,
        Err(e) => { warn!("search watcher init failed: {e}"); return; }
    };

    for root in index_roots() {
        if root.exists() {
            let _ = watcher.watch(&root, RecursiveMode::Recursive);
        }
    }

    // Debounce: wait 5s of quiet before reindexing
    let mut pending = false;
    let mut last_event = tokio::time::Instant::now();

    loop {
        tokio::select! {
            Some(_event) = rx.recv() => {
                pending = true;
                last_event = tokio::time::Instant::now();
            }
            _ = tokio::time::sleep(tokio::time::Duration::from_secs(1)) => {
                if pending && last_event.elapsed().as_secs() >= 5 {
                    pending = false;
                    debug!("search: reindexing after filesystem changes");
                    let _ = build_index().await;
                }
            }
        }
    }
}
