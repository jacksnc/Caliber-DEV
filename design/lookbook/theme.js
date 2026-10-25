// Lets a look-book page be opened as board.html?theme=light&contrast=more&glass=reduced.
// The theme applies to every board on the page; contrast and glass apply to the outer board only.
(() => {
  const query = new URLSearchParams(location.search);
  const boards = document.querySelectorAll(".hx");
  if (!boards.length) return;
  const theme = query.get("theme");
  if (theme === "light" || theme === "dark") boards.forEach((board) => { board.dataset.theme = theme; });
  if (query.get("contrast") === "more") boards[0].dataset.contrast = "more";
  if (query.get("glass") === "reduced") boards[0].dataset.glass = "reduced";
  document.body.style.background = getComputedStyle(boards[0]).getPropertyValue("--canvas-bottom");
})();
