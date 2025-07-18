import "phoenix_html";
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";

let Hooks = {};

Hooks.PromptInput = {
  mounted() {
    this.resize();
    this.el.addEventListener("input", () => this.resize());
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        this.el.form.requestSubmit();
      }
    });
  },
  resize() {
    this.el.style.height = "auto";
    this.el.style.height = this.el.scrollHeight + "px";
  }
};

Hooks.AutoGrow = {
  mounted() {
    this.resize();
    this.el.addEventListener("input", () => this.resize());
  },
  resize() {
    this.el.style.height = "auto";
    this.el.style.height = this.el.scrollHeight + "px";
  }
};

Hooks.VegaLiteChart = {
  mounted() { this.renderChart(); },
  updated() { this.renderChart(); },
  renderChart() {
    const spec = JSON.parse(this.el.dataset.spec || '{}');
    if (window.vegaEmbed) {
      window.vegaEmbed(this.el, spec, {actions: false});
    }
  }
};

Hooks.EnableSubmitOnFileSelect = {
  mounted() {
    this.el.addEventListener("change", () => {
      const buttonId = this.el.dataset.submitButton;
      if (buttonId) {
        const btn = document.getElementById(buttonId);
        if (btn) btn.disabled = this.el.files.length === 0;
      }
    });
  }
};

// Initialize LiveView socket with CSRF token from meta tag
const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
