import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const THINKING = ["off", "minimal", "low", "medium", "high", "xhigh"] as const;
type T = (typeof THINKING)[number];

export default function (pi: ExtensionAPI) {
  let thinking: T | null = null;

  pi.on("thinking_level_select", (e) => { thinking = e.level as T });
  pi.registerShortcut("tab", {
    description: "Cycle thinking level",
    handler: async () => {
      const cur = (thinking || pi.getThinkingLevel() || "off") as T;
      pi.setThinkingLevel(THINKING[(THINKING.indexOf(cur) + 1) % THINKING.length]);
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    thinking = pi.getThinkingLevel() || "off";
    ctx.ui.setFooter((tui, theme, fd) => {
      const unsub = fd.onBranchChange(() => tui.requestRender());
      return {
        dispose: unsub,
        render(width: number): string[] {
          const cwd = ctx.cwd || "~";
          const home = process.env.HOME || "";
          const left = theme.fg("accent", cwd.startsWith(home) ? "~" + cwd.slice(home.length) : cwd)
            + theme.fg("dim", fd.getGitBranch() ? " " + fd.getGitBranch() : "");
          const model = (ctx.model?.id || "no-model").replace(/^(anthropic|openai|google|openrouter|opencode-go)\//, "");
          const t = thinking || pi.getThinkingLevel() || "off";
          const tl = t === "off" ? "" : theme.fg("dim", " " + t.charAt(0) + t.slice(1));
          let ctxL = "";
          const entries = ctx.sessionManager.getBranch();
          let ti = 0, to = 0;
          for (const e of entries) {
            if (e.type === "message" && e.message.role === "assistant") {
              const m = e.message as AssistantMessage;
              ti += m.usage?.input ?? 0; to += m.usage?.output ?? 0;
            }
          }
          const cw = ctx.model?.contextWindow;
          if (cw && cw > 0) ctxL = theme.fg("dim", " " + Math.min(100, Math.round(((ti + to) / cw) * 100)) + "%");
          const rt = theme.fg("accent", "λ " + model) + tl + ctxL;
          return [truncateToWidth(left + " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(rt))) + rt, width)];
        },
      };
    });
  });
}
