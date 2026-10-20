import type { Metadata } from "next";
import { type Tool, costOver, tools } from "../../_components/competitors";
import { RhinoMark, rhinoPrice } from "../../_components/site-chrome";

const site = "https://rhinovoice.app";
const slug = "/es/alternativas-a-wispr-flow";
const englishSlug = "/alternatives/wispr-flow";

/** costOver() speaks English ("about $102"); this page says "unos $102". */
const coste = (tool: Tool, years: number) => costOver(tool.cost, years).replace("about ", "unos ");

const wisprYear = coste(tools.wisprFlow, 1);
const typelessYear = coste(tools.typeless, 1);

type Entrada = {
  tool: Tool;
  badge?: string;
  idealPara: string;
  precioCorto: string;
  precio: string;
  donde: string;
  review: string[];
};

const entradas: Entrada[] = [
  {
    tool: tools.rhino,
    badge: "Mejor precio",
    idealPara: "dictado local que pagas una sola vez",
    precioCorto: `Gratis, o $${rhinoPrice} una vez`,
    precio: `Gratis para empezar (tu primera semana ilimitada, después 2,000 palabras por semana). Ilimitado: $${rhinoPrice} una sola vez, con 30 días para pedir tu dinero de vuelta.`,
    donde: "En tu Mac, siempre. La app no tiene opción de nube.",
    review: [
      "Hice Rhino para quedarme con el gesto de Wispr Flow (mantienes una tecla, hablas, sueltas) sin la nube y sin la suscripción. El reconocimiento de voz y la limpieza con IA corren en tu Mac, funciona con el Wi-Fi apagado y no necesitas cuenta.",
      "Es pequeño a propósito: sin modos ni perfiles por app. Deja el texto tal cual cuando dictas en Claude, ChatGPT o una terminal, y guarda un diccionario con los nombres que repites. Funciona en Macs con Apple silicon y macOS 14 o posterior.",
    ],
  },
  {
    tool: tools.superwhisper,
    idealPara: "salir de la nube sin pagar",
    precioCorto: "Gratis, Pro unos $8.49/mes",
    precio: "Plan gratis. Pro desde unos $8.49 al mes, con opción de licencia de por vida.",
    donde: "En tu Mac, si eliges modelos locales",
    review: [
      "Si dejas Wispr Flow porque no quieres tu voz en un servidor, superwhisper lo resuelve hoy sin pagar nada. Su plan gratis usa modelos Whisper en tu Mac y funciona sin conexión, y no es una prueba de tres días. Elígelo si quieres probar el dictado local antes de pagarle a nadie, nosotros incluidos.",
    ],
  },
  {
    tool: tools.voiceInk,
    idealPara: "quien quiere poder leer el código",
    precioCorto: "$25 una vez",
    precio: "Licencias de por vida desde $25. Gratis si lo compilas tú.",
    donde: "En tu Mac",
    review: [
      "Código abierto, hecho sobre whisper.cpp y vendido como licencia única. Su Power Mode, que hace que tu editor y tu correo se comporten distinto, es una buena idea que casi nadie más ha copiado. Elígelo si el código abierto te importa.",
    ],
  },
  {
    tool: tools.appleDictation,
    idealPara: "saber si de verdad necesitas pagar",
    precioCorto: "Gratis",
    precio: "Gratis, viene con macOS.",
    donde: "En tu Mac, en Apple silicon con el dictado en el dispositivo activado",
    review: [
      "Actívalo antes de comprar nada. Ya está instalado, funciona en el dispositivo y en un Mac con Intel es la única opción local de esta lista que corre. Si hablas en frases limpias y terminadas, quizá no necesitas más. Si piensas en voz alta, vas a gastar el tiempo que ahorraste corrigiendo.",
    ],
  },
  {
    tool: tools.aquaVoice,
    idealPara: "seguir en la nube pagando menos",
    precioCorto: "$8/mes (anual)",
    precio: "1,000 palabras gratis para empezar. Pro a $8 al mes con pago anual.",
    donde: "En su nube",
    review: [
      "Si te molestaba el precio y no la nube, este es el cambio obvio: cuesta alrededor de un tercio menos que Wispr Flow, con un acabado parecido. Sé honesto contigo sobre cuál de los dos problemas tienes en realidad.",
    ],
  },
  {
    tool: tools.typeless,
    idealPara: "la mayor precisión, en todos tus dispositivos",
    precioCorto: "$12/mes (anual)",
    precio: "Plan gratis con un límite semanal de palabras. Pro a $12 al mes con pago anual.",
    donde: "En su nube",
    review: [
      `La app más precisa que probé. Con mi voz acertó 10 de 10 clips sin corregir nada, contra 8 de 10 de Rhino. También cuesta más: ${typelessYear} al año en Pro con pago anual, contra $${rhinoPrice} una vez de Rhino. Tiene apps para Mac, Windows, iPhone y Android. Elígela si la precisión es lo primero y la nube no te molesta.`,
    ],
  },
  {
    tool: tools.macWhisper,
    idealPara: "transcribir archivos, no dictar en vivo",
    precioCorto: "Gratis, Pro unos €59 una vez",
    precio: "Plan gratis. Pro es una licencia única de unos €59 en Gumroad.",
    donde: "En tu Mac",
    review: [
      "Mucha gente que busca una app de dictado en realidad necesita esta. MacWhisper convierte en texto las grabaciones que ya tienes, con etiquetas de quién habla y exportación de subtítulos. Elígela si tu trabajo empieza con un archivo de audio.",
    ],
  },
];

const costeTools = [
  tools.rhino,
  tools.wisprFlow,
  tools.superwhisper,
  tools.voiceInk,
  tools.aquaVoice,
  tools.typeless,
  tools.macWhisper,
  tools.appleDictation,
];

const pasos = [
  "Descarga Rhino gratis para tu Mac.",
  "En Ajustes, elige Español como idioma de transcripción, o deja que detecte el idioma solo.",
  "Elige tu tecla. Fn funciona, y Rhino apaga el panel de emojis que normalmente abre.",
  "Agrega al diccionario los nombres y términos que dices todos los días.",
  "Cierra Wispr Flow y cancela la suscripción cuando estés contento.",
];

const preguntas = [
  {
    question: "¿Cuál es la mejor alternativa a Wispr Flow?",
    answer: `Para dictar sin que tu voz salga de tu Mac y sin suscripción, Rhino Voice: gratis para empezar y $${rhinoPrice} una vez para uso ilimitado. Para una opción local gratis, superwhisper. Para la mayor precisión en mi prueba, Typeless. Para pagar menos en la nube, Aqua Voice. Para transcribir grabaciones, MacWhisper.`,
  },
  {
    question: "¿Por qué dejaría Wispr Flow?",
    answer: `Salen dos razones. La suscripción cuesta $15 al mes, o ${wisprYear} al año con el plan anual. Y lo que dictas se procesa en los servidores de Wispr Flow, algo que importa en conversaciones con clientes, notas médicas, borradores legales o trabajo que todavía no es público.`,
  },
  {
    question: "¿Hay alguna alternativa gratis a Wispr Flow?",
    answer:
      "Sí. Rhino es gratis para empezar: tu primera semana es ilimitada y después tienes 2,000 palabras por semana. El plan gratis de superwhisper usa modelos Whisper en tu Mac, VoiceInk es gratis si lo compilas tú y el Dictado de Apple ya viene instalado.",
  },
  {
    question: "¿Rhino funciona en español?",
    answer:
      "Sí. Rhino transcribe español en tu Mac con modelos Whisper; eliges Español en Ajustes o dejas que detecte el idioma. La interfaz de la app está traducida al español en su mayor parte. Algunos extras, como el formato automático de números, por ahora solo funcionan en inglés.",
  },
  {
    question: "¿Cuál es la alternativa más privada?",
    answer:
      "Las que nunca envían tu audio: el Dictado de Apple con el dictado en el dispositivo activado, superwhisper y VoiceInk con modelos locales, y Rhino Voice, que no tiene ninguna vía a la nube dentro de la app. Aqua Voice y Typeless son servicios en la nube.",
  },
  {
    question: "¿Alguna funciona sin internet?",
    answer:
      "El Dictado de Apple, superwhisper, VoiceInk, MacWhisper y Rhino Voice transcriben en tu Mac y siguen funcionando sin conexión una vez descargados sus modelos. Wispr Flow, Aqua Voice y Typeless necesitan conexión.",
  },
];

function anchor(tool: Tool) {
  return tool.key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
}

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Article",
      headline: "Las 7 mejores alternativas a Wispr Flow en 2026",
      inLanguage: "es",
      url: `${site}${slug}`,
      author: {
        "@type": "Person",
        name: "Noah Kagan",
        jobTitle: "Fundador",
        worksFor: { "@type": "Organization", name: "Rhino Voice", url: site },
      },
      publisher: { "@type": "Organization", name: "Rhino Voice", url: site },
    },
    {
      "@type": "ItemList",
      itemListElement: entradas.map((entrada, index) => ({
        "@type": "ListItem",
        position: index + 1,
        name: entrada.tool.name,
      })),
    },
    {
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Rhino", item: `${site}/` },
        { "@type": "ListItem", position: 2, name: "Alternativas a Wispr Flow", item: `${site}${slug}` },
      ],
    },
    {
      "@type": "FAQPage",
      inLanguage: "es",
      mainEntity: preguntas.map((entry) => ({
        "@type": "Question",
        name: entry.question,
        acceptedAnswer: { "@type": "Answer", text: entry.answer },
      })),
    },
  ],
};

function Descargar({ compact = false }: { compact?: boolean }) {
  return (
    <a className={compact ? "button button-compact" : "button button-primary"} href="/get">
      {compact ? "Descargar gratis" : "Descargar Rhino gratis"}
    </a>
  );
}

export const metadata: Metadata = {
  title: "Las 7 mejores alternativas a Wispr Flow en 2026 (con precios)",
  description:
    "Las 7 mejores alternativas a Wispr Flow en 2026, ordenadas por un competidor: apps que dejan tu voz en tu Mac, apps en la nube más baratas y cuánto cuesta cada una en uno y tres años.",
  alternates: {
    canonical: `${site}${slug}`,
    languages: { en: `${site}${englishSlug}`, es: `${site}${slug}`, "x-default": `${site}${englishSlug}` },
  },
  openGraph: {
    type: "article",
    locale: "es_419",
    url: `${site}${slug}`,
    title: "Las 7 mejores alternativas a Wispr Flow en 2026",
    description: "Apps locales, apps en la nube más baratas y la que hice yo. Ordenadas, con precios reales.",
  },
};

export default function Page() {
  return (
    <div className="doc-page" lang="es">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <a className="skip-link" href="#main">
        Ir al contenido
      </a>

      <header className="site-header">
        <a className="brand" href="/" aria-label="Inicio de Rhino">
          <RhinoMark />
          <span>Rhino Voice</span>
        </a>
        <nav aria-label="Navegación principal">
          <a href={englishSlug} hrefLang="en" lang="en">
            English
          </a>
          <Descargar compact />
        </nav>
      </header>

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Ruta de navegación">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>Alternativas a Wispr Flow</span>
        </nav>

        <h1>Las 7 mejores alternativas a Wispr Flow en 2026</h1>
        <div className="byline">
          <div className="byline-who">
            <img src="/img/noah.jpg" alt="Noah Kagan" width={44} height={44} />
            <div>
              <div className="byline-name">Noah Kagan</div>
              <div className="byline-role">Fundador de Rhino</div>
            </div>
          </div>
          <div className="byline-date">Precios revisados en octubre de 2026</div>
        </div>

        <aside className="answer-box">
          <h2>Respuesta rápida</h2>
          <p>
            Rhino Voice es la mejor alternativa a Wispr Flow si quieres dictar sin que tu voz
            salga de tu Mac y sin pagar cada mes: es gratis para empezar y el uso ilimitado
            cuesta ${rhinoPrice} una sola vez, frente a los {wisprYear} al año de Wispr Flow.
            Elige Typeless si lo que más te importa es la precisión: en mi prueba acertó 10 de
            10, contra 8 de 10 de Rhino. Elige superwhisper para dictar en local gratis, Aqua
            Voice para pagar menos en la nube y MacWhisper para transcribir archivos.
          </p>
        </aside>

        <div className="top-cta">
          <Descargar />
          <span>Gratis para empezar. Ilimitado: ${rhinoPrice} una sola vez.</span>
        </div>
        <p className="checked-note">
          <a href={englishSlug} hrefLang="en" lang="en">
            Read this page in English
          </a>
        </p>

        <div className="intro">
          <p>
            Wispr Flow es una buena app. La gente la deja por dos razones distintas. Cuesta $15
            al mes, o {wisprYear} al año con el plan anual, por algo que un Mac con Apple
            silicon ya puede hacer solo. Y lo que dictas se procesa en sus servidores, algo que
            importa cuando dictas notas de clientes, notas médicas o trabajo que todavía no es
            público.
          </p>
          <p>Yo hago Rhino, así que aparece primero. Cada app de la lista dice en qué nos gana.</p>
          <p>
            Sobre el español: Rhino transcribe español en tu Mac con modelos Whisper. Puedes
            elegir Español o dejar que detecte el idioma solo. La interfaz está traducida al
            español en su mayor parte, y algunos extras, como el formato automático de números,
            por ahora solo funcionan en inglés.
          </p>
        </div>

        <div className="table-wrap">
          <table className="compare-table rank-table">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">App</th>
                <th scope="col">Ideal para</th>
                <th scope="col">Precio</th>
              </tr>
            </thead>
            <tbody>
              {entradas.map((entrada, index) => (
                <tr key={entrada.tool.key} className={entrada.badge ? "rank-ours" : undefined}>
                  <td data-label="Puesto">{index + 1}</td>
                  <th scope="row">
                    <a href={`#${anchor(entrada.tool)}`}>{entrada.tool.name}</a>
                    {entrada.badge ? <span className="mine-badge">{entrada.badge}</span> : null}
                  </th>
                  <td data-label="Ideal para">{entrada.idealPara}</td>
                  <td data-label="Precio">{entrada.precioCorto}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="checked-note">
          Ordenadas para una persona que escribe en un Mac con Apple silicon y quiere dejar de
          pagar cada mes, dejar de enviar su audio a un servidor, o las dos cosas.
        </p>

        {entradas.map((entrada, index) => (
          <section
            key={entrada.tool.key}
            id={anchor(entrada.tool)}
            className={entrada.badge ? "tool-card tool-card-ours" : "tool-card"}
          >
            <h2>
              <span className="tool-num">{String(index + 1).padStart(2, "0")}</span> {entrada.tool.name}
              {entrada.badge ? <span className="mine-badge">{entrada.badge}</span> : null}
            </h2>
            <p className="tool-best">Ideal para: {entrada.idealPara}</p>
            <dl className="pick-meta">
              <div>
                <dt>Precio</dt>
                <dd>{entrada.precio}</dd>
              </div>
              <div>
                <dt>Dónde se procesa tu voz</dt>
                <dd>{entrada.donde}</dd>
              </div>
            </dl>
            {entrada.review.map((paragraph) => (
              <p key={paragraph.slice(0, 40)}>{paragraph}</p>
            ))}
            {entrada.badge ? (
              <figure className="tool-shot">
                <img
                  src="/img/rhino-home.jpg"
                  alt="La pantalla de inicio de Rhino Voice con el tiempo de dictado, las palabras dictadas y la velocidad media"
                  width={1200}
                  height={705}
                  loading="lazy"
                />
                <figcaption>La pantalla de inicio de Rhino. Todo lo que cuenta se queda en tu Mac.</figcaption>
              </figure>
            ) : null}
            <div className="tool-links">
              {entrada.badge ? <Descargar /> : null}
              {entrada.tool.site ? (
                <a className="inline-link" href={entrada.tool.site} target="_blank" rel="nofollow noopener noreferrer">
                  Web de {entrada.tool.name} ↗
                </a>
              ) : null}
            </div>
          </section>
        ))}

        <section>
          <h2>Cuánto cuesta cada una con el tiempo</h2>
          <div className="table-wrap">
            <table className="compare-table">
              <caption>Lo que pagas por el plan de pago en uno y tres años</caption>
              <thead>
                <tr>
                  <th scope="col">App</th>
                  <th scope="col">1 año</th>
                  <th scope="col">3 años</th>
                </tr>
              </thead>
              <tbody>
                {costeTools.map((tool) => (
                  <tr key={tool.key}>
                    <th scope="row">{tool.name}</th>
                    <td data-label="1 año">{coste(tool, 1)}</td>
                    <td data-label="3 años">{coste(tool, 3)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="checked-note">
            Precios en dólares estadounidenses, tomados de la web de cada app en septiembre y
            octubre de 2026, con la tarifa anual cuando existe. &quot;Unos&quot; significa que
            el precio es aproximado o no está en dólares. Rhino cuenta su plan ilimitado; el
            plan gratis cuesta $0.
          </p>
        </section>

        <section>
          <h2>Cuándo te basta Wispr Flow</h2>
          <p>
            Quédate con Wispr Flow si también dictas en Windows o en el teléfono, si tu empresa
            necesita SOC 2 Tipo II, ISO 27001 o un BAA firmado para un plan preparado para
            HIPAA, o si quieres el producto más pulido de la categoría y la nube no te molesta.
            Son razones reales, y nada en esta lista le gana en las tres.
          </p>
        </section>

        <section>
          <h2>Revisadas, pero fuera de la lista</h2>
          <p>
            <strong>Dragon.</strong> Se sigue vendiendo, por unos $699 una vez, pero solo para
            Windows. No hay versión para Mac desde 2018.
          </p>
          <p>
            <strong>Control por voz de macOS.</strong> Gratis y viene con el sistema; es la
            respuesta si quieres manejar tu Mac con la voz. Es un trabajo distinto a escribir,
            que es lo que hace Wispr Flow.
          </p>
        </section>

        <section>
          <h2>Cómo lo revisé</h2>
          <p>
            Cada precio sale de la web de cada app. La lista es para una persona que escribe en
            un Mac con Apple silicon. Nadie pagó por aparecer aquí, y el precio de Rhino en esta
            página se lee del mismo código que el botón de compra.
          </p>
          <p>
            Para la precisión grabé 10 clips de mi propia voz, en inglés, y califiqué cada app
            según si el texto necesitaba corrección, aceptando cualquier formato razonable. En
            agosto de 2026 Typeless sacó 10 de 10 y Rhino 8 de 10, así que Typeless es más
            precisa. No repetí la prueba en español: tu voz, tu acento y tu jerga son la única
            prueba que predice tu experiencia, así que prueba dos de estas antes de decidir.
          </p>
        </section>

        <section>
          <h2>Cómo cambiarte</h2>
          <ol className="switch-steps">
            {pasos.map((paso) => (
              <li key={paso}>{paso}</li>
            ))}
          </ol>
        </section>

        <section>
          <h2>Preguntas frecuentes</h2>
          <dl className="faq">
            {preguntas.map((entry) => (
              <div key={entry.question}>
                <dt>{entry.question}</dt>
                <dd>{entry.answer}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="doc-cta">
          <h2>Prueba Rhino Voice</h2>
          <p>
            Gratis para empezar: tu primera semana es ilimitada y después tienes 2,000 palabras
            por semana. El ilimitado cuesta ${rhinoPrice} una sola vez, sin suscripción y sin
            cuenta.
          </p>
          <Descargar />
        </section>

        <p className="checked-note">
          Todas las marcas pertenecen a sus dueños y se usan aquí solo para comparar.
        </p>
      </main>

      <footer>
        <span>Rhino Voice</span>
        <a href="mailto:noahkagan@gmail.com">Email</a>
        <a href={englishSlug} hrefLang="en" lang="en">
          The 7 best Wispr Flow alternatives (English)
        </a>
        <a href="/vs/wispr-flow" lang="en">
          Rhino Voice vs Wispr Flow
        </a>
      </footer>
    </div>
  );
}
