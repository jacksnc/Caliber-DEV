/* Design-only state/navigation glue. No storage, analytics or network. */
(() => {
  const query = new URLSearchParams(location.search);
  const root = document.documentElement;
  root.dataset.theme = query.get('theme') === 'light' ? 'light' : 'dark';
  const states = ['populated','empty','no-goals','long-name','number-free','locked','opted-out'];
  root.dataset.state = states.includes(query.get('state')) ? query.get('state') : 'populated';
  if (query.get('glass') === 'reduced') root.dataset.glass = 'reduced';
  if (query.get('contrast') === 'more') root.dataset.contrast = 'more';
  const scale = [1, 2, 3].includes(Number(query.get('scale'))) ? Number(query.get('scale')) : 1;
  root.style.fontSize = `${16 * scale}px`;
  root.dataset.scale = String(scale);
  const screen = document.body.dataset.screen;
  const activeTab = screen === 'food-entry' || screen === 'food-review' ? 'diary' : screen;
  const preservePreview = url => {
    for (const key of ['theme','scale','state','glass','contrast']) {
      if (!url.searchParams.has(key) && query.has(key)) url.searchParams.set(key,query.get(key));
    }
    url.searchParams.set('theme',root.dataset.theme);
    return url;
  };
  const titles = {today:'Today',train:'Train',diary:'Diary',stack:'Stack',progress:'Progress','food-entry':'Add food','food-review':'Review food'};
  const names = {today:'Today',train:'Train',diary:'Fuel',stack:'Stack',progress:'Progress'};
  const paths = {today:'M3 11 12 3l9 8v10h-6v-7H9v7H3Z', train:'M3 8v8m4-11v14m10-14v14m4-11v8M7 12h10',diary:'M7 3v7m-3-7v7m6-7v7m-3 0v11M19 3v18m0-18c-4 2-4 8 0 8',stack:'M12 3 3 8l9 5 9-5-9-5ZM3 12l9 5 9-5M3 16l9 5 9-5',progress:'M3 3v18h18M6 16l5-5 4 2 6-8'};
  const header = document.querySelector('.app-header');
  if (header) header.innerHTML = `<div><p class="eyebrow">Caliber · ${root.dataset.theme === 'light' ? 'Frost' : 'Graphite'}</p><h1>${titles[screen] || 'Caliber'}</h1></div><button class="avatar" aria-label="Profile preview">C</button>`;
  const nav = document.querySelector('.app-nav');
  if (nav) {
    nav.setAttribute('aria-label','Main tabs');
    const tabs = Object.keys(names).filter(key => key !== 'stack' || root.dataset.state !== 'opted-out');
    nav.innerHTML = tabs.map(key => `<a href="${key}.html" ${key === activeTab ? 'aria-current="page"' : ''}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[key]}"/></svg><span>${names[key]}</span></a>`).join('');
    // Keep CSS in charge of large-text reflow; this custom count only affects the default tab row.
    nav.style.setProperty('--tab-count',String(tabs.length));
    nav.querySelectorAll('a').forEach(el => { el.href = preservePreview(new URL(el.href)).href; });
  }
  const skip = document.createElement('a'); skip.href = '#main'; skip.className = 'skip-link'; skip.textContent = 'Skip to content'; document.body.prepend(skip);
  const demo = {...window.CALIBER_DEMO};
  if (screen === 'food-review') {
    const food = demo.foods[query.get('food')] || demo.foods.bowl;
    Object.assign(demo,{bowlName:food.name,bowlLongName:`${food.name} with roasted seasonal vegetables, a choice of toppings and a side dressing`,bowlServing:food.serving,bowlEnergy:food.energy,bowlProtein:food.protein,bowlCarbs:food.carbs,bowlFat:food.fat});
    document.querySelectorAll('[data-mass-only]').forEach(el => { el.hidden = !food.massKnown; });
  }
  document.querySelectorAll('[data-demo]').forEach(el => {
    const value = demo[el.dataset.demo];
    if (value === undefined) return;
    if (['INPUT','SELECT','TEXTAREA'].includes(el.tagName)) el.value = value; else el.textContent = value;
  });
  // SVG groups do not reflect an assigned .hidden property like HTML elements do.
  // Use the attribute so the shared CSS hides both kinds from rendering and AX.
  document.querySelectorAll('[data-state-only]').forEach(el => { el.toggleAttribute('hidden',!el.dataset.stateOnly.split(' ').includes(root.dataset.state)); });
  document.querySelectorAll('[data-state-except]').forEach(el => { el.toggleAttribute('hidden',el.dataset.stateExcept.split(' ').includes(root.dataset.state)); });
  const meals = ['Breakfast','Lunch','Dinner','Snacks'];
  let meal = meals.includes(query.get('meal')) ? query.get('meal') : 'Lunch';
  function showMeal() {
    document.querySelectorAll('[data-context-meal]').forEach(el => { if (el.tagName === 'SELECT') el.value = meal.toLowerCase(); else if (el.tagName === 'INPUT') el.value = meal; else el.textContent = meal; });
    document.querySelectorAll('[data-meal-pill]').forEach(el => el.setAttribute('aria-pressed',String(el.dataset.mealPill === meal)));
  }
  function changeMeal(next) {
    if (!meals.includes(next)) return;
    meal = next; showMeal();
    document.querySelectorAll('a[data-board-link]').forEach(el => { const url = new URL(el.href); url.searchParams.set('meal',meal); el.href = url.href; });
  }
  showMeal();
  document.querySelectorAll('[data-meal-pill]').forEach(el => el.addEventListener('click',() => changeMeal(el.dataset.mealPill)));
  document.querySelectorAll('select[data-context-meal]').forEach(el => el.addEventListener('change',() => changeMeal(meals.find(name => name.toLowerCase() === el.value))));
  document.querySelectorAll('a[data-board-link]').forEach(el => { const url = preservePreview(new URL(el.href)); if (!url.searchParams.has('meal')) url.searchParams.set('meal',meal); el.href = url.href; });
  const chart = document.querySelector('.trend-chart');
  if (chart && root.dataset.state === 'number-free') {
    document.getElementById('chart-desc').textContent = 'The shape of your recorded trend, with weight values hidden. No cause is inferred.';
  }
  const note = document.createElement('p'); note.className = 'preview-note'; note.id = 'preview-status'; note.setAttribute('role','status'); note.textContent = 'Design preview · fictional data · nothing is saved'; document.body.append(note);
  document.querySelectorAll('button').forEach(el => el.addEventListener('click',() => { note.textContent = `${el.getAttribute('aria-label') || el.textContent.trim()} — design preview; nothing was saved.`; }));
  document.querySelectorAll('form').forEach(el => el.addEventListener('submit',event => { event.preventDefault(); note.textContent = 'Review preview complete; nothing was saved.'; }));
})();
