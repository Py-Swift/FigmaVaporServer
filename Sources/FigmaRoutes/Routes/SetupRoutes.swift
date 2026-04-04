import Vapor
import Foundation

struct SetupRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // /install-ca/cert — serves the mkcert root CA as .crt so Safari opens
        // the "Install Certificate" dialog automatically on iOS/iPadOS.
        routes.get("install-ca", "cert") { req -> Response in
            let caPath = req.application.directory.workingDirectory + "rootCA.pem"
            guard let data = FileManager.default.contents(atPath: caPath) else {
                throw Abort(.notFound, reason: "rootCA.pem not found — restart the server to copy it")
            }
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "application/x-x509-ca-cert")
            headers.replaceOrAdd(name: .contentDisposition, value: #"attachment; filename="rootCA.crt""#)
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        // /install-ca — setup page with download button, QR code, and step-by-step instructions
        routes.get("install-ca") { req -> Response in
            let host = req.headers.first(name: .host) ?? "localhost:8765"
            let certURL = "https://\(host)/install-ca/cert"
            let encodedURL = certURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? certURL
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: installCAPage(certURL: certURL, encodedCertURL: encodedURL))
            )
        }
    }
}

private func installCAPage(certURL: String, encodedCertURL: String) -> String {
    """
    <!DOCTYPE html>
    <html><head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Trust Server Certificate</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, sans-serif; background: #f2f2f7; min-height: 100vh; display: flex; align-items: flex-start; justify-content: center; padding: 40px 16px; }
        .card { background: #fff; border-radius: 20px; padding: 28px 24px; max-width: 400px; width: 100%; text-align: center; }
        h1 { font-size: 1.25rem; font-weight: 700; margin-bottom: 6px; }
        .sub { color: #888; font-size: .88rem; margin-bottom: 24px; }
        img.qr { display: block; margin: 0 auto 16px; border-radius: 10px; background: #f2f2f7; }
        .url { font-family: monospace; font-size: .7rem; background: #f2f2f7; border-radius: 8px; padding: 8px 12px; margin-bottom: 20px; word-break: break-all; color: #444; }
        a.btn { display: block; background: #007aff; color: #fff; text-decoration: none; font-size: 1rem; font-weight: 600; padding: 15px; border-radius: 14px; margin-bottom: 28px; }
        ol { text-align: left; padding-left: 20px; }
        li { font-size: .88rem; line-height: 2.2; }
        .note { margin-top: 20px; color: #bbb; font-size: .75rem; }
      </style>
    </head><body>
      <div class="card">
        <h1>Trust This Server</h1>
        <p class="sub">One-time setup &mdash; removes certificate warnings on this device forever.</p>
        <img class="qr" width="160" height="160"
             src="https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=\(encodedCertURL)"
             onerror="this.remove()" alt="">
        <div class="url">\(certURL)</div>
        <a class="btn" href="/install-ca/cert">&#8595; Download rootCA.crt</a>
        <ol>
          <li>Tap the button &mdash; Safari downloads the certificate</li>
          <li>Open <b>Settings &rarr; General &rarr; VPN &amp; Device Management</b></li>
          <li>Tap the <b>mkcert</b> profile &rarr; <b>Install</b></li>
          <li>Go to <b>Settings &rarr; General &rarr; About &rarr; Certificate Trust Settings</b></li>
          <li>Enable full trust for <b>mkcert development CA</b></li>
        </ol>
        <p class="note">The QR code links directly to the certificate. Scan it to skip typing the URL.</p>
      </div>
    </body></html>
    """
}
