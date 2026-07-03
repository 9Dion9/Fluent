import { describe, expect, it } from "vitest";
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import Ajv from "ajv";
import addFormats from "ajv-formats";

const dir = path.dirname(fileURLToPath(import.meta.url));
const schemasDir = path.join(dir, "schemas");
const fixturesDir = path.join(dir, "fixtures");

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

const schemaFiles = readdirSync(schemasDir).filter((f) => f.endsWith(".json"));

for (const file of schemaFiles) {
  const schema = JSON.parse(readFileSync(path.join(schemasDir, file), "utf-8"));
  ajv.addSchema(schema, schema.$id);
}

describe("shared schemas", () => {
  for (const file of schemaFiles) {
    const name = file.replace(/\.json$/, "");
    const fixturePath = path.join(fixturesDir, file);

    it(`${name} fixture validates against ${name} schema`, () => {
      const schema = JSON.parse(readFileSync(path.join(schemasDir, file), "utf-8"));
      const fixture = JSON.parse(readFileSync(fixturePath, "utf-8"));
      const validate = ajv.getSchema(schema.$id) ?? ajv.compile(schema);
      const valid = validate(fixture);
      if (!valid) {
        throw new Error(JSON.stringify(validate.errors, null, 2));
      }
      expect(valid).toBe(true);
    });
  }
});
