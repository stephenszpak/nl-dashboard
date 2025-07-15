import "phoenix_html";
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";

// Initialize LiveView socket with CSRF token from meta tag
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
