import "phoenix_html";
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";

let Hooks = {};

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

// Chart.js hooks for analytics charts
Hooks.AnalyticsChart = {
  mounted() { this.renderChart(); },
  updated() { this.renderChart(); },
  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },
  renderChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    
    const config = JSON.parse(this.el.dataset.config || '{}');
    if (window.Chart && config.type) {
      const ctx = this.el.getContext('2d');
      this.chart = new window.Chart(ctx, config);
    }
  }
};

// Chart renderer hook for dashboard charts  
Hooks.ChartRenderer = {
  mounted() { 
    this.waitForChart();
  },
  updated() { 
    this.waitForChart();
  },
  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },
  waitForChart() {
    // Wait for Chart.js to load before rendering
    const checkChart = () => {
      if (window.Chart) {
        this.renderChart();
      } else {
        setTimeout(checkChart, 100);
      }
    };
    checkChart();
  },
  renderChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    
    const configData = this.el.dataset.chartConfig;
    if (!configData) {
      console.error('No chart config data found');
      return;
    }
    
    try {
      const config = JSON.parse(configData);
      if (config && config.type) {
        const ctx = this.el.getContext('2d');
        this.chart = new window.Chart(ctx, config);
      }
    } catch (error) {
      console.error('Error parsing chart config:', error);
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

Hooks.CopyOnClick = {
  mounted() {
    this.onCopy = (e) => {
      e.preventDefault();
      const text = this.el.dataset.text || "";
      if (!text) return;
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => this.toast(), () => this.toast());
      } else {
        // Fallback for older browsers
        const textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        try { document.execCommand('copy'); } catch (_) {}
        document.body.removeChild(textarea);
        this.toast();
      }
    };

    this.el.addEventListener('click', this.onCopy);
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        this.onCopy(e);
      }
    });
  },
  destroyed() {
    this.el.removeEventListener('click', this.onCopy);
  },
  toast() {
    const t = document.createElement('div');
    t.textContent = 'Copied prompt';
    t.style.position = 'fixed';
    t.style.bottom = '20px';
    t.style.right = '20px';
    t.style.padding = '8px 12px';
    t.style.background = 'rgba(17,24,39,0.9)'; // gray-900 with opacity
    t.style.color = 'white';
    t.style.borderRadius = '6px';
    t.style.fontSize = '12px';
    t.style.zIndex = '9999';
    t.style.boxShadow = '0 2px 8px rgba(0,0,0,0.2)';
    document.body.appendChild(t);
    setTimeout(() => {
      t.style.transition = 'opacity 300ms';
      t.style.opacity = '0';
      setTimeout(() => t.remove(), 300);
    }, 1000);
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
