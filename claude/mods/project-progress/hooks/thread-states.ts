import type { ThreadState } from '../types'

export const STATES_IN_ORDER_FOR_TIM: readonly ThreadState[] = [
  'needs_tim',
  'review_ready',
  'failed',
  'working',
  'stopped',
  'done',
]

export function isThreadState(value: unknown): value is ThreadState {
  return STATES_IN_ORDER_FOR_TIM.includes(value as ThreadState)
}
