Requisitos prueba 1

    El estudiante debe mostrar en la plataforma cloud la creación de la instancia de API Manager en funcionamiento.
    El estudiante debe mostrar la configuración del API Manager que permite llamar a los endpoints del backend.
    El estudiante debe demostrar que el frontend consume los endpoints a través del API Manager correctamente configurado.
    El estudiante debe mostrar que el API Manager valida JWT, rechazando peticiones inválidas y aceptando las correctas.
    El estudiante debe mostrar la creación del tenant en IDaaS y la existencia de usuarios registrados.
    El estudiante debe demostrar que el frontend utiliza OAuth 2.0/OpenID Connect para iniciar sesión y obtener un JWT válido.
    El estudiante debe mostrar en la nube que el backend y el frontend están desplegados, activos e integrados.

Indicador de evaluación.

Crea todas las rutas necesarias para que el API Manager sirva como intermediario entre los endpoints del backend del sistema y el frontend. Todas las rutas están creadas y dirigidas correctamente a los microservicios correspondientes. La estructura de paths y métodos es coherente y está probada.

Configura CORS en el API Manager para permitir una comunicación adecuada con el frontend. CORS configurado de forma segura y funcional. Los orígenes permitidos están definidos correctamente y los métodos y encabezados necesarios están habilitados sin sobrepermisos.

Crea un tenant que dé soporte a los diferentes servicios del IDaaS que serán utilizados en el sistema. Tenant creado y configurado correctamente. Incluye usuarios de prueba, roles, políticas y parámetros que el sistema requiere.

Crea y configura correctamente la aplicación correspondiente dentro del tenant. La aplicación está registrada con clientId correcto. Las URIs de redirección están bien definidas. Los roles y scopes están configurados y el IDaaS expone la API del proyecto de manera adecuada.

Crea y configura el flujo de usuario necesario para que, desde el frontend, los usuarios puedan crear sus cuentas en el tenant y luego iniciar sesión, generando los tokens esperados El flujo de registro e inicio de sesión funciona completamente. Los usuarios pueden crear cuenta e iniciar sesión y el sistema obtiene tokens con los claims esperados.

Configura la aplicación y el flujo de usuario de modo que funcionen correctamente utilizando el flujo OIDC “Authorization Code con PKCE” Implementa el flujo Authorization Code con PKCE correctamente. El sistema genera code verifier y code challenge adecuados. Valida parámetros de seguridad como state y nonce

Configura correctamente todas las rutas del API Manager para que, mediante un JWT, se valide el acceso a cada uno de los endpoints del sistema. Todas las rutas aplican la validación JWT. El API Manager verifica issuer y audience correctamente y las pruebas muestran respuestas 200 401 y 403 coherentes

Evidencia el funcionamiento de cada ruta y cómo estas llaman correctamente al backend correspondiente y devuelven el JSON esperado. Entrega evidencias completas del funcionamiento de todas las rutas. Muestra llamadas con y sin token y confirma que los microservicios responden con el JSON esperado
