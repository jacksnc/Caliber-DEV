/* The book composes independent native-screen design boards. */
(() => {
  const names = {diary:'Fuel / Diary',today:'Today',train:'Train',stack:'Stack',progress:'Progress','food-entry':'Add food','food-review':'Review food'};
  const controls = document.querySelector('.book-controls');
  function render() {
    const values = Object.fromEntries([...controls.querySelectorAll('select')].map(el => [el.id,el.value]));
    const screens = values.screen === 'all' ? ['today','train','diary','stack','progress'] : [values.screen];
    const container = document.getElementById('boards'); container.replaceChildren();
    for (const screen of screens) for (const theme of ['dark','light']) {
      const params = new URLSearchParams({theme,state:values.state,scale:values.scale,glass:values.glass,contrast:values.contrast});
      const url = `${screen}.html?${params}`;
      const fig = document.createElement('figure'); fig.className = 'book-board'; fig.style.width = `${Number(values.width) + 2}px`;
      const caption = document.createElement('figcaption');
      const title = document.createElement('h3'); title.textContent = `${names[screen]} · ${theme === 'dark' ? 'Graphite' : 'Frost'}`;
      const link = document.createElement('a'); link.href = url; link.target = '_blank'; link.rel = 'noopener'; link.textContent = 'Open board ↗';
      caption.append(title,link);
      const frame = document.createElement('div'); frame.className = 'book-frame';
      const iframe = document.createElement('iframe'); iframe.src = url; iframe.title = title.textContent; iframe.loading = 'lazy'; iframe.style.width = `${values.width}px`;
      frame.append(iframe); fig.append(caption,frame); container.append(fig);
    }
  }
  controls.addEventListener('change',render); controls.addEventListener('submit',event => event.preventDefault()); render();
})();
