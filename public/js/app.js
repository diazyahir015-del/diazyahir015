(function initGlobalUi() {
  const yearNode = document.getElementById('year');
  if (yearNode) {
    yearNode.textContent = new Date().getFullYear();
  }
})();

function setMessage(node, text, type) {
  if (!node) return;
  node.textContent = text;
  node.classList.remove('success', 'error');
  if (type) {
    node.classList.add(type);
  }
}

const registerForm = document.getElementById('registerForm');
if (registerForm) {
  registerForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const messageNode = document.getElementById('registerMessage');

    const fullName = registerForm.fullName.value.trim();
    const email = registerForm.email.value.trim();
    const password = registerForm.password.value;

    try {
      const response = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullName, email, password })
      });

      const result = await response.json();
      if (!response.ok) {
        setMessage(messageNode, result.message || 'No se pudo registrar.', 'error');
        return;
      }

      setMessage(messageNode, 'Cuenta creada con éxito. Redirigiendo a login...', 'success');
      setTimeout(() => {
        window.location.href = '/login.html';
      }, 1200);
    } catch {
      setMessage(messageNode, 'Error de conexión con el servidor.', 'error');
    }
  });
}

const loginForm = document.getElementById('loginForm');
if (loginForm) {
  loginForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const messageNode = document.getElementById('loginMessage');

    const email = loginForm.email.value.trim();
    const password = loginForm.password.value;

    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });

      const result = await response.json();
      if (!response.ok) {
        setMessage(messageNode, result.message || 'No se pudo iniciar sesión.', 'error');
        return;
      }

      localStorage.setItem('dcNexusUser', JSON.stringify(result.user));
      setMessage(messageNode, 'Inicio de sesión exitoso. Redirigiendo...', 'success');
      setTimeout(() => {
        window.location.href = '/dashboard.html';
      }, 800);
    } catch {
      setMessage(messageNode, 'Error de conexión con el servidor.', 'error');
    }
  });
}

const dashboardUserName = document.getElementById('userName');
if (dashboardUserName) {
  const storedUser = localStorage.getItem('dcNexusUser');
  if (!storedUser) {
    window.location.href = '/login.html';
  } else {
    const user = JSON.parse(storedUser);
    dashboardUserName.textContent = user.fullName || 'Usuario';
  }

  const logoutBtn = document.getElementById('logoutBtn');
  logoutBtn?.addEventListener('click', () => {
    localStorage.removeItem('dcNexusUser');
    window.location.href = '/login.html';
  });
}

const documentForm = document.getElementById('documentForm');
if (documentForm) {
  const config = {
    'acta-nacimiento': {
      title: 'Acta de nacimiento',
      description: 'Captura la información base de registro civil para solicitar tu acta.',
      fields: [
        { label: 'Nombre del padre', name: 'fatherName', type: 'text' },
        { label: 'Nombre de la madre', name: 'motherName', type: 'text' },
        { label: 'Número de libro (si lo tienes)', name: 'bookNumber', type: 'text' },
        { label: 'Número de acta (si lo tienes)', name: 'recordNumber', type: 'text' }
      ]
    },
    curp: {
      title: 'CURP',
      description: 'Proporciona la información personal para validación y generación de CURP.',
      fields: [
        { label: 'Sexo', name: 'gender', type: 'text' },
        { label: 'Entidad de nacimiento', name: 'birthState', type: 'text' },
        { label: 'Primer apellido', name: 'lastName1', type: 'text' },
        { label: 'Segundo apellido', name: 'lastName2', type: 'text' }
      ]
    }
  };

  const params = new URLSearchParams(window.location.search);
  const docType = params.get('doc');
  const selected = config[docType] || config['acta-nacimiento'];

  const titleNode = document.getElementById('docTitle');
  const descriptionNode = document.getElementById('docDescription');
  const specificFieldsNode = document.getElementById('specificFields');

  if (titleNode) titleNode.textContent = selected.title;
  if (descriptionNode) descriptionNode.textContent = selected.description;

  if (specificFieldsNode) {
    specificFieldsNode.innerHTML = selected.fields
      .map(
        (field) => `
        <div>
          <label for="${field.name}">${field.label}</label>
          <input id="${field.name}" name="${field.name}" type="${field.type}" required />
        </div>
      `
      )
      .join('');
  }

  documentForm.addEventListener('submit', (event) => {
    event.preventDefault();
    const messageNode = document.getElementById('docFormMessage');
    setMessage(messageNode, 'Solicitud enviada correctamente. Te contactaremos por WhatsApp o correo.', 'success');
    documentForm.reset();
  });
}
