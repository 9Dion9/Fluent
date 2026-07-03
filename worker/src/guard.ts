import type { ChatReply } from "./schemas";

/**
 * `GuardProvider` v1 implementation (CLAUDE.md §2, §7 guardrail layer 2):
 * keyword/regex prefilter for clearly harmful input. On a hit, we skip the
 * model entirely and return a canned in-character redirect — cheaper and
 * more reliable than trusting the system prompt alone for the worst inputs.
 */
const HARMFUL_PATTERNS: RegExp[] = [
  /\b(kill|murder|suicide|self[\s-]?harm)\b/i,
  /\bhow (do|can) i (make|build|synthesize) (a )?(bomb|explosive|weapon)/i,
  /\bchild (sexual|porn|abuse)/i,
  /\b(csam)\b/i,
];

const CANNED_REDIRECT: Record<string, string> = {
  sunny: "Whoa, let's steer clear of that one — I'm only any good at the language stuff anyway! What do you want to say in your target language?",
  dry: "That's outside my job description. I only do vocabulary and grammar. Try me again with something learnable.",
  professor: "That falls outside what I can help with. Let's return to the language at hand — what would you like to practice?",
};

export function guardPrefilterHit(text: string): boolean {
  return HARMFUL_PATTERNS.some((pattern) => pattern.test(text));
}

export function guardCannedReply(persona: string): ChatReply {
  const reply = CANNED_REDIRECT[persona] ?? CANNED_REDIRECT.sunny ?? "";
  return {
    reply,
    reply_target_text: "",
    corrections: [],
    suggested_replies: [],
    new_vocab: [],
  };
}
