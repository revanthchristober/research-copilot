#!/usr/bin/env node
/**
 * Research Copilot — MCP server.
 *
 * Exposes the running Research Copilot Rails app's interview database
 * as tools for Claude Desktop (or any MCP client).
 *
 * Configure the Rails base URL via the RESEARCH_COPILOT_URL env var.
 * Defaults to http://localhost:3000.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE_URL = (process.env.RESEARCH_COPILOT_URL ?? "http://localhost:3000").replace(/\/$/, "");

const server = new McpServer({
  name: "research-copilot",
  version: "0.1.0",
});

async function callRails(path: string, init?: RequestInit): Promise<unknown> {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      ...(init?.headers ?? {}),
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Rails ${res.status} ${res.statusText} at ${path}: ${body.slice(0, 200)}`);
  }
  return res.json();
}

const textResult = (data: unknown) => ({
  content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
});

server.registerTool(
  "search_interviews",
  {
    title: "Search interviews",
    description: "Semantic search across all ingested interview transcripts. Returns the top-k most relevant chunks ranked by cosine similarity.",
    inputSchema: {
      query: z.string().describe("The research query — natural language."),
      k: z.number().int().min(1).max(50).default(10).describe("Number of results to return (1-50)."),
    },
  },
  async ({ query, k }) => {
    const url = `/api/v1/search?q=${encodeURIComponent(query)}&k=${k}`;
    const data = await callRails(url);
    return textResult(data);
  }
);

server.registerTool(
  "get_quotes",
  {
    title: "Fetch quotes by chunk_id",
    description: "Retrieve the full text of specific interview chunks by their IDs (use IDs returned by search_interviews or find_pain_points).",
    inputSchema: {
      chunk_ids: z.array(z.number().int()).min(1).max(50).describe("List of chunk IDs to fetch."),
    },
  },
  async ({ chunk_ids }) => {
    const data = await callRails(`/api/v1/quotes`, {
      method: "POST",
      body: JSON.stringify({ chunk_ids }),
    });
    return textResult(data);
  }
);

server.registerTool(
  "find_pain_points",
  {
    title: "List recurring themes / pain points",
    description: "Return the auto-extracted themes across all interviews, ranked by evidence count. Each theme has a label, summary, and the chunk_ids that support it.",
    inputSchema: {},
  },
  async () => {
    const data = await callRails(`/api/v1/themes`);
    return textResult(data);
  }
);

server.registerTool(
  "find_feature_requests",
  {
    title: "Find feature requests across interviews",
    description: "Semantically search for places where users requested features, improvements, or suggested changes to the product.",
    inputSchema: {
      k: z.number().int().min(1).max(20).default(10),
    },
  },
  async ({ k }) => {
    const url = `/api/v1/search?q=${encodeURIComponent("feature request improvement suggestion users want would have helped")}&k=${k}`;
    const data = await callRails(url);
    return textResult(data);
  }
);

server.registerTool(
  "ask_research_question",
  {
    title: "Ask a research question (RAG + groundedness)",
    description: "Synthesize an answer from the interview corpus. Returns an answer with inline [N] citations, the citations themselves, and a 0-100 groundedness score from an independent judge.",
    inputSchema: {
      question: z.string().min(3).describe("A research question — e.g. 'What are the top onboarding pain points?'"),
    },
  },
  async ({ question }) => {
    const data = await callRails(`/api/v1/ask`, {
      method: "POST",
      body: JSON.stringify({ question }),
    });
    return textResult(data);
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Logged to stderr so it doesn't interfere with stdio protocol traffic on stdout.
  console.error(`[research-copilot-mcp] connected, Rails base = ${BASE_URL}`);
}

main().catch((err) => {
  console.error(`[research-copilot-mcp] fatal:`, err);
  process.exit(1);
});
