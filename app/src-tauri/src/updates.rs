//! Check published Android releases in the owner's fork. Installation is handled by Android.
use serde::{Deserialize, Serialize};
use crate::error::{ApiError, ApiResult};

#[derive(Deserialize)]
struct Release { tag_name: String, draft: bool, prerelease: bool, assets: Vec<Asset> }
#[derive(Deserialize)]
struct Asset { name: String }
#[derive(Serialize)]
pub struct Update { version: String, url: String }

fn version(value: &str) -> Option<[u32; 3]> {
    let parts: Vec<_> = value.split('.').collect();
    if parts.len() != 3 { return None; }
    Some([parts[0].parse().ok()?, parts[1].parse().ok()?, parts[2].parse().ok()?])
}

#[tauri::command]
pub async fn check_android_update() -> ApiResult<Option<Update>> {
    if !cfg!(target_os = "android") { return Ok(None); }
    let client = reqwest::Client::builder().tls_backend_preconfigured(crate::qubo::tls_config()?.as_ref().clone()).user_agent("Backsight-Android")
        .timeout(std::time::Duration::from_secs(15)).build().map_err(ApiError::internal)?;
    let releases: Vec<Release> = client.get("https://api.github.com/repos/shentharo/backsight/releases?per_page=100")
        .send().await.map_err(ApiError::internal)?.error_for_status().map_err(ApiError::internal)?
        .json().await.map_err(ApiError::internal)?;
    let installed = version(env!("CARGO_PKG_VERSION")).ok_or_else(|| ApiError::internal("Invalid installed version"))?;
    let best = releases.into_iter().filter(|r| !r.draft && !r.prerelease && r.assets.iter().any(|a| a.name == "backsight-android-arm64.apk"))
        .filter_map(|r| { let v = r.tag_name.strip_prefix("android-v")?; Some((version(v)?, v.to_owned())) })
        .filter(|(v, _)| *v > installed).max_by_key(|(v, _)| *v);
    Ok(best.map(|(_, v)| Update { url: format!("https://github.com/shentharo/backsight/releases/tag/android-v{v}"), version: v }))
}

#[cfg(test)]
mod tests {
    use super::version;
    #[test] fn versions_are_numeric_triplets() {
        assert!(version("1.2.10") > version("1.2.9"));
        assert_eq!(version("1.2.3-evil"), None);
        assert_eq!(version("1.2"), None);
    }
}
