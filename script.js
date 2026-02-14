const yearElement = document.getElementById('year');
const hero = document.querySelector('[data-hero]');

if (yearElement) {
  yearElement.textContent = new Date().getFullYear();
}

const heroImages = [
  'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=1800&q=80',
  'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=1800&q=80',
  'https://images.unsplash.com/photo-1600878459108-617a253537e9?auto=format&fit=crop&w=1800&q=80',
  'https://images.unsplash.com/photo-1586717791821-3f44a563fa4c?auto=format&fit=crop&w=1800&q=80',
];

let currentImageIndex = 0;

function updateHeroBackground() {
  if (!hero) {
    return;
  }

  hero.style.backgroundImage = `url("${heroImages[currentImageIndex]}")`;
}

if (hero) {
  updateHeroBackground();

  setInterval(() => {
    currentImageIndex = (currentImageIndex + 1) % heroImages.length;
    updateHeroBackground();
  }, 5000);
}
