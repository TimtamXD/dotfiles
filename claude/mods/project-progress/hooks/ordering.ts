import type { ThreadCounts, ThreadStatus } from '../types'
import { STATES_IN_ORDER_FOR_TIM } from './thread-states'

const DAY = 24 * 60 * 60 * 1000

function isStillWorthShowing(thread: ThreadStatus, now: number): boolean {
  return thread.state !== 'done' || now - thread.updatedAt <= DAY
}

function rankOf(thread: ThreadStatus): number {
  return STATES_IN_ORDER_FOR_TIM.indexOf(thread.state)
}

export function orderForTim(threads: ThreadStatus[], now: number): ThreadStatus[] {
  return threads
    .filter(thread => isStillWorthShowing(thread, now))
    .sort((first, second) => rankOf(first) - rankOf(second) || second.updatedAt - first.updatedAt)
}

export function countByState(threads: ThreadStatus[]): ThreadCounts {
  const counts = Object.fromEntries(
    STATES_IN_ORDER_FOR_TIM.map(state => [state, 0]),
  ) as ThreadCounts
  for (const thread of threads) counts[thread.state] += 1

  return counts
}
