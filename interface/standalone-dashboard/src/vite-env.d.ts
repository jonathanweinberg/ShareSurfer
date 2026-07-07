/// <reference types="vite/client" />

import type { RawSnapshot } from "./data/fixtures";
import type { DataRow, DatasetKey } from "./data/schema";

declare global {
  interface Window {
    __SHARESURFER_SNAPSHOT__?: RawSnapshot;
    __SHARESURFER_DATASET_CHUNKS__?: Partial<Record<DatasetKey | string, DataRow[]>>;
  }
}
