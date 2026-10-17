# App Store listing: español (Puerto Rico)

Draft of the text for App Store Connect, Spanish. Nothing here is submitted or published. Each `### Campo` below has one `text` block: that block is exactly what gets pasted, and `Tests/AppResourceTests/StoreListingTests.swift` counts it against Apple's limits on every `swift test` (and checks the tone rules: never *monto*, no named IVU, no other brands, URLs and contact still marked TODO). The English listing is [en.md](en.md); both files must have the same fields.

Apple's limits (App Store Connect Help, "Platform version information" and "App information"): name 2 to 30 characters, subtitle 30, promotional text 170, description 4,000, what's new 4,000, keywords 100 bytes (accents count as 2 bytes), App Review notes 4,000 bytes.

**Which App Store Connect language?** Apple offers *Spanish (Mexico)* and *Spanish (Spain)* as metadata languages; there is no Puerto Rico entry. Put this text in *Spanish (Mexico)* (the Latin American Spanish slot) and check on a Spanish-language iPhone with a US storefront that it is the one shown. The English listing goes in *English (U.S.)*. Primary language of the app record: Spanish, to match the app's development language.

## Texto para App Store Connect

### App name

```text
Esplitéalo
```

### Subtitle

```text
Divide la cuenta sin bregar
```

### Promotional text

Editable at any time without a new review. Good place for seasonal copy.

```text
Escanea el recibo, marca quién pidió qué y comparte lo que le toca a cada cual. Funciona en cualquier iPhone, sin cuentas y con la matemática a la vista.
```

### Description

```text
Divide la cuenta del restaurante sin sacar la calculadora y sin armar un relajo.

Toma una foto del recibo, marca quién pidió qué y comparte lo que le toca a cada cual. Esplitéalo lee el recibo en tu iPhone y hace la matemática por ti, a la vista.

CÓMO FUNCIONA
1. Escanea el recibo con la cámara o elige una foto que ya tengas.
2. Chequea lo que leyó la app. Puedes arreglar, añadir o quitar artículos.
3. Añade a la gente de la mesa, solo con el nombre.
4. Marca quién pidió cada artículo. Si varios comparten un plato, se divide en partes iguales.
5. Escoge la propina y comparte el espliteo con el grupo.

LA MATEMÁTICA, A LA VISTA
• El impuesto y la propina se reparten en proporción a lo que pidió cada cual.
• Ves el desglose de cada persona: artículos, impuesto, propina y total.
• Si sobran centavos, la app te enseña a quién le tocó cada uno y por qué. Mismos datos, mismo resultado.
• Si los números no cuadran con el recibo, te avisa y no te deja compartir hasta que lo arregles. Nada se cambia a escondidas.

FUNCIONA EN CUALQUIER iPHONE
No necesitas cuenta ni una app de pagos. Esplitéalo calcula cuánto le toca a cada persona y tú lo compartes como texto por Mensajes, Notas o la app que prefieras.

PRIVADO DESDE EL DISEÑO
• Sin cuentas y sin registro.
• El recibo se lee en tu iPhone. La foto no sale del dispositivo y no se guarda.
• Sin anuncios, sin analíticas y sin rastreo.
• La cámara se usa solo para escanear recibos. Elegir una foto de tu biblioteca no requiere ningún permiso.

EN ESPAÑOL Y EN INGLÉS
Esplitéalo habla español de Puerto Rico y también inglés. Cambia de idioma en los Ajustes de tu iPhone.

Aviso: Esplitéalo calcula y muestra cuánto le toca a cada persona. No procesa pagos ni mueve dinero; cada cual paga como acuerde el grupo.
```

### Keywords

```text
recibo,restaurante,propina,impuesto,gastos,grupo,amigos,cuadrar,escáner,calculadora,comida
```

### What's new

```text
Primera versión de Esplitéalo. Escanea el recibo, marca quién pidió qué, escoge la propina y comparte lo que le toca a cada cual.
```

### Primary category

```text
Finanzas (Finance)
```

### Secondary category

```text
Utilidades (Utilities)
```

### Age rating

```text
4+. Todas las preguntas del cuestionario de Apple se contestan "Ninguna" (None). Detalle en docs/RELEASE_CHECKLIST.md.
```

### Support URL

```text
TODO: URL de soporte (por definir; un dominio del proyecto, no un correo personal)
```

### Marketing URL

```text
TODO: URL de mercadeo (opcional; por definir con el dominio del proyecto)
```

### Privacy policy URL

```text
TODO: URL pública de la política de privacidad (docs/PRIVACY_POLICY.md aún no está publicada)
```

### Contact

```text
TODO: contacto de soporte; es el mismo contacto pendiente en la política de privacidad (docs/PRIVACY_POLICY.md)
```

### Copyright

```text
TODO: año y nombre legal del titular (por definir al inscribirse en el Apple Developer Program)
```

### Review notes

Not localized in App Store Connect: App Review reads English. Paste the English text from [en.md](en.md). This is the same text in Spanish, for the owner to read.

```text
Esplitéalo divide la cuenta de un restaurante. No tiene cuentas, inicio de sesión, compras ni servidor. No hace falta una cuenta de prueba.

Cámara: se usa solo para escanear el recibo. El permiso se pide la primera vez que se toca "Escanear recibo", nunca antes. Elegir una foto con "Elegir foto" no requiere ningún permiso. El recibo se lee en el dispositivo con Vision y VisionKit; la foto no se envía a ningún lado ni se guarda. La app no usa la red.

Cómo probar con un recibo de muestra:
1. Guarda en Fotos la imagen adjunta "sample-receipt.jpg" (una foto de un recibo de restaurante).
2. Abre la app y toca "Elegir foto"; escoge esa imagen. También puedes tocar "Escanear recibo" y apuntar la cámara a cualquier recibo impreso.
3. En "Chequea el recibo" revisa los artículos, el impuesto y el total.
4. Añade dos o tres personas con solo el nombre.
5. En "Marcar artículos" toca cada artículo y escoge quién lo pidió.
6. En "Totales" escoge la propina y toca "Compartir espliteo" para ver el resumen en texto y la hoja de compartir de iOS.

La app no procesa pagos ni se conecta a apps de pagos: solo prepara un texto con lo que le toca pagar a cada persona.
```

## Notas de posicionamiento (no se pegan en App Store Connect)

Contexto: iOS 27 trae "Split Bill" dentro de Apple Cash. Esplitéalo no compite en pagos; compite en que **sirve para cualquier cuenta y cualquier iPhone**. Los puntos que sí podemos decir, todos ciertos hoy:

- Funciona en cualquier iPhone con iOS 18 o más reciente; no requiere Apple Cash, ni saldo, ni una cuenta.
- Enseña la matemática: desglose por persona, a dónde fue cada centavo suelto, y se niega a compartir si los números no cuadran con el recibo.
- Español de Puerto Rico de verdad (tono y vocabulario), no una traducción genérica.
- Lee el recibo en el teléfono y no guarda la foto.

Reglas para el texto público: no nombrar a otras marcas en las palabras clave ni en el resto del listado (la prueba lo vigila para las marcas de pago y de dividir cuentas); no decir que se integra con apps de pagos (ATH Móvil queda fuera del alcance); no afirmar nada sobre Apple Cash que no podamos comprobar. Apple suele objetar marcas de terceros en los metadatos (Guideline 2.3.7), así que el listado dice "no necesitas una app de pagos" y no "no necesitas Apple Cash".

**Decisión pendiente del dueño**: si se quiere nombrar a Apple Cash de forma explícita, la única variante razonable es el texto promocional (se cambia sin nueva revisión), por ejemplo: "Funciona en cualquier iPhone, sin Apple Cash." Confirmar el nombre y la función en la documentación de Apple vigente cuando iOS 27 esté publicado y asumir el riesgo de revisión.
