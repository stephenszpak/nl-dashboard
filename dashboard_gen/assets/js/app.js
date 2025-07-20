import "./phx"

// Focus input when prompt is selected
window.addEventListener("phx:focus_input", () => {
  const input = document.getElementById("prompt-input");
  if (input) {
    input.focus();
    // Move cursor to end of text
    input.setSelectionRange(input.value.length, input.value.length);
  }
});
