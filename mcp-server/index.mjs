#!/usr/bin/env node
/**
 * Goberna MCP Server
 *
 * Expone como tools de Claude Code los candidatos del consultor logged-in
 * en electoral.goberna.club. Auth: token JWT en ~/.config/goberna/token.
 *
 * Tools (Fase A — read-only):
 *   list_candidates          → lista candidatos asignados al consultor
 *   get_candidate_context    → contexto completo de un candidato
 *
 * Tools (Fase B — agregadas en commit posterior):
 *   list_decks               → decks existentes de un candidato
 *   upload_deck              → sube un .html como draft
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// ── Config ──────────────────────────────────────────────────────────────
const API_URL = process.env.GOBERNA_API_URL ?? "https://electoral.goberna.club";
const TOKEN_PATH =
  process.env.GOBERNA_TOKEN_PATH ?? join(homedir(), ".config", "goberna", "token");

function readToken() {
  if (!existsSync(TOKEN_PATH)) {
    throw new Error(
      `No se encontró tu token en ${TOKEN_PATH}.\n` +
        `Pedile al admin de Goberna que te genere uno y guardalo en ese archivo.`,
    );
  }
  return readFileSync(TOKEN_PATH, "utf8").trim();
}

async function api(path, init = {}) {
  const token = readToken();
  const res = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      ...(init.headers ?? {}),
    },
  });
  if (!res.ok) {
    let body = null;
    try {
      body = await res.json();
    } catch {
      body = await res.text().catch(() => null);
    }
    const msg = typeof body === "object" && body?.message ? body.message : `HTTP ${res.status}`;
    throw new Error(`Goberna API ${path} → ${msg}`);
  }
  return res.json();
}

// ── Tool definitions ────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "list_candidates",
    description:
      "Lista los candidatos asignados al consultor logged-in. Devuelve nombre, cargo, jurisdicción y partido por cada uno. Llamar al inicio de cada conversación para ofrecerle al consultor cuál trabajar.",
    inputSchema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
  {
    name: "get_candidate_context",
    description:
      "Devuelve el contexto completo de un candidato (cargo, ámbito, jurisdicción anidada, organización política, foto, has_password). Usar después de que el consultor elige uno de la lista para prepoblar el deck con datos reales en lugar de pedirlos manualmente.",
    inputSchema: {
      type: "object",
      properties: {
        candidato_id: {
          type: "integer",
          description: "ID del candidato (entero, viene de list_candidates)",
        },
      },
      required: ["candidato_id"],
    },
  },
];

// ── Server setup ────────────────────────────────────────────────────────

const server = new Server(
  {
    name: "goberna-mcp",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  try {
    switch (name) {
      case "list_candidates": {
        const data = await api("/api/consultor/candidates");
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(
                {
                  ok: data.ok,
                  count: data.candidates?.length ?? 0,
                  admin_all: data.admin_all ?? false,
                  candidates: data.candidates ?? [],
                },
                null,
                2,
              ),
            },
          ],
        };
      }

      case "get_candidate_context": {
        const id = args.candidato_id;
        if (typeof id !== "number" || !Number.isInteger(id)) {
          throw new Error("candidato_id debe ser un entero");
        }
        const data = await api(`/api/consultor/candidates/${id}/context`);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(data, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Tool desconocida: ${name}`);
    }
  } catch (e) {
    return {
      isError: true,
      content: [
        {
          type: "text",
          text: `Error: ${e.message}`,
        },
      ],
    };
  }
});

// ── Boot ────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
process.stderr.write(`[goberna-mcp] running · API=${API_URL} · token=${TOKEN_PATH}\n`);
