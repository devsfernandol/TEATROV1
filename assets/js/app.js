/**
 * Mejora progresiva: la aplicación funciona igual sin JavaScript.
 * Evita el doble envío del formulario de compra deshabilitando el botón.
 */
(function () {
    'use strict';

    function reactivar(formulario) {
        formulario.dataset.enviando = '';
        var boton = formulario.querySelector('button[type="submit"]');
        if (boton) {
            boton.disabled = false;
            boton.removeAttribute('aria-busy');
            if (boton.dataset.textoOriginal) {
                boton.textContent = boton.dataset.textoOriginal;
            }
        }
    }

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

    // Si el usuario vuelve con el botón "Atrás", el formulario se reactiva.
    window.addEventListener('pageshow', function (evento) {
        if (evento.persisted) {
            document.querySelectorAll('form[data-envio-unico]').forEach(reactivar);
        }
    });
})();
