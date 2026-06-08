import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  expect: {
    timeout: 5_000
  },
  use: {
    ...devices["Desktop Chrome"],
    viewport: { width: 1440, height: 1000 },
    trace: "on-first-retry"
  },
  projects: [
    {
      name: "chromium"
    }
  ]
});
