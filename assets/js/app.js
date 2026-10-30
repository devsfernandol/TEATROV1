/**
 * Mejoras progresivas: la aplicación funciona igual sin JavaScript.
 */
(function () {
    'use strict';

    // Evita el doble envío del formulario de compra deshabilitando el botón.
    document.querySelectorAll('form[data-envio-unico]').forEach(function (formulario) {
        formulario.addEventListener('submit', function (evento) {
            if (formulario.dataset.enviando === '1') {
                evento.preventDefault();
                return;
            }
            formulario.dataset.enviando = '1';

            var boton = formulario.querySelector('button[type="submit"]');
            if (boton) {
                boton.disabled = true;
                boton.setAttribute('aria-busy', 'true');
                if (boton.dataset.textoEnvio) {
                    boton.dataset.textoOriginal = boton.textContent;
                    boton.textContent = boton.dataset.textoEnvio;
                }
            }
        });
    });

    // Botón de imprimir: oculto por defecto, solo se muestra si hay JavaScript.
    document.querySelectorAll('[data-imprimir]').forEach(function (boton) {
        boton.hidden = false;
        boton.addEventListener('click', function () {
            window.print();
        });
    });

    // Si el usuario vuelve con el botón "Atrás", el formulario se reactiva.
    window.addEventListener('pageshow', function (evento) {
        if (!evento.persisted) {
            return;
        }
        document.querySelectorAll('form[data-envio-unico]').forEach(function (formulario) {
            formulario.dataset.enviando = '';
            var boton = formulario.querySelector('button[type="submit"]');
            if (boton) {
                boton.disabled = false;
                boton.removeAttribute('aria-busy');
                if (boton.dataset.textoOriginal) {
                    boton.textContent = boton.dataset.textoOriginal;
                }
            }
        });
    });
})();
