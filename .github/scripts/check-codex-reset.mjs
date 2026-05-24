import fs from "node:fs";
import path from "node:path";

const apiUrl = "https://www.hascodexratelimitreset.today/api/status";
const stateFile = path.join(process.cwd(), ".github", "state", "codex-reset-state.json");
const lineToken = process.env.LINE_CHANNEL_ACCESS_TOKEN;
const forceNotify = String(process.env.FORCE_NOTIFY).toLowerCase() === "true";

function readState() {
  try {
    const raw = fs.readFileSync(stateFile, "utf8");
    return JSON.parse(raw);
  } catch {
    return {
      lastObservedState: null,
      lastNotifiedResetAt: null
    };
  }
}

function writeState(state) {
  fs.mkdirSync(path.dirname(stateFile), { recursive: true });
  fs.writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

async function fetchStatus() {
  const response = await fetch(apiUrl, {
    headers: {
      "Cache-Control": "no-cache"
    }
  });

  if (!response.ok) {
    throw new Error(`Status request failed with ${response.status}`);
  }

  return response.json();
}

function buildMessage(status, isTest = false) {
  const subtitle = Array.isArray(status.yesSubtitles) && status.yesSubtitles.length > 0
    ? status.yesSubtitles[0]
    : "Codex rate limit reset.";

  const tweetUrl = status?.automationSummary?.tweetUrl || "https://www.hascodexratelimitreset.today/";
  const prefix = isTest ? "Codex LINE test" : "Codex reset: YES";
  return `${prefix}\n${subtitle}\n${tweetUrl}`;
}

async function sendLineBroadcast(message) {
  if (!lineToken) {
    throw new Error("Missing LINE_CHANNEL_ACCESS_TOKEN secret");
  }

  const response = await fetch("https://api.line.me/v2/bot/message/broadcast", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${lineToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      messages: [
        {
          type: "text",
          text: message
        }
      ]
    })
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`LINE request failed with ${response.status}: ${body}`);
  }
}

const status = await fetchStatus();
const previousState = readState();
const currentState = String(status.state || "");
const currentResetAt = status.resetAt == null ? null : String(status.resetAt);
const transitionedToYes =
  previousState.lastObservedState === "no" &&
  currentState === "yes" &&
  currentResetAt !== previousState.lastNotifiedResetAt;

console.log(`Previous state: ${previousState.lastObservedState ?? "null"}`);
console.log(`Current state: ${currentState}`);
console.log(`Current resetAt: ${currentResetAt ?? "null"}`);
console.log(`Force notify: ${forceNotify}`);

if (forceNotify) {
  await sendLineBroadcast(buildMessage(status, true));
  console.log("Sent LINE test message.");
}

if (transitionedToYes) {
  await sendLineBroadcast(buildMessage(status, false));
  previousState.lastNotifiedResetAt = currentResetAt;
  console.log("Detected no->yes transition and sent LINE notification.");
}

previousState.lastObservedState = currentState;
writeState(previousState);
