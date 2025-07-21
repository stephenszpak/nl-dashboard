import "./phx"

// Focus input when prompt is selected
window.addEventListener("phx:focus_input", () => {
  const input = document.getElementById("prompt-input");
  if (input) {
    // Add visual feedback animation
    input.classList.add("ring-2", "ring-blue-500", "ring-opacity-50");
    
    // Focus and position cursor
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
    
    // Remove animation after 2 seconds
    setTimeout(() => {
      input.classList.remove("ring-2", "ring-blue-500", "ring-opacity-50");
    }, 2000);
  }
});

// Handle focus event for message input
window.addEventListener("phx:focus", (e) => {
  const input = document.querySelector(e.detail.to);
  if (input) {
    // Add visual feedback animation
    input.classList.add("ring-2", "ring-blue-500", "ring-opacity-50");
    
    // Focus and position cursor
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
    
    // Remove animation after 2 seconds
    setTimeout(() => {
      input.classList.remove("ring-2", "ring-blue-500", "ring-opacity-50");
    }, 2000);
  }
});
