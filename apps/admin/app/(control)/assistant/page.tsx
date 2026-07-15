import type { Metadata } from "next";
import { PageHeader, Section } from "@/components/ui";
import { AssistantClient } from "./assistant-client";
export const metadata:Metadata={title:"Admin AI"};
export default function AssistantPage(){return <><PageHeader eyebrow="Read-only co-pilot" title="Admin AI" description="Ask operational questions without granting an AI the power to mutate production."/><Section title="Operations assistant" description="Answers use only the current privacy-safe overview contract"><AssistantClient/></Section></>}
