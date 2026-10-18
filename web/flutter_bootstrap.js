{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Serve CanvasKit from local assets so no CDN (www.gstatic.com)
    // access is needed to start the app.
    canvasKitBaseUrl: "/canvaskit/",
  },
});
