/// <reference types="vite/client" />

import type { RawSnapshot } from "./data/fixtures";

declare global {
  interface Window {
    __SHARESURFER_SNAPSHOT__?: RawSnapshot;
  }
}
