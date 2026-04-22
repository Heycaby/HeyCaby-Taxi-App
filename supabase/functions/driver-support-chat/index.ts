import {
  corsOptions,
  handleSupportChatRequest,
  json,
} from "../_shared/support_chat_shared.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return corsOptions();
  }
  try {
    return await handleSupportChatRequest(req, "driver");
  } catch (e) {
    console.error("driver-support-chat:", e);
    return json({ error: "internal_error" }, 500);
  }
});
