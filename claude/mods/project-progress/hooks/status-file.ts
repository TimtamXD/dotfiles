import type { ThreadStatus } from '../types'
import { isThreadState } from './thread-states'

function parseJson(text: string): Record<string, unknown> | undefined {
  try {
    const parsed: unknown = JSON.parse(text)
    return typeof parsed === 'object' && parsed !== null
      ? (parsed as Record<string, unknown>)
      : undefined
  } catch {
    return undefined
  }
}

function wholeCount(value: unknown): number {
  return typeof value === 'number' && value > 0 ? Math.floor(value) : 0
}

function optionalText(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() !== '' ? value : undefined
}

export function readStatusFile(text: string): ThreadStatus | undefined {
  const raw = parseJson(text)
  const threadId = optionalText(raw?.threadId)
  const title = optionalText(raw?.title)
  const updatedAt = Date.parse(String(raw?.updatedAt))
  if (!raw || !threadId || !title || !isThreadState(raw.state) || Number.isNaN(updatedAt)) {
    return undefined
  }
  const stepsTotal = wholeCount(raw.stepsTotal)

  return {
    threadId,
    title,
    state: raw.state,
    waitingOn: optionalText(raw.waitingOn),
    currentStep: optionalText(raw.currentStep),
    stepsDone: Math.min(wholeCount(raw.stepsDone), stepsTotal),
    stepsTotal,
    updatedAt,
  }
}
