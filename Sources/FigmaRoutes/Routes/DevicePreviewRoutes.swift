import Vapor
import VaporKivyReloader

struct DevicePreviewRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // GET /device-preview?w=390&h=844
        // Browser navigates directly to the container's noVNC URL (plain HTTP on LAN).
        // Vapor just starts the container and redirects once it's ready.
        routes.get("device-preview") { req async -> Response in
            let w = (try? req.query.get(Int.self, at: "w")).flatMap { $0 > 0 ? $0 : nil }
            let h = (try? req.query.get(Int.self, at: "h")).flatMap { $0 > 0 ? $0 : nil }

            if let w, let h {
                await DeviceReloader.shared.setResolution(width: w, height: h)
                let code = await CanvasPyCache.shared.fetch() ?? ""
                await DeviceReloader.shared.reload(code: code)
            }

            let html = devicePreviewHTML(hasSize: w != nil && h != nil)
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: html)
            )
        }

        // GET /device-preview/status
        routes.get("device-preview", "status") { req async -> Response in
            struct Status: Content { var running: Bool; var url: String? }
            let running = await DeviceReloader.shared.isRunning()
            let url = await DeviceReloader.shared.novncURL()
            let data = (try? JSONEncoder().encode(Status(running: running, url: url))) ?? Data()
            return Response(status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(data: data))
        }

        // POST /device-preview/resize
        routes.post("device-preview", "resize") { req async -> Response in
            struct Body: Content { var width: Int; var height: Int }
            guard let body = try? req.content.decode(Body.self),
                  body.width > 0, body.height > 0 else {
                return Response(status: .badRequest)
            }
            await DeviceReloader.shared.setResolution(width: body.width, height: body.height)
            return Response(status: .ok)
        }
    }
}


// MARK: - HTML

private func devicePreviewHTML(hasSize: Bool) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Kivy Preview</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; background: #111; overflow: hidden; }
        #vncFrame { width: 100%; height: 100%; border: none; display: none; }
        #msg { position: absolute; inset: 0; display: flex; align-items: center;
               justify-content: center; color: #888; font: 14px -apple-system, sans-serif; }
      </style>
    </head>
    <body>
      <p id="msg">\(hasSize ? "Starting container…" : "Measuring display…")</p>
      <iframe id="vncFrame" allowfullscreen></iframe>
      <script>
        (function() {
          var w = window.innerWidth, h = window.innerHeight;
          if (\(hasSize ? "false" : "true")) {
            window.location.replace('/device-preview?w=' + w + '&h=' + h);
            return;
          }
          var msg = document.getElementById('msg');
          var frame = document.getElementById('vncFrame');
          var attempt = 0;
          function poll() {
            if (attempt > 80) { msg.textContent = 'Timed out. Reload to retry.'; return; }
            attempt++;
            fetch('/device-preview/status')
              .then(function(r) { return r.json(); })
              .then(function(j) {
                if (j.running && j.url) {
                  msg.style.display = 'none';
                  frame.src = j.url;
                  frame.style.display = 'block';
                } else {
                  msg.textContent = 'Starting container… (' + attempt + ')';
                  setTimeout(poll, 3000);
                }
              })
              .catch(function() {
                msg.textContent = 'Waiting… (' + attempt + ')';
                setTimeout(poll, 3000);
              });
          }
          poll();
        })();
      </script>
    </body>
    </html>
    """
}
