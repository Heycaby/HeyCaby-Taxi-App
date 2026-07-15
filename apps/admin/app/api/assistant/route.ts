import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/admin";

export async function POST(request:Request){
  const {supabase}=await requireAdmin();
  const key=process.env.OPENAI_API_KEY?.trim();
  if(!key)return NextResponse.json({error:"Admin AI is safely disabled until OPENAI_API_KEY is configured."},{status:503});
  let message="";try{const body=await request.json();message=String(body.message||"").trim().slice(0,1000);}catch{return NextResponse.json({error:"Invalid request."},{status:400})}
  if(message.length<2)return NextResponse.json({error:"Ask a specific operational question."},{status:400});
  const {data:overview,error}=await supabase.rpc("fn_admin_os_overview");
  if(error)return NextResponse.json({error:"Operational context is unavailable."},{status:503});
  const response=await fetch("https://api.openai.com/v1/responses",{method:"POST",headers:{Authorization:`Bearer ${key}`,"Content-Type":"application/json"},body:JSON.stringify({
    model:process.env.OPENAI_ADMIN_MODEL||"gpt-5.4-mini",
    instructions:"You are HeyCaby Admin OS, a concise read-only operations analyst. Use only the supplied aggregate context. Never claim to perform actions, never expose or infer personal data, and clearly label uncertainty. Recommend the canonical Admin screen or domain owner for follow-up.",
    input:`Aggregate production context:\n${JSON.stringify(overview)}\n\nAdministrator question: ${message}`,
    max_output_tokens:700
  })});
  if(!response.ok)return NextResponse.json({error:"The AI provider is temporarily unavailable. No state changed."},{status:502});
  const result=await response.json() as {output_text?:string;output?:Array<{content?:Array<{type?:string;text?:string}>}>};
  const answer=result.output_text||result.output?.flatMap(o=>o.content||[]).find(c=>c.type==="output_text")?.text;
  return NextResponse.json({answer:answer||"No answer was produced."});
}
