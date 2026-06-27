/// <reference types="astro/client" />

interface ImportMetaEnv {
  /** Supabase Projekt-URL (öffentlich). */
  readonly PUBLIC_SUPABASE_URL?: string;
  /** Supabase Anon/Publishable-Key (öffentlich, RLS sichert den Zugriff ab). */
  readonly PUBLIC_SUPABASE_ANON_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

declare module '*.scss' {
  const content: string;
  export default content;
}

declare module '*.css' {
  const content: string;
  export default content;
}

declare module '*.jpeg' {
  const content: string;
  export default content;
}

declare module '*.jpg' {
  const content: string;
  export default content;
}

declare module '*.png' {
  const content: string;
  export default content;
}

declare module '*.gif' {
  const content: string;
  export default content;
}

declare module '*.svg' {
  const content: string;
  export default content;
}

declare module '*.webp' {
  const content: string;
  export default content;
}
