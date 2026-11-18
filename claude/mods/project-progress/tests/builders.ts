import type { ThreadStatus } from '../types'

export const NOW = Date.parse('2026-11-18T04:00:00Z')
export const MINUTE = 60_000
export const HOUR = 60 * MINUTE

export function aThread(overrides: Partial<ThreadStatus> = {}): ThreadStatus {
  return {
    threadId: 'cmsg_fix_export',
    title: 'Fix Safari export button',
    state: 'working',
    stepsDone: 1,
    stepsTotal: 4,
    currentStep: 'Write the failing test',
    updatedAt: NOW - 5 * MINUTE,
    ...overrides,
  }
}

export function aStatusFile(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    schema: 1,
    threadId: 'cmsg_fix_export',
    title: 'Fix Safari export button',
    state: 'working',
    stepsDone: 1,
    stepsTotal: 4,
    currentStep: 'Write the failing test',
    updatedAt: '2026-11-18T03:55:00Z',
    ...overrides,
  })
}
