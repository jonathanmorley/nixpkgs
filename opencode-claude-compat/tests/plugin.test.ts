import { describe, it, expect } from "bun:test";
import plugin from "../src/plugin";

describe("plugin entry", () => {
  it("exports a function returning hooks including config and tool hooks", async () => {
    const hooks = await (plugin as any)({ client: {}, project: {}, directory: "/tmp", $: {} });
    expect(hooks).toHaveProperty("config");
    // At minimum, config hook; tool hooks optional until hooks coverage lands
    expect(typeof hooks.config).toBe("function");
  });
});
