import SwiftUI
import WebKit

/// FitCheck (fitcheck.andypandy.org) hosted as a native tab.
///
/// It's a thin WKWebView rather than bundled files on purpose: FitCheck relies on
/// its own server-side proxies (image generation, shop import, cross-device sync),
/// so it needs the live site regardless. Website data (IndexedDB / localStorage)
/// persists in the default data store, so uploaded photos, the store catalogue and
/// the sync secret survive between launches.
struct FitCheckView: View {
    var body: some View {
        FitCheckWebView(url: URL(string: "https://fitcheck.andypandy.org")!)
            .ignoresSafeArea(.container, edges: .bottom)   // fill to the tab bar; top stays under the status bar
    }
}

private struct FitCheckWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // persistent store keeps FitCheck's IndexedDB/localStorage across launches
        config.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}
