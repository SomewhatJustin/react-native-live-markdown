// Global type declarations for React Native environment

declare const global: {
  process?: {
    env: {
      JEST_WORKER_ID?: string;
    };
  };
  jsi_setMarkdownRuntime?: (runtime: unknown) => void;
  jsi_registerMarkdownWorklet?: (worklet: unknown) => number;
  jsi_unregisterMarkdownWorklet?: (id: number) => void;
};

declare namespace NodeJS {
  interface Timeout {}
}
