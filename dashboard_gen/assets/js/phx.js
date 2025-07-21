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
