import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import type { ExtensionCommandContext, HunkExtensionAPI } from 'hunkdiff/extension';

const hunkCmd = (ctx: ExtensionCommandContext) => (...args: string[]) => {
  spawnSync(
    'hunk', args,
    {
      cwd: ctx.cwd,
      timeout: 1000,
    }
  );
}

const herdrCmd = (ctx: ExtensionCommandContext) => (...args: string[]) => {
  const paneOutput = spawnSync(
    'herdr', args,
    {
      cwd: ctx.cwd,
      timeout: 1000,
    }
  );
  try {
    return JSON.parse(paneOutput.stdout.toString('utf8')).result;
  } catch {
    return undefined;
  }
}

const configs = existsSync(`${process.env.HERDR_PLUGIN_ROOT}/config.json`) ? JSON.parse(readFileSync(`${process.env.HERDR_PLUGIN_ROOT}/config.json`).toString('utf8')) : {};

const diffModes: Record<string, {
  title: string;
  revset?: string;
  key?: string;
}> = {
  uncommited: {
    title: 'Uncommitted',
    key: 'ctrl+w',
  },
  unpushed: {
    title: 'Unpushed',
    revset: `remote_bookmarks(remote='${configs['default-remote'] ?? 'origin'}')..@`,
    key: 'ctrl+p',
  },
  trunk: {
    title: 'Trunk',
    revset: 'trunk()..@',
    key: 'ctrl+t',
  },
};

export default function (hunk: HunkExtensionAPI) {
  Object.entries(diffModes).forEach(([key, item]) => hunk.registerCommand({
    id: `diff-${key}`,
    title: `${item.title} Diff`,
    key: item.key,
  }, async (ctx) => {
    const hunkCli = hunkCmd(ctx);
    if (item.revset) {
      hunkCli('session', 'reload', '--repo', '.', '--', 'diff', item.revset);
    } else {
      hunkCli('session', 'reload', '--repo', '.', '--', 'diff');
    }
    ctx.notify(`Switched to ${item.title.toLowerCase()} diff`);
  }));

  hunk.registerCommand({ id: 'send', title: 'Send notes to agent', key: 'ctrl+s' }, async (ctx) => {
    const snapshot = ctx.review.snapshot();

    if (!snapshot || snapshot.notes.length === 0) {
      ctx.notify('No comment');
      return;
    }

    const pathByFileKey = new Map(snapshot.files.map(
      (file) => [file.fileKey, file.path]
    ));
    const notes = snapshot.notes.flatMap((note) => {
      const path = pathByFileKey.get(note.fileKey);

      if (!path) {
        return [];
      }

      return [{
        path,
        range: note.anchor.newRange,
        summary: note.summary,
      }];
    });

    const herdr = herdrCmd(ctx);
    const pane = herdr('pane', 'current').pane;
    const workspaceId = pane.workspace_id;
    const reviewerToken = pane.tokens?.['hunk-reviewer'];

    if (reviewerToken !== '1') {
      ctx.notify("Not a hunk-reviewer pane");
      return;
    }

    const agents = herdr('agent', 'list').agents.filter((agent: any) => agent.workspace_id === workspaceId);
    const tabsById = new Map<string, any>(herdr('tab', 'list', '--workspace', workspaceId).tabs.map((tab: any) => [tab.tab_id, tab]));

    let agent;
    if (agents.length === 0) {
      // TODO: Copy to clipboard
      ctx.notify('No agent running');
    } else if (agents.length === 1) {
      [agent] = agents;
    } else {
      const agentChoices = new Map<string, any>(agents.map(
        (agent: any, index: number) => [
          `${index}: ${agent.agent} (${agent.agent_status}) - ${tabsById.get(agent.tab_id)?.label ?? agent.tab_id}`,
          agent
        ]
      ));
      const picked = await ctx.dialogs.select({
        title: "Which agent to send notes to?",
        options: Array.from(agentChoices.keys()),
      });

      if (!picked) {
        return;
      }

      agent = agentChoices.get(picked);
    }

    if (!agent) {
      ctx.notify('Invalid agent state');
    }

    herdr('pane', 'send-text', agent.pane_id, notes.map(
      (note) => [
        `${note.path}:${note.range}`,
        note.summary,
      ].join('\n')
    ).join('\n\n'));
    if (configs['follow-send'] !== false) {
      herdr('agent', 'focus', agent.pane_id);
    }
    const hunkCli = hunkCmd(ctx);
    hunkCli('session', 'comment', 'clear', '--repo', '.', '--all', '--yes');
    ctx.notify(`${notes.length} notes sent to ${agent.agent} (${agent.agent_status}) - ${tabsById.get(agent.tab_id)?.label ?? agent.tab_id}`);
  });
}
