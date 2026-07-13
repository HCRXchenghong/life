import { optionalText, requiredText } from "../security/validation";

const FUNCTION_NAME = /^[A-Za-z0-9_-]{1,64}$/;

export type GatewayResponseRequest = {
  providerId: string;
  input: unknown;
  tools: Array<Record<string, unknown>>;
  previousResponseId: string | null;
};

export function gatewayResponseRequest(payload: Record<string, unknown>): GatewayResponseRequest {
  const providerId = requiredText(payload.providerId, "providerId", 64);
  const input = payload.input;
  const serializedInput = JSON.stringify(input);
  if (
    (typeof input !== "string" && !Array.isArray(input)) ||
    serializedInput.length > 128_000
  ) {
    throw new Error("input must be a string or array no larger than 128 KB");
  }
  const rawTools = payload.tools ?? [];
  if (!Array.isArray(rawTools) || rawTools.length > 32) {
    throw new Error("tools must contain at most 32 function tools");
  }
  const tools = rawTools.map(validateFunctionTool);
  return {
    providerId,
    input,
    tools,
    previousResponseId: optionalText(
      payload.previous_response_id,
      "previous_response_id",
      160,
    ),
  };
}

function validateFunctionTool(value: unknown): Record<string, unknown> {
  const tool = asRecord(value, "tool");
  if (tool.type !== "function") throw new Error("Only function tools are allowed");
  const name = requiredText(tool.name, "tool.name", 64);
  if (!FUNCTION_NAME.test(name)) throw new Error("tool.name contains unsupported characters");
  if (tool.strict !== true) throw new Error(`Tool '${name}' must set strict=true`);
  const parameters = asRecord(tool.parameters, `tool '${name}' parameters`);
  validateStrictObjectSchema(parameters, `tool '${name}' parameters`, 0);
  return {
    type: "function",
    name,
    description: requiredText(tool.description, `tool '${name}' description`, 1_000),
    strict: true,
    parameters,
  };
}

function validateStrictObjectSchema(
  schema: Record<string, unknown>,
  path: string,
  depth: number,
): void {
  if (depth > 12) throw new Error(`${path} exceeds the schema depth limit`);
  if (schema.type === "object") {
    if (schema.additionalProperties !== false) {
      throw new Error(`${path} must set additionalProperties=false`);
    }
    const properties = asRecord(schema.properties ?? {}, `${path}.properties`);
    const required = schema.required;
    if (!Array.isArray(required)) throw new Error(`${path}.required must be an array`);
    const names = Object.keys(properties);
    if (
      required.length !== names.length ||
      names.some((name) => !required.includes(name))
    ) {
      throw new Error(`${path}.required must list every property`);
    }
    for (const [name, child] of Object.entries(properties)) {
      validateStrictObjectSchema(asRecord(child, `${path}.${name}`), `${path}.${name}`, depth + 1);
    }
  }
  if (schema.type === "array") {
    validateStrictObjectSchema(asRecord(schema.items, `${path}.items`), `${path}.items`, depth + 1);
  }
  for (const branchName of ["anyOf", "oneOf"] as const) {
    const branches = schema[branchName];
    if (branches === undefined) continue;
    if (!Array.isArray(branches)) throw new Error(`${path}.${branchName} must be an array`);
    for (const [index, branch] of branches.entries()) {
      validateStrictObjectSchema(
        asRecord(branch, `${path}.${branchName}[${index}]`),
        `${path}.${branchName}[${index}]`,
        depth + 1,
      );
    }
  }
}

function asRecord(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${field} must be an object`);
  }
  return value as Record<string, unknown>;
}
