import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsubscribe,
        invalidate() {},
        render(width: number) {
          const branch = footerData.getGitBranch();
          const model = ctx.model?.id ?? "no-model";
          const text = branch ? `${model} • ${branch}` : model;
          const line = theme.fg("dim", text);
          return [truncateToWidth(line, Math.max(1, width))];
        },
      };
    });
  });
}
