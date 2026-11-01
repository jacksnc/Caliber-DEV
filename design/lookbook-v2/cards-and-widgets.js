(() => {
  const root = document.documentElement;
  const carousel = document.querySelector('#nutrition-carousel');
  const slides = Array.from(document.querySelectorAll('.metric-slide'));
  const pageNumber = document.querySelector('[data-current-page]');
  const themeButtons = document.querySelectorAll('[data-theme-choice]');
  const privacyButton = document.querySelector('#privacy-toggle');
  let current = 0;
  let start = null;

  const showPage = (next) => {
    current = (next + slides.length) % slides.length;
    for (const [index, slide] of slides.entries()) {
      slide.hidden = index !== current;
    }
    pageNumber.textContent = String(current + 1).padStart(2, '0');
  };

  carousel.addEventListener('pointerdown', (event) => {
    if (event.target.closest('button')) return;
    start = { x: event.clientX, y: event.clientY, id: event.pointerId };
  });
  carousel.addEventListener('pointerup', (event) => {
    if (!start || event.pointerId !== start.id) return;
    const dx = event.clientX - start.x;
    const dy = event.clientY - start.y;
    start = null;
    if (Math.abs(dx) < 44 || Math.abs(dx) < Math.abs(dy) * 1.25) return;
    showPage(current + (dx < 0 ? 1 : -1));
  });
  carousel.addEventListener('pointercancel', () => { start = null; });
  carousel.addEventListener('keydown', (event) => {
    if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return;
    event.preventDefault();
    showPage(current + (event.key === 'ArrowRight' ? 1 : -1));
  });
  document.querySelectorAll('[data-move]').forEach((button) => {
    button.addEventListener('click', () => showPage(current + Number(button.dataset.move)));
  });

  themeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const graphite = button.dataset.themeChoice === 'graphite';
      root.dataset.theme = graphite ? 'dark' : 'light';
      themeButtons.forEach((choice) => choice.setAttribute(
        'aria-pressed', String(choice === button)));
    });
  });

  privacyButton.addEventListener('click', () => {
    const locked = privacyButton.getAttribute('aria-pressed') !== 'true';
    privacyButton.setAttribute('aria-pressed', String(locked));
    privacyButton.textContent = locked ? 'On' : 'Off';
    privacyButton.setAttribute('aria-label', locked
      ? 'Preview locked-device privacy, on' : 'Preview locked-device privacy, off');
    document.body.dataset.private = locked ? 'locked' : 'visible';
  });
})();
