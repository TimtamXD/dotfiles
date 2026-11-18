import type { ThreadState, ThreadStatus } from '../types'
import { countByState } from './ordering'
import { STATES_IN_ORDER_FOR_TIM } from './thread-states'

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

export const STATE_WORDS: Record<ThreadState, string> = {
  needs_tim: 'need you',
  review_ready: 'ready to review',
  failed: 'failed',
  working: 'working',
  stopped: 'stopped',
  done: 'done',
}

export function describeAge(at: number, now: number): string {
  const elapsed = Math.max(0, now - at)
  if (elapsed < MINUTE) return 'just now'
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)}m ago`
  if (elapsed < DAY) return `${Math.floor(elapsed / HOUR)}h ago`

  return `${Math.floor(elapsed / DAY)}d ago`
}

export function summarise(threads: ThreadStatus[]): string {
  const counts = countByState(threads)
  const needsTim = counts.needs_tim + counts.review_ready
  const lead = needsTim === 0 ? 'Nothing needs you' : `${needsTim} need you`
  const rest = STATES_IN_ORDER_FOR_TIM.filter(
    state => state !== 'needs_tim' && state !== 'review_ready' && counts[state] > 0,
  ).map(state => `${counts[state]} ${STATE_WORDS[state]}`)

  return [lead, ...rest].join(' · ')
}
