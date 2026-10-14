import SwiftUI
import WebKit

final class TranslateHandler: NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(_ uc: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let text = message.body as? String else { replyHandler(nil, "bad"); return }
        Task {
            do { replyHandler(try await Translator.translate(text), nil) }
            catch { replyHandler(nil, error.localizedDescription) }
        }
    }
}

struct DiscordWebView: UIViewRepresentable {
    static let js = #"""
    (function(){
      if (window.__dt) return; window.__dt = true;
      let auto = localStorage.getItem('dt_auto') !== '0';
      let done = new WeakSet();
      const cache = new Map();
      async function handle(el){
        if (done.has(el)) return;
        const text = (el.innerText || '').trim();
        if (!text) return;
        done.add(el);
        try {
          let t = cache.get(text);
          if (!t) {
            t = await window.webkit.messageHandlers.translate.postMessage(text);
            cache.set(text, t);
          }
          if (!t || t === text) return;
          const d = document.createElement('div');
          d.className = 'dt-tr';
          d.style.cssText = 'color:#5865f2;font-size:0.9em;margin-top:2px;border-left:3px solid #5865f2;padding-left:6px;';
          d.textContent = t;
          el.appendChild(d);
        } catch (e) {}
      }
      function scan(){
        if (!auto) return;
        document.querySelectorAll('[id^="message-content-"]').forEach(handle);
      }
      new MutationObserver(function(){
        clearTimeout(window.__dtT);
        window.__dtT = setTimeout(scan, 400);
      }).observe(document.documentElement, {childList: true, subtree: true});
      const b = document.createElement('div');
      function label(){ b.textContent = auto ? '译:开' : '译:关'; }
      b.style.cssText = 'position:fixed;bottom:90px;right:12px;z-index:99999;background:#5865f2;color:#fff;padding:8px 12px;border-radius:20px;font:600 13px sans-serif;';
      label();
      b.onclick = function(){
        auto = !auto;
        localStorage.setItem('dt_auto', auto ? '1' : '0');
        label();
        if (auto) { scan(); }
        else { document.querySelectorAll('.dt-tr').forEach(function(e){ e.remove(); }); done = new WeakSet(); }
      };
      document.body.appendChild(b);
      scan();
    })();
    """#

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.allowsInlineMediaPlayback = true
        cfg.userContentController.addScriptMessageHandler(TranslateHandler(), contentWorld: .page, name: "translate")
        cfg.userContentController.addUserScript(
            WKUserScript(source: Self.js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        wv.allowsBackForwardNavigationGestures = true
        wv.load(URLRequest(url: URL(string: "https://discord.com/app")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
